{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    nodejs
    p7zip
    file
    fuse
    appimage-run
    electron
    squashfsTools
  ];

  shellHook = ''
    echo "EmuDeck build environment loaded"
    echo "Node version: $(node --version)"
    echo "NPM version: $(npm --version)"
    
    # Disable nix-ld to avoid conflicts with AppImage tools
    export NIX_LD=""
    export NIX_LD_LIBRARY_PATH=""
  '';
}
