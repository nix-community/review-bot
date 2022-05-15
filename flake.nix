{
  description = "Run `nixpkgs-review pr` from Matrix [maintainer=@ckiee]";

  inputs = {
    nixpkgs.url =
      "github:nixos/nixpkgs/nixos-unstable"; # We want to use packages from the binary cache
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = inputs@{ self, nixpkgs, flake-utils }:
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
        runtimeDeps = [ pkgs.nixpkgs-review pkgs.bubblewrap pkgs.git ];
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
                lib.makeBinPath runtimeDeps
              }
            '';
          };
          default = review-bot;
        };

        nixosModules.review-bot = { config, lib, pkgs, ... }:
          with lib;
          let
            cfg = config.services.nc-review-bot;
            util = import ./svc-util.nix { inherit lib config; };
          in {
            options.services.nc-review-bot = {
              enable =
                mkEnableOption "Enables nix-community's review-bot for nixpkgs";
              secretFolder = mkOption {
                type = types.str;
                example = "/run/keys/lbahblah";
                description =
                  "path to service secret directory. the file default.yml must be in it";
              };
            };

            config = mkIf cfg.enable (mkMerge [
              (util.mkService "review-bot" {
                home = cfg.folder;
                description = "Nix-community nixpkgs-review matrix bot";
                script = let bin = pkgs.cookie.anonvote-bot;
                in ''
                  exec ${bin}/bin/review-bot
                '';
              })
              {
                systemd.services.review-bot.environment.NODE_CONFIG_DIR =
                  cfg.secretFolder;
              }
            ]);
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
          buildInputs = with pkgs; [ yarn node y2n.yarn2nix ] ++ runtimeDeps;
        };
      });
}
