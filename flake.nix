{
  description = "Deploying my domains";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    utils.url = "github:numtide/flake-utils";
    colmena.url = "github:zhaofengli/colmena";
    agenix.url = "github:ryantm/agenix";
    agenix-rekey.url = "github:oddlama/agenix-rekey";
    agenix-rekey.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, colmena, agenix, agenix-rekey, nixpkgs, utils }:
    let
      per_system = utils.lib.eachDefaultSystem (
        system :
        let 
          pkgs = import nixpkgs {
            overlays = [ agenix-rekey.overlays.default ];
            inherit system;
           };
        in {
          devShells = {
            default = pkgs.mkShell {
              packages = [ pkgs.agenix-rekey (import colmena) pkgs.opentofu ];
            };
          };
        });
      global = {
        agenix-rekey = agenix-rekey.configure {
          userFlake = self;
          nixosConfigurations =
            ((colmena.lib.makeHive self.colmena).introspect (x: x)).nodes;
        };
        colmena = (import ./hive.nix {
          pkgs = nixpkgs;
          inherit agenix agenix-rekey;
        });
      };
    in per_system // global;
}
