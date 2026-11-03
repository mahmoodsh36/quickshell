{
  lib,
  symlinkJoin,
  makeWrapper,
  quickshell,
  brightnessctl,
  wlsunset,
  wf-recorder,
  slurp,
  cliphist,
  wl-clipboard,
  libnotify,
  matugen,
  vips,
  jq,
  glib,
  gsettings-desktop-schemas,
  procps,
  coreutils,
  # a checkout that wins over the bundled copy when it exists, so edits hot reload
  liveDir ? null,
  env ? { },
  extraPackages ? [ ],
}:

let
  config = lib.fileset.toSource {
    root = ../.;
    fileset = lib.fileset.unions [
      (lib.fileset.fileFilter (f: f.hasExt "qml") ../.)
      ../theming
    ];
  };

  runtimeDeps = [
    brightnessctl
    wlsunset
    wf-recorder
    slurp
    cliphist
    wl-clipboard
    libnotify
    matugen
    vips
    jq
    glib
    procps
    coreutils
  ] ++ extraPackages;

  # ipc finds the instance by config path, so every qs call must resolve the same one
  pickConfig = ''
    if [ -z "''${QS_CONFIG_PATH-}" ]; then
      export QS_CONFIG_PATH=${config}
      ${lib.optionalString (liveDir != null) ''[ -f ${lib.escapeShellArg liveDir}/shell.qml ] && export QS_CONFIG_PATH=${lib.escapeShellArg liveDir}''}
    fi
  '';

  wrapArgs = lib.escapeShellArgs (
    [
      "--run" pickConfig
      # suffix so programs launched from the shell still prefer the user's own versions
      "--suffix" "PATH" ":" (lib.makeBinPath runtimeDeps)
      "--suffix" "XDG_DATA_DIRS" ":" "${gsettings-desktop-schemas}/share/gsettings-schemas/${gsettings-desktop-schemas.name}"
    ]
    ++ lib.concatLists (lib.mapAttrsToList (k: v: [ "--set-default" k v ]) env)
  );
in
symlinkJoin {
  name = "quickshell-config-${quickshell.version}";
  paths = [ quickshell ];
  nativeBuildInputs = [ makeWrapper ];
  postBuild = ''
    for bin in qs quickshell; do
      wrapProgram $out/bin/$bin ${wrapArgs}
    done
  '';
  passthru = { inherit config runtimeDeps; };
  meta = quickshell.meta // { mainProgram = "qs"; };
}
