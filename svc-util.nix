{ config, lib, ... }:

with lib; {
  # Make a service with it's own user account and secure systemd settings
  #
  #  mkService "comicfury" {
  #    home = "/var/lib/comicfury";
  #    description = "ComicFury discord webhook";
  #    script =
  #      "exec ${pkgs.cookie.comicfury-discord-webhook}/bin/comicfury-discord-webhook";
  #  }
  mkService = name:
    { home, extraGroups ? [ ], description ? name, script, wants ? [ ]
    , noDefaultTarget ? false, ... }: ({
      users = {
        users."${name}" = {
          inherit home extraGroups description;
          createHome = true;
          isSystemUser = true;
          group = name;
        };
        groups."${name}" = { };
      };

      systemd.services."${name}" = let serviceWants = wants;
      in rec {
        inherit script description;
        wantedBy = if noDefaultTarget then [ ] else [ "multi-user.target" ];
        requires = serviceWants;
        after = requires;

        serviceConfig = {
          User = "${name}";
          Group = "${name}";
          Restart = "on-failure";
          WorkingDirectory = "~";
          RestartSec = "10s";

          # This makes all non-kernel (e.g. devfs) filesystems read-only so we need to whitelist our ${home} path
          ProtectSystem = "strict";
          ReadWritePaths = [ home ];
          CapabilityBoundingSet = "";
          DeviceAllow = [ ];
          NoNewPrivileges = "true";
          ProtectControlGroups = "true";
          ProtectClock = "true";
          PrivateDevices = "true";
          PrivateUsers = "true";
          PrivateTmp = "true";
          ProtectHome = "true";
          ProtectHostname = "true";
          ProtectKernelLogs = "true";
          ProtectKernelModules = "true";
          ProtectKernelTunables = "true";
          RemoveIPC = "true";
          ProtectProc = "invisible";
          RestrictAddressFamilies = [ "~AF_UNIX" "~AF_NETLINK" ];
          RestrictSUIDSGID = "true";
          RestrictRealtime = "true";
          LockPersonality = "true";
          SystemCallArchitectures = "native";
          ProcSubset = "pid";
          SystemCallFilter = [
            "~@reboot"
            "~@module"
            "~@mount"
            "~@swap"
            "~@resources"
            "~@cpu-emulation"
            "~@obsolete"
            "~@debug"
            "~@privileged"
          ];
          RestrictNamespaces = [
            "~CLONE_NEWCGROUP"
            "~CLONE_NEWIPC"
            "~CLONE_NEWNET"
            "~CLONE_NEWNS"
            "~CLONE_NEWPID"
            "~CLONE_NEWUTS"
            "~CLONE_NEWUSER"
          ];
          UMask = "077";
        };
      };
    });
}
