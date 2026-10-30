{
  lib,
  stdenvNoCC,
  fetchurl,
  buildFHSEnv,
  makeDesktopItem,
}:

let
  source = lib.importJSON ./source.json;
  pname = "horizon-launcher";
  inherit (source) version;

  # The launcher downloads game builds and Mojang's Java runtimes and runs them.
  # Those are ordinary Linux binaries, so the launcher runs inside an FHS
  # environment where they find /lib64/ld-linux-x86-64.so.2 and their libraries.
  unwrapped = stdenvNoCC.mkDerivation {
    pname = "${pname}-unwrapped";
    inherit version;

    src = fetchurl {
      url = "https://github.com/horizon-rust/horizon/releases/download/launcher@${version}/horizon-launcher-linux-x86_64.tar.gz";
      inherit (source) hash;
    };

    sourceRoot = ".";

    dontConfigure = true;
    dontBuild = true;
    dontStrip = true;
    dontPatchELF = true;

    installPhase = ''
      runHook preInstall
      install -Dm755 horizon-launcher $out/bin/horizon-launcher
      runHook postInstall
    '';
  };

  desktopItem = makeDesktopItem {
    name = pname;
    desktopName = "Horizon";
    genericName = "Game launcher";
    comment = "Install, prepare and play Horizon, Minecraft: Java Edition rewritten in Rust";
    exec = pname;
    icon = "horizon";
    categories = [ "Game" ];
    startupWMClass = "horizon-launcher";
  };
in
buildFHSEnv {
  inherit pname version;

  targetPkgs =
    pkgs: with pkgs; [
      # Launcher and game windows (winit + wgpu)
      vulkan-loader
      libglvnd
      wayland
      libxkbcommon
      libx11
      libxcb
      libxcursor
      libxext
      libxi
      libxrandr
      libxrender
      libxxf86vm

      # Game input and sound. The host's /etc/alsa config routes ALSA to
      # PipeWire or PulseAudio through its own plugins.
      udev
      alsa-lib

      # Fonts, D-Bus (keyring), opening links, process checks
      fontconfig
      freetype
      dbus
      xdg-utils
      procps

      # Mojang's Java runtime, which prepares the game's resources
      zlib
      libxtst

      # The launcher's optional GameMode toggle
      gamemode
    ];

  runScript = "${unwrapped}/bin/horizon-launcher";

  # Nix updates the launcher, so it must not replace itself in the read-only
  # store. Menu entries it writes for instances call the wrapper on PATH, which
  # survives updates and garbage collection, rather than a store path.
  profile = ''
    export HORIZON_LAUNCHER_NO_SELF_UPDATE=1
    export HORIZON_LAUNCHER_DESKTOP_EXEC="''${HORIZON_LAUNCHER_DESKTOP_EXEC:-${pname}}"
  '';

  extraInstallCommands = ''
    install -Dm444 ${desktopItem}/share/applications/${pname}.desktop -t $out/share/applications
    install -Dm444 ${./assets/horizon.svg} $out/share/icons/hicolor/scalable/apps/horizon.svg
    install -Dm444 ${./assets/horizon-256.png} $out/share/icons/hicolor/256x256/apps/horizon.png
  '';

  passthru = { inherit unwrapped; };

  meta = {
    description = "Launcher for Horizon, Minecraft: Java Edition rewritten in Rust";
    longDescription = ''
      Installs, prepares, updates and plays Horizon, an unofficial rewrite of
      Minecraft: Java Edition in Rust. Horizon prepares its resources from your
      own copy of Minecraft: Java Edition.
    '';
    homepage = "https://playhorizon.dev";
    changelog = "https://github.com/horizon-rust/horizon/releases/tag/launcher@${version}";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = pname;
  };
}
