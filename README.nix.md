# EmuDeck Nix Flake

This flake provides a way to build and run EmuDeck as a native Nix package without using AppImage.

## Features

- Builds EmuDeck as a proper Nix derivation
- Uses system Electron instead of bundled binary
- Includes desktop entry and icon
- Can be installed system-wide or run directly
- No AppImage overhead

## Usage

### Running directly (without installing)

```bash
nix run .#
```

### Installing to your system (NixOS)

Add to your `configuration.nix` or flake:

```nix
{
  inputs.emudeck.url = "path:/home/alnav/tmp/emudeck-electron";
  # or from git:
  # inputs.emudeck.url = "github:EmuDeck/emudeck-electron";
}
```

Then in your packages:

```nix
environment.systemPackages = [
  inputs.emudeck.packages.${system}.default
];
```

### Installing for current user

```bash
nix profile install .#
```

### Development

Enter the development shell:

```bash
nix develop
```

Then run normal npm commands:

```bash
npm install
npm start
```

## Building

Build the package:

```bash
nix build .#
```

The result will be in `./result/`:

- Binary: `./result/bin/emudeck`
- App files: `./result/lib/emudeck/`
- Desktop entry: `./result/share/applications/emudeck.desktop`

## Structure

- `flake.nix` - Main Nix flake configuration
- The package uses `buildNpmPackage` to build the Electron app
- Electron is provided by nixpkgs (no download required)
- GUI components submodule is fetched during build

## Differences from AppImage

- ✅ Better integration with system (desktop entries, icons)
- ✅ Uses system libraries where possible
- ✅ Smaller closure size (shared dependencies)
- ✅ Can be updated through Nix
- ✅ No FUSE required
- ✅ Follows NixOS conventions

## Troubleshooting

### Git tree is dirty warning

This is normal during development. The warning appears when uncommitted changes exist. To suppress it, commit your changes:

```bash
git add flake.nix
git commit -m "Add Nix flake"
```

### Build fails with hash mismatch

If dependencies change, you may need to update the `npmDepsHash`. Simply run `nix build` and it will tell you the correct hash to use.

### Submodule hash mismatch

If the GUI components submodule changes, update the hash in `flake.nix`:

```bash
nix-shell -p nix-prefetch-git --run \
  "nix-prefetch-git --url https://github.com/EmuDeck/emudeck-gui-components.git --rev <COMMIT_HASH>"
```

Then update the `sha256` value in the `fetchgit` call.
