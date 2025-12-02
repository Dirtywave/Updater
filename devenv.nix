{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  # Source of truth.
  # Automatically propagates to src-tauri/Cargo.toml and src-frontend/package.json
  application-version = "0.0.1";

  pkgs-unstable = import inputs.nixpkgs-unstable {
    overlays = [
      inputs.rust-overlay.overlays.default
    ];

    system = pkgs.stdenv.system;
  };
in
{
  cachix.enable = false;

  # Nix can't (or I can't) expand the $HOME variable during evaluation,
  # so the environment variable ends up containing the literal $HOME
  # string instead of the expanded/resolved value of the user's home directory.
  # Because of this, we're setting the variable from the context of the shell.
  enterShell = ''
    export SOPS_AGE_KEY_FILE=$HOME/.config/age/identities.txt
  '';

  env = {
    AGE_ROOT_PUBLIC_KEY = "age1zwls895rxugu2kf6f4ys6pgl36e3k7dx4djt3dl9ckdmcgg3naaqs9qjae";

    APPLE_SIGNING_SECRETS_FILE = "${config.env.DEVENV_ROOT}/encrypted/apple-signing.sops.json";

    BIOME_BINARY = "${pkgs.biome}/bin/biome";

    CARGO_TARGET_DIR = "${config.env.TAURI_ROOT}/target";

    GITHUB_API_TOKEN = "";

    PINIA_STORE_PATH = "${config.env.DEVENV_STATE}/pinia";

    QUASAR_ROOT = "${config.env.DEVENV_ROOT}/src-frontend";

    ROOT_KEY_FILE = "${config.env.DEVENV_ROOT}/encrypted/root-key.sops.json";

    TAURI_ROOT = "${config.env.DEVENV_ROOT}/src-tauri";

    TAURI_UPDATER_KEY_FILE = "${config.env.DEVENV_ROOT}/encrypted/tauri-updater.sops.json";
  };

  languages = {
    javascript = {
      enable = true;

      directory = "${config.env.QUASAR_ROOT}";

      package = pkgs-unstable.nodejs_25;

      pnpm.enable = true;
    };

    rust = {
      enable = true;

      # https://devenv.sh/reference/options/#languagesrustchannel
      channel = "stable";

      targets = [
        "aarch64-apple-darwin"
        "x86_64-apple-darwin"
        "x86_64-pc-windows-gnu"
        "x86_64-unknown-linux-gnu"
      ];

      components = [
        "rustc"
        "cargo"
        "clippy"
        "rustfmt"
        "rust-analyzer"
        "rust-src"
        "rust-std"
      ];
    };

    typescript.enable = true;
  };

  git-hooks = {
    hooks = {
      biome = {
        after = [ "commitizen" ];
        args = [ "--no-errors-on-unmatched" ];
        enable = true;
        fail_fast = true;
      };

      clippy = {
        after = [ "rustfmt" ];
        enable = true;
        settings.offline = lib.mkDefault false;
        extraPackages = [ pkgs.openssl ];
      };

      commitizen = {
        before = [ "biome" ];
        enable = true;
        fail_fast = true;
        # TODO: Temporary mitigation to address commitizen force-pushing over a release and changing the hash. Should be able to remove in a few days (Currently 2025-10-05).
        package = pkgs-unstable.commitizen;
      };

      # eslint = {
      #   after = [ "biome" ];
      #   args = [ "-c" "${config.env.QUASAR_ROOT}/eslint.config.js" ];
      #   enable = true;
      #   fail_fast = true;
      #   files = "\\.(ts|js|mjs|cjs|vue)$";

      #   settings = {
      #     binPath = "${config.env.QUASAR_ROOT}/node_modules/.bin/eslint";
      #   };
      # };

      rustfmt = {
        # after = [ "eslint" ];
        enable = true;
        fail_fast = true;
      };
    };

    settings.rust.cargoManifestPath = "${config.env.TAURI_ROOT}/Cargo.toml";
  };

  outputs =
    let
      validateTarget =
        name: target:
        let
          required = [
            "rustTarget"
            "stdenv"
          ];
          missing = builtins.filter (attr: !builtins.hasAttr attr target) required;
        in
        lib.asserts.assertMsg (
          missing == [ ]
        ) "Invalid target '${name}': missing attributes: ${lib.concatStringsSep ", " missing}";

      mkTarget =
        systemStr:
        {
          rustTargetOverride ? null,
        }:
        let
          platform = pkgs.lib.systems.elaborate systemStr;
          rustTarget = if rustTargetOverride != null then rustTargetOverride else platform.rust.rustcTarget;
        in
        {
          arch = platform.parsed.cpu.name;
          platform = platform;
          rustTarget = rustTarget;
          stdenv = pkgs.stdenv;
        };

      targets = {
        linux = mkTarget "x86_64-linux" { };

        macos = mkTarget "aarch64-darwin" { };
      };

      frontend = pkgs-unstable.stdenv.mkDerivation (finalAttrs: {
        pname = "dirtywave-updater-frontend";

        version = application-version;

        src = pkgs.lib.cleanSource ./src-frontend;

        nativeBuildInputs = [
          pkgs-unstable.nodejs_24
          pkgs-unstable.pnpmConfigHook
          pkgs-unstable.pnpm
        ];

        pnpmDeps = pkgs-unstable.fetchPnpmDeps {
          inherit (finalAttrs) pname version src;
          pnpm = pkgs-unstable.pnpm;
          fetcherVersion = 3;
          hash = "sha256-WAbAxIm2sY/nF9OFMCSwmkbJIOQut3fEY9faimC75Ao=";
        };

        buildPhase = ''
          npm run build
        '';

        installPhase = ''
          mkdir -p $out/dist
          cp -r dist/* $out/dist/
        '';
      });

      buildForTarget =
        {
          frontend,
          rustTarget,
          stdenv,
          ...
        }:
        let
          rustToolchain = pkgs-unstable.rust-bin.stable.latest.default.override {
            extensions = [ "rust-src" ];
            targets = [ rustTarget ];
          };

          rustPlatform = pkgs-unstable.makeRustPlatform {
            cargo = rustToolchain;
            rustc = rustToolchain;
          };

          nativeBuildInputs = [
            pkgs-unstable.cargo-tauri
            pkgs.rsync
            pkgs.makeWrapper
          ]
          ++ lib.optionals stdenv.hostPlatform.isDarwin [
            pkgs.darwin.DarwinTools # Provides sw_vers, "needed" (wanted) for building MacOS app
          ]
          ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.wrapGAppsHook4 ];
        in
        rustPlatform.buildRustPackage (finalAttrs: {
          inherit nativeBuildInputs;
          inherit stdenv;

          allowSubstitutes = false;
          auditable = false;

          pname = "dirtywave-updater";
          version = application-version;
          src = lib.cleanSource ./.;

          doCheck = false;
          dontTauriInstall = true;

          preBuild = ''
            export HOME=$(mktemp -d)

            if [ -d ${frontend}/dist ]; then
              cp -r ${frontend}/dist src-frontend/dist
            fi
          '';

          buildPhase = ''
            runHook preBuild

            cargoBuildType="''${cargoBuildType:-release}"
            export "CARGO_PROFILE_''${cargoBuildType@U}_STRIP"=false

            # Keep outputs outside subdir; Tauri respects CLI args better than env here
            CARGO_TARGET_DIR="$(pwd)/target"
            export CARGO_TARGET_DIR

            pushd src-tauri

            TAURI_FLAGS=( --no-bundle --target ${rustTarget} )

            CARGO_FLAGS=( -j ''${NIX_BUILD_CORES} --offline --profile "''${cargoBuildType}" --target ${rustTarget} --verbose )

            echo "tauri build flags: ''${TAURI_FLAGS[*]}"
            echo "cargo flags: ''${CARGO_FLAGS[*]}"

            # ${lib.getExe rustToolchain} --version || true
            ${rustToolchain}/bin/rustc --version || true

            cargo tauri build "''${TAURI_FLAGS[@]}" -- "''${CARGO_FLAGS[@]}"

            popd

            runHook postBuild
          '';

          installPhase = ''
            runHook preInstall

            mkdir -p $out/bin

            cp target/${rustTarget}/release/dirtywave-updater $out/bin/

            mkdir -p $out/share/build

            cp -r src-tauri $out/share/build/

            # if [ -d src-frontend/dist ]; then
            #   cp -r src-frontend/dist $out/share/build/src-frontend/
            # fi

            # if [ -d ${frontend}/dist ]; then
            #   cp -r ${frontend}/dist $out/share/build/src-frontend/
            # fi
            runHook postInstall
          '';

          cargoLock = {
            lockFile = ./src-tauri/Cargo.lock;
          };

          cargoRoot = "src-tauri";

          buildAndTestSubdir = finalAttrs.cargoRoot;
        });

      bundleForTarget =
        { rustTarget, stdenv, ... }:
        buildDrv:
        let
          # Dummy minisign keypair for pure builds (do not use for production)
          # These are plain strings checked into the store; safe only for dummy use.
          # pubkey format is the full minisign public key line (base64), private key is the full minisign secret key file content.
          dummyUpdaterSecrets = {
            publicKey = "dW50cnVzdGVkIGNvbW1lbnQ6IG1pbmlzaWduIHB1YmxpYyBrZXk6IEI3MDYyQzU3MzI3Mjc4OEYKUldTUGVISXlWeXdHdC8zajRaa2QvWHZ1elpIZTVrOU1LUGNlMDVRZDVBQlhkd0Z4TDNpc1pjdkoK";

            privateKey = "dW50cnVzdGVkIGNvbW1lbnQ6IHJzaWduIGVuY3J5cHRlZCBzZWNyZXQga2V5ClJXUlRZMEl5ekZuOVEvYmlVc2FScmthOVFVVmhDRWN0NE9BOG83ZWYvY1F1djlpeTdKOEFBQkFBQUFBQUFBQUFBQUlBQUFBQWc4Y3hObUFNZEpjT3o3OStWaWZhVXFGalVscGxYVm43RlU3cW1FanpJMWtMSElFWWxRUlBydVV0T2VWYmJWVllDakJHRUZxUzl3VHpjOG45RDQ3U1hWRkNLNlpHNTZBZDROWVV5RFZtQTAzdkJuZUNodVk4Z3JHSEU4emRBNzI5cDl4OXA3ZGhwSGs9Cg==";

            password = "";
          };

          hdiutilWrapper = pkgs.writeShellScriptBin "hdiutil" ''
            echo "Running wrapper script"
            exec /usr/bin/hdiutil "$@"
          '';

          setFileShim = pkgs.writeShellScriptBin "SetFile" ''
            # Fake SetFile wrapper using xattr
            # Supports:
            #   SetFile -c icnC "$MOUNT_DIR/.VolumeIcon.icns"
            #   SetFile -a C "$MOUNT_DIR"

            if [[ $# -lt 2 ]]; then
              echo "usage: SetFile <flags> <target>" >&2
              exit 1
            fi

            flag="$1"; shift

            case "$flag" in
              -c)
                typecode="$1"; shift
                target="$1"; shift
                if [[ "$typecode" == "icnC" ]]; then
                  # No-op: Finder doesn't require type codes anymore.
                  if [[ ! -f "$target" ]]; then
                    echo "error: icon file not found: $target" >&2
                    exit 1
                  fi
                else
                  echo "warning: unhandled type code $typecode" >&2
                fi
                ;;

              -a)
                attrs="$1"; shift
                target="$1"; shift
                if [[ "$attrs" == *C* ]]; then
                  # Set the “has custom icon” bit in FinderInfo
                  xattr -wx com.apple.FinderInfo \
                    "0000000000000000000000000000000000000000000000000000000000000400" \
                    "$target"
                else
                  echo "warning: unhandled attribute flags $attrs" >&2
                fi
                ;;

              *)
                echo "error: unsupported SetFile invocation: $flag $*" >&2
                exit 1
                ;;
            esac
          '';
        in
        pkgs.stdenv.mkDerivation {
          allowSubstitutes = false;
          pname = "dirtywave-updater-bundle";
          version = application-version;
          inherit stdenv;
          src = buildDrv;

          nativeBuildInputs = [
            pkgs.cargo
            pkgs.cargo-tauri
            pkgs.rustc
          ]
          ++ lib.optionals stdenv.hostPlatform.isDarwin [
            (pkgs.writeShellApplication {
              name = "codesign";
              text = ''
                echo "Skipping codesign (pure build)"
                exit 0
              '';
            })
            pkgs.darwin.xattr
            pkgs.darwin.DarwinTools # Provides sw_vers, needed for bundling MacOS DMGs
            pkgs.perl
            hdiutilWrapper
            setFileShim
          ];

          buildPhase =
            let
              patchScript = pkgs.writeShellScriptBin "patch-out-and-bundle-dynamic-libraries" config.scripts.patch-out-and-bundle-dynamic-libraries.exec;
            in
            ''
              mkdir -p .bin

              cp -r $src/share/build/* .

              chmod -R u+w .

              rm -rf src-tauri/target

              mkdir -p src-tauri/target/${rustTarget}/release
              mkdir -p src-tauri/target/release

              # Copy the built binary from the buildDrv
              cp $src/bin/dirtywave-updater src-tauri/target/${rustTarget}/release/

              # Darwin: patch the raw binary *before* Tauri bundles it
              ${lib.optionalString stdenv.hostPlatform.isDarwin ''
                echo "Patching raw binary before bundling"

                frameworks_json=$(
                  ${patchScript}/bin/patch-out-and-bundle-dynamic-libraries \
                    src-tauri/target/${rustTarget}/release/dirtywave-updater \
                    src-tauri/frameworks
                )
              ''}

              frameworks_json="''${frameworks_json:=[]}"

              # Export dummy updater signing secrets to satisfy Tauri updater plugin.
              export TAURI_SIGNING_PRIVATE_KEY_PASSWORD="${dummyUpdaterSecrets.password}"
              export TAURI_SIGNING_PRIVATE_KEY="${dummyUpdaterSecrets.privateKey}"

              export CI=true

              cargo-tauri bundle \
                --config "{
                  \"bundle\": {
                    \"useLocalToolsDir\": true,
                    \"macOS\": { \"frameworks\": $frameworks_json }
                  },
                  \"plugins\": {
                    \"updater\": { \"pubkey\": \"${dummyUpdaterSecrets.publicKey}\" }
                  }
                }" \
                --target ${rustTarget} \
                ${lib.optionalString (
                  (rustTarget == "aarch64-apple-darwin") || (rustTarget == "x86_64-apple-darwin")
                ) "--bundles app,dmg -v \\"}
            '';
          # ${
          #   lib.optionalString (stdenv.hostPlatform.isDarwin) ''
          #     patch-out-and-bundle-dynamic-libraries $(find "src-tauri/target/${rustTarget}/release/bundle" -type d -name "*.app" -print -quit)''
          # }

          installPhase = ''
            mkdir -p $out
            if [ -d "src-tauri/target/${rustTarget}/release/bundle" ]; then
              cp -r src-tauri/target/${rustTarget}/release/bundle/* $out/
            else
              echo "Bundle directory not found!"
              find target -name "bundle" -type d || echo "No bundle directories found"
              exit 1
            fi
          '';
        };
    in
    {
      dirtywave-updater = {
        # inherit frontend;

        build = {
          inherit frontend;
        }
        // pkgs.lib.mapAttrs (
          name: target:
          assert validateTarget name target;
          buildForTarget (target // { frontend = config.outputs.dirtywave-updater.build.frontend; })
        ) targets;

        bundle = pkgs.lib.mapAttrs (
          name: target:
          let
            build = config.outputs.dirtywave-updater.build.${name};
          in
          assert validateTarget name target;
          bundleForTarget target build
        ) targets;
      };
    };

  packages = [
    pkgs.age
    pkgs.cargo-tauri
    pkgs.jq
  ];

  processes.tauri-dev.exec = "tauri-cli dev";

  scripts = {
    age-generate-identity.exec = ''
      AGE_DIR="$HOME/.config/age"
      IDENTITIES_FILE="$AGE_DIR/identities.txt"

      if [ ! -d "$AGE_DIR" ]; then
          echo "- Creating age config directory at $AGE_DIR" | ${pkgs.gum}/bin/gum format

          mkdir -p "$AGE_DIR"
      fi

      echo "- Generating a new age identity" | ${pkgs.gum}/bin/gum format

      NEW_IDENTITY=$(age-keygen 2>/dev/null)

      # NEW_IDENTITY=$(age-keygen 2>/dev/null)

      # Check if the identities file exists
      if [ ! -f "$IDENTITIES_FILE" ]; then
          echo "- Creating identities file at $IDENTITIES_FILE" | ${pkgs.gum}/bin/gum format

          echo "$NEW_IDENTITY" > "$IDENTITIES_FILE"
      else
          echo "- Appending new identity to $IDENTITIES_FILE" | ${pkgs.gum}/bin/gum format

          echo "$NEW_IDENTITY" >> "$IDENTITIES_FILE"
      fi

      echo "- Identity generation complete." | ${pkgs.gum}/bin/gum format

      # Extract the public key from the new identity and print it
      PUBLIC_KEY=$(echo "$NEW_IDENTITY" | grep "^# public key:" | awk '{print $NF}')

      NEW_PUBLIC_KEY_LABEL=$(${pkgs.gum}/bin/gum style --foreground 212 "New Public Key:")
      PUBLIC_KEY_CONTENT=$(${pkgs.gum}/bin/gum style --foreground white "$PUBLIC_KEY")
      KEY_BANNER_CONTENT=$(${pkgs.gum}/bin/gum join --align center --vertical "$NEW_PUBLIC_KEY_LABEL" "" "$PUBLIC_KEY_CONTENT")

      ${pkgs.gum}/bin/gum style --border normal --border-foreground 45 --padding "1 2" "$KEY_BANNER_CONTENT"
    '';

    backend.exec = ''
      (cd ${config.env.TAURI_ROOT} && exec "$@")
    '';

    frontend.exec = ''
      (cd ${config.env.QUASAR_ROOT} && exec "$@")
    '';

    get-latest-git-tag.exec = "git describe --tags --abbrev=0 2>/dev/null || echo ";

    patch-out-and-bundle-dynamic-libraries = {
      exec = ''
        app="$1"
        frameworks_override="''${2:-}"

        echo "app is $app" >&2

        if [ -z "$app" ]; then
          echo "No argument provided" >&2
          exit 1
        fi

        list_store_dylibs() {
          otool -L "$1" \
            | awk '{print $1}' \
            | grep '^/nix/store' \
            || true
        }

        patch_binary() {
          local macho="$1"
          local frameworks="$2"

          mkdir -p "$frameworks"

          install_name_tool -add_rpath "@executable_path/../Frameworks" "$macho" || true

          list_store_dylibs "$macho" | while IFS= read -r dep; do
            [ -z "$dep" ] && continue
            local name="$(basename "$dep")"
            local target="$frameworks/$name"

            if [ ! -e "$target" ]; then
              echo "Copying $dep → $target" >&2
              cp -f "$dep" "$target"
              chmod +w "$target"
              install_name_tool -id "@rpath/$name" "$target"
            fi

            install_name_tool -change "$dep" "@rpath/$name" "$macho"
          done
        }

        # -----------------------------
        # RAW BINARY CASE
        # -----------------------------
        if [ -f "$app" ]; then
          echo "Detected raw binary" >&2

          if [ -n "$frameworks_override" ]; then
            frameworks="$frameworks_override"
          else
            frameworks="$(dirname "$app")/Frameworks"
          fi

          patch_binary "$app" "$frameworks"

          # NEW: recursively patch copied dylibs
          for dylib in "$frameworks"/*.dylib; do
            [ -e "$dylib" ] || continue
            patch_binary "$dylib" "$frameworks"
          done

          # Emit JSON only when override is used
          if [ -n "$frameworks_override" ]; then
            printf '['
            first=1
            for f in "$frameworks"/*.dylib; do
              [ -e "$f" ] || continue
              # rel="''${f#./}"
              rel="frameworks/$(basename "$f")"
              if [ $first -eq 1 ]; then
                printf '"%s"' "$rel"
                first=0
              else
                printf ', "%s"' "$rel"
              fi
            done
            printf ']'
          fi

          exit 0
        fi

        # -----------------------------
        # .APP BUNDLE CASE
        # -----------------------------
        if [ -d "$app" ]; then
          echo "Detected .app bundle" >&2
          frameworks="$app/Contents/Frameworks"
          mkdir -p "$frameworks"

          find "$app/Contents/MacOS" -type f -perm /111 | while IFS= read -r exe; do
            if list_store_dylibs "$exe" | grep -q .; then
              echo "Patching $exe" >&2
              patch_binary "$exe" "$frameworks"
            else
              echo "Skipping $exe (no Nix store references)" >&2
            fi
          done

          for dylib in "$frameworks"/*.dylib; do
            [ -e "$dylib" ] || continue
            patch_binary "$dylib" "$frameworks"
          done

          exit 0
        fi

        echo "Invalid argument: $app" >&2
        exit 1
      '';

      # exec = ''
      #   app="$1"
      #   echo "app is $app"

      #   if [ -z "$app" ]; then
      #     echo "No argument provided" >&2
      #     exit 1
      #   fi

      #   list_store_dylibs() {
      #     otool -L "$1" \
      #       | awk '{print $1}' \
      #       | grep '^/nix/store'
      #   }

      #   patch_binary() {
      #     local macho="$1"
      #     local frameworks="$2"

      #     # Ensure Frameworks dir exists
      #     mkdir -p "$frameworks"

      #     # Add rpath so @rpath works
      #     install_name_tool -add_rpath "@executable_path/../Frameworks" "$macho" || true

      #     list_store_dylibs "$macho" | while IFS= read -r dep; do
      #       [ -z "$dep" ] && continue
      #       local name="$(basename "$dep")"
      #       local target="$frameworks/$name"

      #       if [ ! -e "$target" ]; then
      #         cp -f "$dep" "$target"
      #         chmod +w "$target"
      #         install_name_tool -id "@rpath/$name" "$target"
      #       fi

      #       install_name_tool -change "$dep" "@rpath/$name" "$macho"
      #     done
      #   }

      #   if [ -f "$app" ]; then
      #     # Raw binary case
      #     echo "Detected raw binary"
      #     frameworks="$(dirname "$app")/Frameworks"
      #     patch_binary "$app" "$frameworks"

      #   elif [ -d "$app" ]; then
      #     # .app bundle case
      #     echo "Detected .app bundle"
      #     frameworks="$app/Contents/Frameworks"
      #     mkdir -p "$frameworks"

      #     # Loop over all executables in Contents/MacOS
      #     find "$app/Contents/MacOS" -type f -perm /111 | while IFS= read -r exe; do
      #       if list_store_dylibs "$exe" | grep -q .; then
      #         echo "Patching $exe"
      #         patch_binary "$exe" "$frameworks"
      #       else
      #         echo "Skipping $exe (no Nix store references)"
      #       fi
      #     done

      #     # Recursively patch any bundled dylibs
      #     for dylib in "$frameworks"/*.dylib; do
      #       [ -e "$dylib" ] || continue
      #       patch_binary "$dylib" "$frameworks"
      #     done

      #   else
      #     echo "Invalid argument: $app" >&2
      #     exit 1
      #   fi
      # '';

      # exec = ''
      #   app="$1"

      #   echo "app is $1"

      #   if [ -z "$app" ]; then
      #     echo "No .app found after bundling" >&2
      #     exit 1
      #   fi

      #   frameworks="$app/Contents/Frameworks"
      #   mkdir -p "$frameworks"

      #   list_store_dylibs() {
      #     otool -L "$1" \
      #       | awk '{print $1}' \
      #       | grep '^/nix/store'
      #   }

      #   patch_binary() {
      #     local macho="$1"
      #     install_name_tool -add_rpath "@executable_path/../Frameworks" "$macho" || true

      #     list_store_dylibs "$macho" | while IFS= read -r dep; do
      #       [ -z "$dep" ] && continue
      #       local name="$(basename "$dep")"
      #       local target="$frameworks/$name"

      #       if [ ! -e "$target" ]; then
      #         cp -f "$dep" "$target"
      #         chmod +w "$target"
      #         install_name_tool -id "@rpath/$name" "$target"
      #       fi

      #       install_name_tool -change "$dep" "@rpath/$name" "$macho"
      #     done
      #   }

      #   # Loop over all executables in Contents/MacOS
      #   find "$app/Contents/MacOS" -type f -perm /111 | while IFS= read -r exe; do
      #     if list_store_dylibs "$exe" | grep -q .; then
      #       echo "Patching $exe"
      #       patch_binary "$exe"
      #     else
      #       echo "Skipping $exe (no Nix store references)"
      #     fi
      #   done

      #   # Recursively patch any bundled dylibs
      #   for dylib in "$frameworks"/*.dylib; do
      #     [ -e "$dylib" ] || continue
      #     patch_binary "$dylib"
      #   done
      # '';

      packages = [ pkgs.darwin.cctools ];
    };

    prepare-release = {
      exec = ''
        set -euo pipefail

        usage() {
          echo "Usage: $0 --version <version> --out-dir <dir> [--last-tag <tag>] --platform <name>:<sig-file>:<filename> ..." >&2
          exit 1
        }

        VERSION=""
        OUT_DIR=""
        LAST_TAG=""
        PLATFORMS=()

        while [ $# -gt 0 ]; do
          case "$1" in
            --version)   VERSION="$2"; shift 2 ;;
            --out-dir)   OUT_DIR="$2"; shift 2 ;;
            --last-tag)  LAST_TAG="$2"; shift 2 ;;
            --platform)  PLATFORMS+=("$2"); shift 2 ;;
            --help|-h)   usage ;;
            *) echo "Unknown option: $1" >&2; usage ;;
          esac
        done

        if [ -z "$VERSION" ] || [ -z "$OUT_DIR" ] || [ ''${#PLATFORMS[@]} -eq 0 ]; then
          echo "Missing required arguments" >&2
          usage
        fi

        PUB_DATE="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

        if [ -z "$LAST_TAG" ]; then
          LAST_TAG="$(get-latest-git-tag || true)"
        fi

        if [ -n "$LAST_TAG" ]; then
          NOTES=$(git log --pretty=format:"%s" "$LAST_TAG"..$VERSION \
            | grep -vE '^feat: release [0-9]+\.[0-9]+\.[0-9]+$' || true)
        else
          NOTES="Initial release"
        fi

        NOTES_JSON=$(printf '%s' "$NOTES" | jq -Rs .)

        # Create a new git tag if it doesn't exist
        if ! git rev-parse "$VERSION" >/dev/null 2>&1; then
          git tag -a "$VERSION" -m "Release $VERSION"
        fi

        BASE_URL="https://github.com/Dirtywave/Updater/releases/download/''${VERSION}"

        PLATFORMS_JSON="{}"
        for entry in "''${PLATFORMS[@]}"; do
          name="''${entry%%:*}"
          rest="''${entry#*:}"
          sig_spec="''${rest%%:*}"
          filename="''${rest#*:}"

          if [[ "$sig_spec" == base64=* ]]; then
            # Already a base64 blob
            signature="''${sig_spec#base64=}"
          else
            # Treat as a file path
            if [ ! -f "$sig_spec" ]; then
              echo "Signature file not found: $sig_spec" >&2

              exit 1
            fi
            signature=$(base64 -w0 < "$sig_spec")
          fi

          url="$BASE_URL/$filename"

          PLATFORMS_JSON=$(jq \
            --arg name "$name" \
            --arg sig "$signature" \
            --arg url "$url" \
            '. + {($name): {signature: $sig, url: $url}}' \
            <<<"$PLATFORMS_JSON")
        done

        LATEST_JSON="$OUT_DIR/latest.json"

        jq -n \
          --arg version "$VERSION" \
          --argjson notes "$NOTES_JSON" \
          --arg pub_date "$PUB_DATE" \
          --argjson platforms "$PLATFORMS_JSON" \
          '{
            version: $version,
            notes: $notes,
            pub_date: $pub_date,
            platforms: $platforms
          }' > "$LATEST_JSON"

        echo "Generated latest.json release metadata for $VERSION" >&2

        echo "$LATEST_JSON"
      '';

      packages = [
        pkgs.jq
        pkgs.coreutils
      ];
    };

    quasar-cli.exec = ''frontend bun @quasar/cli "$@"'';

    set-and-sync-package-versions = {
      exec = ''
        set -euo pipefail

        if [ $# -ne 1 ]; then
          echo "Usage: $0 {patch|minor|major}"
          exit 1
        fi

        BUMP_TYPE="$1"

        CURRENT=$(sed -nE 's|^[[:space:]]*application-version = "([^"]+)";.*|\1|p' devenv.nix)

        if [ -z "$CURRENT" ]; then
          echo "Could not determine current version from devenv.nix"
          exit 1
        fi

        # Compute new version using semver-tool
        NEW=$(semver bump "$BUMP_TYPE" "$CURRENT")

        echo "Bumping version: $CURRENT → $NEW" >&2

        # Update devenv.nix
        sed -i -E "s|^([[:space:]]*application-version = \").*(\";)|\1''${NEW}\2|" devenv.nix

        # Update Cargo.toml
        backend sed -i -E "s|^version = \".*\"|version = \"''${NEW}\"|" "Cargo.toml"

        # Update Cargo.lock with the application's new version
        backend cargo update --quiet --workspace

        # Update package.json
        frontend sed -i -E "s|\"version\": *\"[^\"]*\"|\"version\": \"''${NEW}\"|" "package.json"

        echo "''${NEW}"
      '';

      packages = [ pkgs.semver-tool ];
    };

    sign-updater = {
      exec = ''
        set -euo pipefail

        OUT_DIR="."

        if [[ "''${1:-}" == "--out-dir" ]]; then
          OUT_DIR="$2"

          shift 2
        fi

        sign_file() {
          : "''${TAURI_SIGNING_PRIVATE_KEY:?TAURI_SIGNING_PRIVATE_KEY must be set}"
          : "''${TAURI_SIGNING_PRIVATE_KEY_PASSWORD:=}"

          local tmpdir
          tmpdir="$(mktemp -d)"
          trap 'rm -rf "$tmpdir"' EXIT
          local seckey_file="$tmpdir/minisign.key"

          if echo "$TAURI_SIGNING_PRIVATE_KEY" | base64 -d >/dev/null 2>&1; then
            echo "$TAURI_SIGNING_PRIVATE_KEY" | base64 -d >"$seckey_file"
          else
            echo "$TAURI_SIGNING_PRIVATE_KEY" >"$seckey_file"
          fi
          
          local ts fname trusted_comment
          ts=$(date +%s)
          fname=$(basename "$FILE")
          trusted_comment="timestamp:''${ts}\tfile:''${fname}"

          sig_path="$OUT_DIR/$fname.sig"

          if minisign -S \
              -x "$sig_path" \
              -s "$seckey_file" \
              -c "signature from tauri secret key" \
              -t "$trusted_comment" \
              -m "$FILE" \
              <<<"$TAURI_SIGNING_PRIVATE_KEY_PASSWORD" \
              >/dev/null 2>&1
          then
            echo "Signed $FILE -> $sig_path" >&2

            echo "$sig_path"
            # base64 -w0 "$sig_path"
          else
            echo "ERROR: signing failed for $FILE" >&2

            exit 1
          fi
        }

        # Export the function and the captured variables so they're visible inside exec-env
        export -f sign_file
        export OUT_DIR
        export FILE="$1"

        exec sops exec-env "$TAURI_UPDATER_KEY_FILE" 'sign_file'
      '';

      packages = [ pkgs.minisign ];
    };

    # This is a wrapper around SOPS to cleanly work with an envelope encryption approach.
    #
    # There is a root key/identity/age recipient that can decrypt the Tauri updater keys file
    # (./encrypted/tauri-updater.sops.json). _That_ recipient is encrypted via SOPS in the
    # ./encrypted/root-key.sops.json file; the recipients allowed to decrypt the root key are
    # able to be updated out-of-band, without needing to touch or modify anything encrypted by
    # the root recipient. In order to read and operate on data encrypted by the root recipient
    # we must first decrypt the file containing the root recipient's private key, and then use
    # that key to decrypt the data.
    #
    # This wrapper makes that very simple - it detects when the root key was used to encrypt
    # the file being operated upon, and then acquires/configures the root key for use before
    # actually invoking SOPS on the file.
    sops = {
      exec = ''
        set -euo pipefail

        # Forward all args by default
        ARGS=("$@")

        # Try to detect a file argument among the args
        TARGET=""

        for arg in "''${ARGS[@]}"; do
          if [ -f "$arg" ]; then
            TARGET="$arg"

            break
          fi
        done

        if [ -n "$TARGET" ]; then
          # Does it have age metadata?
          if jq -e '.sops.age[].recipient' "$TARGET" >/dev/null 2>&1; then
            # Does it include the root recipient?
            if jq -r '.sops.age[].recipient' "$TARGET" | grep -qF "$AGE_ROOT_PUBLIC_KEY"; then
              export SOPS_AGE_KEY="$(
                sops decrypt --extract '["dirtywaveUpdaterRootPrivateKey"]' "$ROOT_KEY_FILE"
              )"
            fi
          fi
        fi

        exec sops "''${ARGS[@]}"
      '';

      packages = [
        pkgs.jq
        pkgs-unstable.sops
      ];
    };

    sops-set.exec = ''
      set -euo pipefail

      if [ "$#" -ne 3 ]; then
        echo "Usage: sops-set <file> <key> <value>" >&2
        exit 1
      fi

      FILE="$1"
      KEY="$2"
      VALUE="$3"

      # Expand into the canonical sops set command
      # -R = read raw input
      # -s = slurp into a single string
      # . = identity filter
      # This produces a valid JSON string with \n escapes instead of literal newlines.
      exec sops set "$FILE" \
        "[\"$KEY\"]" \
        "$(printf '%s' "$VALUE" | jq -Rs .)"
    '';

    tauri-cli.exec = ''backend cargo-tauri "$@"'';
  };

  tasks = {
    "dirtywave-updater:bootstrap:git-config-sopsdiffer" = {
      before = [ "devenv:enterShell" ];

      exec = ''git config --local diff.sopsdiffer.textconv "sops decrypt"'';

      status = ''
        [ "$(git config --local diff.sopsdiffer.textconv)" = "sops decrypt" ] && exit 0 || exit 1
      '';
    };
  };

  # See full reference at https://devenv.sh/reference/options/
}
