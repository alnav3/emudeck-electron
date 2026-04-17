{
  description = "EmuDeck - Emulation configuration tool";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    {
      # NixOS module: installs EmuDeck and enables AppImage support via binfmt
      nixosModules.default = { config, lib, pkgs, ... }:
        let
          cfg = config.programs.emudeck;
        in {
          options.programs.emudeck = {
            enable = lib.mkEnableOption "EmuDeck - Emulation configuration tool";
          };

          config = lib.mkIf cfg.enable {
            environment.systemPackages = [
              self.packages.${pkgs.system}.default
            ];

            # Register AppImage binfmt so downloaded AppImages run via appimage-run.
            # This is required because EmuDeck's backend downloads and executes
            # AppImages (e.g. Steam ROM Manager) which can't run natively on NixOS.
            programs.appimage = {
              enable = true;
              binfmt = true;
            };
          };
        };
    } //
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        
        # Pin to Node 20 (LTS) for compatibility
        nodejs = pkgs.nodejs_20;

        # Runtime dependencies that EmuDeck's backend scripts expect
        runtimeDeps = with pkgs; [
          appimage-run
          bash
          coreutils
          curl
          git
          gzip
          jq
          rsync
          unzip
          wget
          zenity
          xdg-utils
        ];
        
        runtimePath = pkgs.lib.makeBinPath runtimeDeps;
        
        # Build the Electron app
        emudeck = pkgs.buildNpmPackage {
          pname = "emudeck";
          version = "2.5.0";

          src = ./.;

          npmDepsHash = "sha256-3pHi0Li1EdXliijZx+mAFJICxBS3yU+pfkEGTCaa/6c=";

          # We need to initialize submodules
          postUnpack = ''
            cd $sourceRoot
            mkdir -p src/renderer/components
            cp -r ${pkgs.fetchgit {
              url = "https://github.com/EmuDeck/emudeck-gui-components.git";
              rev = "4b8503fea14bcfcc36182f968012b521c9a70e82";
              sha256 = "sha256-XCR5WT2bhFR2RdOq4PyP2Lkf5VCeasBBwOKQJgdYZAc=";
            }}/* src/renderer/components/ || true
            cd ..
          '';

          # Patch package.json to remove devEngines
          postPatch = ''
            sed -i '/"devEngines":/,/}/d' package.json
          '';

          # Skip downloading electron during npm install
          ELECTRON_SKIP_BINARY_DOWNLOAD = "1";
          
          # Prevent network access during build
          makeCacheWritable = true;

          # Build commands
          npmBuildScript = "build";

          # Don't run tests during build
          doCheck = false;

          nativeBuildInputs = with pkgs; [
            makeWrapper
            copyDesktopItems
            asar
          ];

          buildInputs = with pkgs; [
            electron
          ];

          # Install phase - copy built files and create wrapper
          installPhase = ''
            runHook preInstall

            mkdir -p $out/lib/emudeck
            mkdir -p $out/bin
            mkdir -p $out/share/applications
            mkdir -p $out/share/icons/hicolor/512x512/apps

            # Pack the app as app.asar so Electron sets app.isPackaged = true.
            # This is critical: without it, all production paths (preload, assets) break.
            asar pack release/app $out/lib/emudeck/app.asar

            # Assets go next to app.asar so process.resourcesPath finds them
            cp -r assets $out/lib/emudeck/assets

            # Wrap electron, pointing at the asar archive.
            # - APPIMAGE suppresses electron-updater's "not an AppImage" error
            # - PATH includes runtime deps so backend scripts find curl, git, jq, etc.
            # - APPIMAGE_EXTRACT_AND_RUN makes AppImages work without FUSE on NixOS
            makeWrapper ${pkgs.electron}/bin/electron $out/bin/emudeck \
              --add-flags "$out/lib/emudeck/app.asar" \
              --set NODE_ENV production \
              --set ELECTRON_FORCE_IS_PACKAGED "1" \
              --set APPIMAGE "$out/bin/emudeck" \
              --set APPIMAGE_EXTRACT_AND_RUN "1" \
              --prefix PATH : "${runtimePath}"

            # Install icon
            if [ -f assets/icon.png ]; then
              cp assets/icon.png $out/share/icons/hicolor/512x512/apps/emudeck.png
            fi

            # Desktop entry
            cat > $out/share/applications/emudeck.desktop << EOF
[Desktop Entry]
Name=EmuDeck
Comment=Emulation configuration tool
Exec=$out/bin/emudeck
Icon=emudeck
Type=Application
Categories=Game;Utility;
Terminal=false
EOF

            runHook postInstall
          '';

          meta = with pkgs.lib; {
            description = "Emulation configuration tool for Steam Deck and Linux";
            homepage = "https://www.emudeck.com";
            license = licenses.mit;
            maintainers = [ ];
            platforms = platforms.linux;
          };
        };

      in {
        packages = {
          default = emudeck;
          emudeck = emudeck;
        };

        # Development shell
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            nodejs
            electron
            git
          ];

          shellHook = ''
            echo "EmuDeck development environment"
            echo "Node: $(node --version)"
            echo "NPM: $(npm --version)"
            echo ""
            echo "Run 'npm install' to install dependencies"
            echo "Run 'npm start' to start the development server"
          '';
        };

        # Apps - allows 'nix run'
        apps.default = {
          type = "app";
          program = "${emudeck}/bin/emudeck";
        };
      }
    );
}
