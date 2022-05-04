{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url =
      "github:nixos/nixpkgs/nixos-unstable"; # We want to use packages from the binary cache
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = inputs@{ self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        inherit (pkgs) lib;
        node = pkgs.nodejs-16_x;
        nyarn = pkgs.yarn.override { nodejs = node; };
        y2n = pkgs.yarn2nix-moretea.override {
          nodejs = node;
          yarn = nyarn;
        };
      in rec {
        packages = rec {
          review-bot = y2n.mkYarnPackage {
            name = "review-bot";
            src = ./.;
            packageJSON = ./package.json;
            yarnLock = ./yarn.lock;
            yarnNix = ./yarn.nix; # TODO see if we really need this
            buildPhase = "yarn --offline run postinstall";
            nativeBuildInputs = with pkgs; [ makeWrapper ];
            postFixup = ''
              wrapProgram $out/bin/review-bot --prefix PATH : ${
                lib.makeBinPath (with pkgs; [ nixpkgs-review ])
              }
            '';
          };
          default = review-bot;
        };

        defaultPackage = packages.default;

        apps = rec {
          review-bot = flake-utils.lib.mkApp {
            name = "review-bot";
            drv = packages.review-bot;
          };
          default = review-bot;
        };

        defaultApp = apps.default;

        devShell = pkgs.mkShell {
          buildInputs = with pkgs; [ yarn node y2n.yarn2nix ];
        };
      });
}
