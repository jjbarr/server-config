{
  description = "Deploying my domains";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    utils.url = "github:numtide/flake-utils";
    colmena.url = "github:zhaofengli/colmena";
  };

  outputs = { self, colmena, nixpkgs, utils }:
    let
      per_system = utils.lib.eachDefaultSystem (
        system :
        let 
          pkgs = import nixpkgs {
            inherit system;
           };
        in {
          devShells = {
            default = pkgs.mkShell {
              packages = [ pkgs.sops (import colmena) pkgs.opentofu ];
            };
          };
        });
      global = {
        colmena = (import ./hive.nix {
          pkgs = nixpkgs;
          inherit sops-nix;
        });
      };
    in per_system // global;
}
