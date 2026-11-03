{ config, lib, pkgs, ... }:

let
  cfg = config.mahmooz.quickshell;
  inherit (lib) mkOption mkEnableOption mkIf mkDefault mkMerge types;

  # runs with the wayland session and stops with it
  sessionService = {
    partOf = [ cfg.target ];
    after = [ cfg.target ];
    wantedBy = [ cfg.target ];
    unitConfig.ConditionEnvironment = "WAYLAND_DISPLAY";
    serviceConfig.Restart = "on-failure";
  };
in
{
  options.mahmooz.quickshell = {
    enable = mkEnableOption "the quickshell desktop shell and everything it depends on";

    liveDir = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "checkout used instead of the bundled config when present, so edits hot reload";
    };

    wallpaperDir = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "folder the wallpaper picker browses, defaults to $data/images/wal";
    };

    env = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "defaults for the shell's environment, see Config.qml for what it reads";
    };

    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [ ];
      description = "extra tools on the shell's PATH only";
    };

    target = mkOption {
      type = types.str;
      default = "graphical-session.target";
      description = "systemd target the shell and clipboard services are tied to";
    };

    package = mkOption {
      type = types.package;
      readOnly = true;
      description = "the wrapped qs, also the one to use for `qs ipc call`";
    };
  };

  config = mkMerge [
    {
      mahmooz.quickshell.package = pkgs.callPackage ./package.nix {
        inherit (cfg) liveDir extraPackages;
        env = cfg.env // lib.optionalAttrs (cfg.wallpaperDir != null) {
          QS_WALLPAPER_DIR = cfg.wallpaperDir;
        };
      };
    }

    (mkIf cfg.enable {
      environment.systemPackages = [ cfg.package pkgs.adw-gtk3 ];
      fonts.packages = [ pkgs.material-symbols ];
      services.upower.enable = mkDefault true;
      # gsettings writes the gtk theme and color scheme through dconf
      programs.dconf.enable = mkDefault true;

      systemd.user.services.quickshell = mkMerge [
        sessionService
        {
          description = "quickshell desktop shell";
          # the user manager's PATH is minimal and apps launched from the shell inherit this
          enableDefaultPath = false;
          environment.PATH = lib.concatStringsSep ":" [
            "/run/wrappers/bin"
            "/etc/profiles/per-user/%u/bin"
            "%h/.nix-profile/bin"
            "%h/.local/bin"
            "/run/current-system/sw/bin"
          ];
          serviceConfig.ExecStart = lib.getExe cfg.package;
        }
      ];

      # feeds the launcher's clipboard mode
      systemd.user.services.cliphist = mkMerge [
        sessionService
        {
          description = "clipboard history";
          serviceConfig.ExecStart = "${lib.getExe' pkgs.wl-clipboard "wl-paste"} --watch ${lib.getExe pkgs.cliphist} store";
        }
      ];
    })
  ];
}
