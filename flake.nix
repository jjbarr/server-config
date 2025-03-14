{
  description = "Deploying my domains";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = { self, nixpkgs, colmena }: {
    devShells.x86_64-linux.default =
      let pkgs = nixpkgs.legacyPackages.x86_64-linux;
      in pkgs.mkShell {
        buildInputs = [ pkgs.colmena pkgs.opentofu ];
      };
  };
}

