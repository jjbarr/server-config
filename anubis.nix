{agenix, agenix-rekey}:
{name, nodes, pkgs, lib, modulesPath, config, ...} : {
  imports = [
    (modulesPath + "/virtualisation/digital-ocean-config.nix")
    agenix.nixosModules.default
    agenix-rekey.nixosModules.default
  ];
  system.stateVersion = "24.11";
  nixpkgs.system = "x86_64-linux";
  deployment = {
    targetHost = "anubis.bahamut.monster";
  };
  networking.hostName = name;
  networking.domain = "bahamut.monster";
  
  # the firewall breaks do-agent anyways. C'est useless.
  services.do-agent.enable = false;
  # allow unprivileged ports
  boot.kernel.sysctl."net.ipv4.ip_unprivileged_port_start" = 80;

  age.rekey = {
    storageMode = "local";
    localStorageDir = ./.secrets/rekeyed/anubis;
    hostPubkey =
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEwsFwNLN4PWqoh3ZmUb82dZzxI8510dbY5c/iUglSrs";
    masterIdentities = [
      {
        identity = "/home/joshua/secinfo/server-key.txt";
        pubkey = "age1l4rhfgte20haxhcp7xqzzr6s5n0ted6f48led0qmfgpn4sx2evesacvs0q";
      }
    ];
  };
  
  # metrics with grafana
  services.alloy.enable = true;
  #alloy runs as nobody by default, which is... not correct
  systemd.services.alloy = {
    serviceConfig.DynamicUser = lib.mkForce false;
    serviceConfig.User = "alloy";
    serviceConfig.Group = "alloy";
  };
  age.secrets.graf-apikey.rekeyFile = ./anubis/graf-apikey.age;
  #this is a hack but I'm so done
  age.secrets.graf-apikey.mode = "440";
  age.secrets.graf-apikey.owner = "alloy";
  age.secrets.graf-apikey.group = "alloy";
  environment.etc."alloy/config.alloy".text =
    builtins.replaceStrings ["$APIKEY"] [config.age.secrets.graf-apikey.path]
      (lib.strings.fileContents ./anubis/config.alloy);
  # web user only gets access to uploads
  services.openssh.extraConfig = ''
      Match User web
        ChrootDirectory /public
        ForceCommand internal-sftp
        AllowTCPForwarding no
        X11Forwarding no
        AllowAgentForwarding no
    '';
  
  users.groups.web = {};
  users.groups.alloy = {};
  users.groups.haproxy = {};
  users.users = {
    web = {
      isSystemUser = true;
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN4yxSed86xXJ3wuBwxX7HrAHrHSkFliBg7s4Nx53NFS joshua@uruk"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHM0G+Ri6crg86mYVWWDHUiO+FX0GB0di9QkdNvE8SWF joshua@prospero"
      ];
      group = "web";
    };
    alloy = {
      isSystemUser = true;
      group = "alloy";
      extraGroups = ["utmp" "systemd-journal"];
    };
    haproxy = {
      isSystemUser = true;
      group = "haproxy";
      extraGroups = ["acme"];
    };
  };
  
  systemd.tmpfiles.rules = [
    "d /public 0755 root root"
    "d /public/ptnote.dev 0775 web web"
    "d /config - root root"
    "f /config/acme.json 0600 root root"
  ];

  age.secrets.pb-dns.rekeyFile = ./anubis/pb_dns.age;
  age.secrets.pb-dns.owner = "acme";
  security.acme = {
    acceptTerms = true;
    defaults.email = "jjbarr+acme@ptnote.dev";
    defaults.dnsProvider = "porkbun";
    defaults.environmentFile = config.age.secrets.pb-dns.path; 
    certs."ptnote.dev" = {
      extraDomainNames = ["*.ptnote.dev"];
    };
  };

  services.haproxy.enable = true;
  services.haproxy.user = "haproxy";
  services.haproxy.group = "haproxy";
  services.haproxy.config = ''
  global
    ssl-default-bind-options ssl-min-ver TLSv1.2
  defaults
    timeout connect 5s
    timeout client 1m
    timeout server 1m
  crt-store ptnote
    crt-base /var/lib/acme/ptnote.dev
    key-base /var/lib/acme/ptnote.dev
    load crt "cert.pem" key "key.pem"
  frontend main
    mode http
    bind *:80
    bind *:443 ssl crt "@ptnote/cert.pem"
    http-request redirect scheme https unless { ssl_fc }
    http-response set-header Strict-Transport-Security "max-age=259200; includeSubDomains; preload;"
    http-response set-header X-Clacks-Overhead "GNU Terry Pratchett"
    use_backend static if { req.hdr(host) -i ptnote.dev }
    use_backend static if { req.hdr(host) -i www.ptnote.dev }
  frontend stats
    mode http
    http-request use-service prometheus-exporter if { path /metrics }
    bind *:8404
    stats enable
    stats uri /stats
    stats refresh 10s
    stats admin if LOCALHOST
  backend static
    mode http
    option forwardfor
    server s1 127.0.0.1:8091 check
  '';
  systemd.timers."refresh-haproxy" = {
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "monthly";
      Unit = "refresh-haproxy.service";
    };
  };
  systemd.services."refresh-haproxy" = {
    script = ''
    set -eu
    ${pkgs.systemd}/bin/systemctl try-reload-or-restart haproxy.service
    '';
    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };
  };

  virtualisation.containers.enable = true;
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    defaultNetwork.settings.dns_enabled = true;
  };
  virtualisation.oci-containers.containers = {
    sws = {
      autoStart = true;
      image = "ghcr.io/static-web-server/static-web-server:2";
      volumes = ["/public/ptnote.dev:/public:z"];
      ports = ["8091:8091"];
      environment = {
        SERVER_ROOT="/public";
        SERVER_LOG_LEVEL="info";
        SERVER_LOG_X_REAL_IP="true";
        SERVER_LOG_FORWARDED_FOR="true";
        SERVER_PORT="8091";
      };
    };
  };
}
