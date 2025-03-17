{ pkgs, agenix, agenix-rekey} : {
  meta.nixpkgs = import pkgs {
    system = "x86_64-linux";
    #overlays = [ragenix.overlays.default];
    config.allowUnfree = true;
  };
  defaults = { pkgs, ... } : {
    environment.systemPackages = with pkgs; [vim wget curl];
    networking.firewall = {
      enable = true;
      allowedTCPPorts = [ 22 80 443 ];
      # for QUIC
      allowedUDPPortRanges = [{ from = 443; to = 443; }];
      checkReversePath = "loose";
    };
    services.fail2ban = {enable = true; maxretry = 5;};
    services.openssh = {
      enable = true;
      ports = [ 22 ];
      settings.PasswordAuthentication = false;
      settings.PermitRootLogin = "prohibit-password";
      hostKeys = [ {
        path = "/etc/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      } ];
    };
  };
  anubis = (import ./anubis.nix) { inherit agenix agenix-rekey; };
}
