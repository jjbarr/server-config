{name, nodes, pkgs, modulesPath, config, ...} : {
  system.stateVersion = "24.11";
  nixpkgs.system = "x86_64-linux";
  deployment = {
    targetHost = "anubis.bahamut.monster";
  };
  networking.hostName = name;
  networking.domain = "bahamut.monster";
  # Bring in the digitalocean config
  imports = [
    (modulesPath + "/virtualisation/digital-ocean-config.nix")
  ];
    
  # the firewall breaks do-agent anyways. C'est useless.
  services.do-agent.enable = false;
  # allow unprivileged ports
  boot.kernel.sysctl."net.ipv4.ip_unprivileged_port_start" = 80;
  
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
  users.users = {
    web = {
      isSystemUser = true;
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN4yxSed86xXJ3wuBwxX7HrAHrHSkFliBg7s4Nx53NFS joshua@uruk"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHM0G+Ri6crg86mYVWWDHUiO+FX0GB0di9QkdNvE8SWF joshua@prospero"
      ];
      group = "web";
    };
  };
  
  systemd.tmpfiles.rules = [
    "d /public 0755 root root"
    "d /public/ptnote.dev 0775 web web"
    "d /config - root root"
    "f /config/acme.json 0600 root root"
  ];

  virtualisation.containers.enable = true;
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    defaultNetwork.settings.dns_enabled = true;
  };
  virtualisation.oci-containers.containers = {
    traefik = {
      autoStart = true;
      image = "docker.io/traefik:v3.3";
      # unfortunately required to map the socket in
      extraOptions = ["--security-opt" "label=disable"];
      cmd = [
        "--api.insecure=true" "--api.dashboard=true" "--providers.docker=true"
        "--providers.docker.exposedbydefault=false"
        "--accesslog=true"
        "--entryPoints.http"
        "--entryPoints.http.address=:80"
        "--entrypoints.http.http.redirections.entryPoint.to=https"
        "--entrypoints.http.http.redirections.entryPoint.scheme=https"
        "--entryPoints.https"
        "--entryPoints.https.address=:443"
        "--certificatesresolvers.lets-encrypt.acme.email=jjbarr@ptnote.dev" 
        "--certificatesresolvers.lets-encrypt.acme.storage=acme.json"
        "--certificatesresolvers.lets-encrypt.acme.tlschallenge=true"
      ];
      ports = ["8080:8080" "80:80" "443:443"];
      volumes = [
        "/run/podman/podman.sock:/var/run/docker.sock:ro"
      ];
    };
    sws = {
      autoStart = true;
      image = "ghcr.io/static-web-server/static-web-server:2";
      volumes = ["/public/ptnote.dev:/public:z"];
      environment = {
        SERVER_ROOT="/public";
        SERVER_LOG_LEVEL="info";
        SERVER_LOG_X_REAL_IP="true";
        SERVER_LOG_FORWARDED_FOR="true";
        SERVER_PORT="8080";
      };
      labels = {
        "traefik.enable"="true";
        "traefik.http.routers.sws.entryPoints"="https";
        "traefik.http.routers.sws.rule"="Host(`www.ptnote.dev`) || Host(`ptnote.dev`)";
        "traefik.http.routers.sws.tls"="true";
        "traefik.http.routers.sws.tls.certResolver"="lets-encrypt";
        "traefik.http.middlewares.gtp.headers.customresponseheaders.X-Clacks-Overhead"="GNU Terry Pratchett";
        "traefik.http.routers.sws.middlewares"="gtp@docker";
        "traefik.http.services.sws.loadbalancer.server.port"="8080";
      };
    };
  };
}
