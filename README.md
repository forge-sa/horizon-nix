# Horizon Nix Flake

A Nix flake that packages the [Horizon](https://playhorizon.dev) launcher. Horizon is Minecraft: Java Edition 26.3 rewritten in Rust ([source](https://github.com/horizon-rust/horizon)).

Horizon is an unofficial fan project. It is not affiliated with, endorsed by or connected to Mojang Studios or Microsoft. It contains none of Minecraft's code, textures or sounds. The launcher builds them from your own copy of Minecraft: Java Edition, so you need to own the game.

## Quick Start

### Using with Flakes

Add this flake as an input to your `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    horizon = {
      url = "github:forge-sa/horizon-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
```

Then install it in your system configuration:

```nix
{ inputs, pkgs, ... }:
{
  environment.systemPackages = [
    inputs.horizon.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];
}
```

Pass `inputs` to your modules with `specialArgs = { inherit inputs; };` in `nixpkgs.lib.nixosSystem`.

### Home Manager

```nix
home.packages = [
  inputs.horizon.packages.${pkgs.stdenv.hostPlatform.system}.default
];
```

### Overlay

```nix
nixpkgs.overlays = [ inputs.horizon.overlays.default ];
environment.systemPackages = [ pkgs.horizon-launcher ];
```

### Direct Installation

```bash
# Install to your user profile
nix profile add github:forge-sa/horizon-nix

# Or run it once without installing
nix run github:forge-sa/horizon-nix
```

### Without Flakes

```nix
environment.systemPackages = [
  (pkgs.callPackage "${builtins.fetchTarball "https://github.com/forge-sa/horizon-nix/archive/main.tar.gz"}/package.nix" { })
];
```

Once it is installed, start **Horizon** from your app menu or run `horizon-launcher`.

## How It Works

- **FHS environment.** The launcher downloads Horizon game builds and Mojang's Java runtime, then runs them. These are ordinary Linux binaries that expect `/lib64/ld-linux-x86-64.so.2` and libraries in `/usr/lib`. The launcher runs inside a `buildFHSEnv` sandbox that provides them, the same way `steam` works on NixOS. You don't need `programs.nix-ld`.
- **Updates come from Nix.** The launcher's self-update is turned off (`HORIZON_LAUNCHER_NO_SELF_UPDATE=1`) because it can't replace itself in the read-only Nix store. To get a newer launcher, run `nix flake update horizon` and rebuild. Game versions are a separate matter: the launcher installs and updates them in your home folder, as it does on any other distribution.
- **Desktop integration.** The package installs a `horizon-launcher.desktop` entry and the Horizon icon. Menu entries that the launcher creates for instances call `horizon-launcher` from your `PATH`, so they keep working after updates and garbage collection.

## Notes

- **Graphics:** Horizon draws through Vulkan or OpenGL (EGL). On NixOS, `hardware.graphics.enable = true;` is enough (desktop setups enable it by default). On other distributions, you may need [nixGL](https://github.com/nix-community/nixGL) or the distribution's own launcher build.
- **Sound** goes through ALSA. NixOS's PipeWire and PulseAudio modules route ALSA automatically.
- **Old game versions** that prepare with Python need `python3` installed on the host. Your `PATH` is still visible inside the sandbox.
- Only `x86_64-linux` is supported, because upstream ships no other Linux builds.

## Development

```bash
nix build          # build the package into ./result
nix run            # run the launcher
nix fmt            # format the Nix files
.github/update.sh  # bump source.json to the newest launcher release (needs curl, jq, nix)
```

`source.json` holds the launcher version and hash, `package.nix` holds the package, and `assets/` holds the Horizon icon taken from the launcher.

## Automated Maintenance

`.github/workflows/update.yml` runs every 6 hours and can also be started by hand. It looks for a new `launcher@X.Y.Z` release, updates `source.json`, builds the package and commits the change only if the build succeeds. For the commit to go through, set **Settings → Actions → General → Workflow permissions** to *Read and write* on GitHub.

## License

The Nix packaging in this repository is MIT licensed, the same as Horizon.
