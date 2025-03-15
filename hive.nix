{ pkgs ? <nixpkgs> } : {
  meta.nixpkgs = pkgs;
  anubis = {name, nodes, modulesPath, ...} : {
    deployment = {
      targetHost = "bahamut.monster";
      targetPort = 1131;
    };
    networking.hostName = name;
    # Bring in the digitalocean config
    imports = pkgs.lib.optional (builtins.pathExists ./do-userdata.nix) ./do-userdata.nix ++ [
      (modulesPath + "/virtualisation/digital-ocean-config.nix")
    ];

    # allow unprivileged ports
    boot.kernel.sysctl."net.ipv4.ip_unprivileged_port_start" = 80;
    
    services.openssh = {
      enable = true;
      ports = [ 1131 ];
      settings.PasswordAuthentication = false;
      settings.PermitRootLogin = "prohibit-password";
      services.openssh.hostKeys = [ {
        path = "/etc/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      } ];
    };

    users.users = {
      anubis = {
        isSystemUser = true;
        linger = true;
        group = "anubis";
        extraGroups = ["podman"];
      };
    };

    systemd.tmpfiles.rules = [
      "d /public - anubis anubis"
      "d /config - anubis anubis"
      "f /config/acme.json 0600 anubis anubis"
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
        user = "anubis";
        image = "docker.io/traefik:v3.3";
        # unfortunately required to map the socket in
        preRunExtraOptions = ["--security-label=disable"];
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
          "--certificatesresolvers.lets-encrypt.acme.email='jjbarr@ptnote.dev'" 
          "--certificatesresolvers.lets-encrypt.acme.storage=acme.json"
          "--certificatesresolvers.lets-encrypt.acme.tlschallenge=true "
        ];
        ports = ["127.0.0.1:8080:8080" "80:80" "443:443"];
        volumes = [
          "%t/podman/podman.sock:/var/run/docker.sock:ro"
        ];
      };
      sws = {
        autoStart = true;
        image = "ghcr.io/static-web-server/static-web-server:2";
        user = "anubis";
        volumes = "/public:/public:z";
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
          "traefik.http.routers.sws.rule"="Host(`bahamut.monster`) || Host(`www.bahamut.monster`)";
          "traefik.http.routers.sws.tls"="true";
          "traefik.http.routers.sws.tls.certResolver"="lets-encrypt";
          "traefik.http.services.sws.loadbalancer.server.port"="8080";
        };
      };  
    };
  };
}
