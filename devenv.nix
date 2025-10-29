{ config, inputs, lib, pkgs, ... }:

let
  # Source of truth.
  # Automatically propagates to src-tauri/Cargo.toml and src-quasar/package.json
  application-version = "0.0.0";

  pkgs-unstable = import inputs.nixpkgs-unstable {
    overlays = [ inputs.rust-overlay.overlays.default ];
    system = pkgs.stdenv.system;
  };
in {
  cachix.enable = false;

  # Nix can't (or I can't) expand the $HOME variable during evaluation,
  # so the environment variable ends up containing the literal $HOME
  # string instead of the expanded/resolved value of the user's home directory.
  # Because of this, we're setting the variable from the context of the shell.
  enterShell = ''
    export SOPS_AGE_KEY_FILE=$HOME/.config/age/identities.txt
  '';

  env = {
    AGE_ROOT_PUBLIC_KEY =
      "age1zwls895rxugu2kf6f4ys6pgl36e3k7dx4djt3dl9ckdmcgg3naaqs9qjae";

    APPLE_SIGNING_SECRETS_FILE =
      "${config.env.DEVENV_ROOT}/encrypted/apple-signing.sops.json";

    BIOME_BINARY = "${pkgs.biome}/bin/biome";

    CARGO_TARGET_DIR = "${config.env.TAURI_ROOT}/target";

    PINIA_STORE_PATH = "${config.env.DEVENV_STATE}/pinia";

    QUASAR_ROOT = "${config.env.DEVENV_ROOT}/src-quasar";

    ROOT_KEY_FILE = "${config.env.DEVENV_ROOT}/encrypted/root-key.sops.json";

    TAURI_ROOT = "${config.env.DEVENV_ROOT}/src-tauri";

    TAURI_UPDATER_KEY_FILE =
      "${config.env.DEVENV_ROOT}/encrypted/tauri-updater.sops.json";
  };

  languages = {
    javascript = {
      enable = true;

      bun = {
        enable = true;

        install.enable = false;
      };

      directory = "${config.env.QUASAR_ROOT}";
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

      eslint = {
        after = [ "biome" ];
        args = [ "-c" "${config.env.QUASAR_ROOT}/eslint.config.js" ];
        enable = true;
        fail_fast = true;
        files = "\\.(ts|js|mjs|cjs|vue)$";

        settings = {
          binPath = "${config.env.QUASAR_ROOT}/node_modules/.bin/eslint";
        };
      };

      rustfmt = {
        after = [ "eslint" ];
        enable = true;
        fail_fast = true;
      };
    };

    settings.rust.cargoManifestPath = "${config.env.TAURI_ROOT}/Cargo.toml";
  };

  outputs = let
    validateTarget = name: target:
      let
        required = [ "rustTarget" "stdenv" ];
        missing =
          builtins.filter (attr: !builtins.hasAttr attr target) required;
      in lib.asserts.assertMsg (missing == [ ])
      "Invalid target '${name}': missing attributes: ${
        lib.concatStringsSep ", " missing
      }";

    mkTarget = systemStr:
      { rustTargetOverride ? null, cross ? false }:
      let
        platform = pkgs.lib.systems.elaborate systemStr;
        rustTarget = if rustTargetOverride != null then
          rustTargetOverride
        else
          platform.rust.rustcTarget;
        stdenv' = if cross then pkgs.pkgsCross.mingwW64.stdenv else pkgs.stdenv;
      in {
        platform = platform;
        rustTarget = rustTarget;
        arch = platform.parsed.cpu.name;
        stdenv = stdenv';
      };

    targets = {
      linux = mkTarget "x86_64-linux" { };

      macos = mkTarget "aarch64-darwin" { };

      windows = {
        rustTarget = "x86_64-pc-windows-msvc";
        stdenv =
          pkgs.stdenv; # Need this for ...-windows-gnu: pkgs.pkgsCross.mingwW64.stdenv;
      };
    };

    buildForTarget = { rustTarget, stdenv, ... }:
      let
        isWindowsGnu = rustTarget == "x86_64-pc-windows-gnu";
        isWindowsMsvc = rustTarget == "x86_64-pc-windows-msvc";

        rustToolchain = pkgs-unstable.rust-bin.stable.latest.default.override {
          extensions = [ "rust-src" ];
          targets = [ rustTarget ];
        };

        # Cross pkgs for Windows
        winPkgs = pkgs.pkgsCross.mingwW64;

        # IMPORTANT: use makeRustPlatform from the *same pkgs set* as stdenv
        # so that cross metadata is consistent
        rustPlatform = if isWindowsGnu then
          winPkgs.makeRustPlatform {
            cargo = rustToolchain;
            rustc = rustToolchain;
          }
        else
          pkgs.makeRustPlatform {
            cargo = rustToolchain;
            rustc = rustToolchain;
          };

        nativeBuildInputs = [
          pkgs.cargo-tauri
          pkgs.rsync
          pkgs.bun
          inputs.bun2nix.packages."${pkgs.stdenv.system}".default
          pkgs.makeWrapper
          pkgs.pkg-config
        ] ++ lib.optionals stdenv.hostPlatform.isDarwin [
          pkgs.darwin.DarwinTools # Provides sw_vers, "needed" (wanted) for building MacOS app
        ] ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux
          [ pkgs.wrapGAppsHook4 ]
          ++ lib.optionals isWindowsMsvc [ pkgs.cargo-xwin pkgs.lld pkgs.nsis ];
      in rustPlatform.buildRustPackage (finalAttrs: {
        inherit stdenv;
        inherit nativeBuildInputs;

        auditable = false;

        pname = "dirtywave-updater";
        version = application-version;
        src = lib.cleanSource ./.;

        doCheck = false;
        dontTauriInstall = true;
        dontPatchElf = isWindowsGnu || isWindowsMsvc;

        postPatch = ''
          rsync -a --copy-links --chmod=ugo+w --exclude=".bin" ${finalAttrs.bunNodeModules}/node_modules/ src-quasar/node_modules/

          mkdir -p src-quasar/node_modules/.bin

          for target in ${finalAttrs.bunNodeModules}/node_modules/.bin/*; do
            name=$(basename "$target")
            real=$(readlink -f "$target")

            rm -f "src-quasar/node_modules/.bin/$name"

            # makeWrapper ${pkgs.nodejs}/bin/node "src-quasar/node_modules/.bin/$name" \
            makeWrapper ${pkgs.bun}/bin/bun "src-quasar/node_modules/.bin/$name" \
              --add-flags "$real"
          done
        '';

        buildInputs = lib.optionals isWindowsGnu [
          winPkgs.buildPackages.gcc
          winPkgs.windows.mingw_w64
          winPkgs.windows.mcfgthreads
          winPkgs.windows.pthreads
        ];

        preBuild = ''
          export PATH="${finalAttrs.bunNodeModules}/bin:${pkgs.bun}/bin:$PATH"

          export HOME=$(mktemp -d)
        '' + lib.optionalString isWindowsGnu ''
          export CARGO_TARGET_X86_64_PC_WINDOWS_GNU_LINKER="${winPkgs.buildPackages.gcc}/bin/x86_64-w64-mingw32-gcc"
          export PATH="${winPkgs.buildPackages.gcc}/bin:$PATH"
          export PKG_CONFIG_ALLOW_CROSS=1

          # For crates that compile C code (via cc-rs)
          export CC_x86_64_pc_windows_gnu="$CARGO_TARGET_X86_64_PC_WINDOWS_GNU_LINKER"
          export CXX_x86_64_pc_windows_gnu="${winPkgs.buildPackages.gcc}/bin/x86_64-w64-mingw32-g++"
          export AR_x86_64_pc_windows_gnu="${winPkgs.buildPackages.gcc}/bin/x86_64-w64-mingw32-ar"
        '';

        buildPhase = ''
          runHook preBuild

          ${lib.optionalString (isWindowsGnu || isWindowsMsvc) ''
            ./src-tauri/scripts/build/unix/beforeBuildCommand.sh

            rm ./src-tauri/tauri.windows.conf.json
          ''}

          cargoBuildType="''${cargoBuildType:-release}"
          export "CARGO_PROFILE_''${cargoBuildType@U}_STRIP"=false

          # Keep outputs outside subdir; Tauri respects CLI args better than env here
          CARGO_TARGET_DIR="$(pwd)/target"
          export CARGO_TARGET_DIR

          pushd src-tauri

          TAURI_FLAGS=( --no-bundle --target ${rustTarget} )
          ${lib.optionalString isWindowsMsvc
          "TAURI_FLAGS+=( --runner cargo-xwin )"}

          CARGO_FLAGS=( -j ''${NIX_BUILD_CORES} --offline --profile "''${cargoBuildType}" --target ${rustTarget} )

          echo "tauri build flags: ''${TAURI_FLAGS[*]}"
          echo "cargo flags: ''${CARGO_FLAGS[*]}"

          ${lib.getExe rustToolchain} --version || true
          cargo tauri build "''${TAURI_FLAGS[@]}" -- "''${CARGO_FLAGS[@]}"

          popd

          runHook postBuild
        '';

        installPhase = let
          exeSuffix = lib.optionalString (isWindowsGnu || isWindowsMsvc) ".exe";
        in ''
          runHook preInstall

          mkdir -p $out/bin

          # Copy the built binary, with .exe suffix when targeting Windows
          cp target/${rustTarget}/release/dirtywave-updater${exeSuffix} $out/bin/

          mkdir -p $out/share/build

          cp -r src-tauri $out/share/build/

          if [ -d src-quasar/dist ]; then
            cp -r src-quasar/dist $out/share/build/src-quasar/
          fi

          ${lib.optionalString isWindowsMsvc ''
            mkdir -p $out/dist

            if [ -d target/${rustTarget}/release/bundle/nsis ] && \
              [ "$(ls -A target/${rustTarget}/release/bundle/nsis)" ]; then
              cp -r target/${rustTarget}/release/bundle/nsis/* $out/dist/
            fi
          ''}

          runHook postInstall
        '';

        cargoLock = { lockFile = ./src-tauri/Cargo.lock; };

        bunNodeModules =
          inputs.bun2nix.lib."${pkgs.stdenv.system}".mkBunNodeModules {
            packages = import ./src-quasar/bun.nix;
          };

        cargoRoot = "src-tauri";

        buildAndTestSubdir = finalAttrs.cargoRoot;
      });

    bundleForTarget = { rustTarget, stdenv, ... }:
      buildDrv:
      let
        isWindowsGnu = rustTarget == "x86_64-pc-windows-gnu";
        isWindowsMsvc = rustTarget == "x86_64-pc-windows-msvc";

        # Dummy minisign keypair for pure builds (do not use for production)
        # These are plain strings checked into the store; safe only for dummy use.
        # pubkey format is the full minisign public key line (base64), private key is the full minisign secret key file content.
        dummyUpdaterSecrets = {
          publicKey =
            "dW50cnVzdGVkIGNvbW1lbnQ6IG1pbmlzaWduIHB1YmxpYyBrZXk6IEI3MDYyQzU3MzI3Mjc4OEYKUldTUGVISXlWeXdHdC8zajRaa2QvWHZ1elpIZTVrOU1LUGNlMDVRZDVBQlhkd0Z4TDNpc1pjdkoK";

          privateKey =
            "dW50cnVzdGVkIGNvbW1lbnQ6IHJzaWduIGVuY3J5cHRlZCBzZWNyZXQga2V5ClJXUlRZMEl5ekZuOVEvYmlVc2FScmthOVFVVmhDRWN0NE9BOG83ZWYvY1F1djlpeTdKOEFBQkFBQUFBQUFBQUFBQUlBQUFBQWc4Y3hObUFNZEpjT3o3OStWaWZhVXFGalVscGxYVm43RlU3cW1FanpJMWtMSElFWWxRUlBydVV0T2VWYmJWVllDakJHRUZxUzl3VHpjOG45RDQ3U1hWRkNLNlpHNTZBZDROWVV5RFZtQTAzdkJuZUNodVk4Z3JHSEU4emRBNzI5cDl4OXA3ZGhwSGs9Cg==";

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
      in pkgs.stdenv.mkDerivation {
        pname = "dirtywave-updater-bundle";
        version = application-version;
        inherit stdenv;
        src = buildDrv;

        nativeBuildInputs = [ pkgs.cargo pkgs.rustc pkgs.cargo-tauri ]
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
          ] ++ lib.optionals (isWindowsGnu || isWindowsMsvc) [ pkgs.nsis ];

        buildPhase = ''
          mkdir -p .bin

          ${lib.optionalString (isWindowsGnu || isWindowsMsvc) ''
            ln -s ${pkgs.nsis}/bin/makensis .bin/makensis.exe
            export PATH=$PWD/.bin:$PATH
          ''}

          cp -r $src/share/build/* .

          chmod -R u+w .

          rm -rf src-tauri/target

          mkdir -p src-tauri/target/${rustTarget}/release
          mkdir -p src-tauri/target/release

          if [[ "${rustTarget}" = x86_64-pc-windows-* ]]; then
            cp $src/bin/dirtywave-updater.exe src-tauri/target/${rustTarget}/release/
          else
            cp $src/bin/dirtywave-updater src-tauri/target/${rustTarget}/release/
          fi

          # Export dummy updater signing secrets to satisfy Tauri updater plugin.
          # We sign For Real™ in a later step of the process.
          export TAURI_SIGNING_PRIVATE_KEY_PASSWORD="${dummyUpdaterSecrets.password}"
          export TAURI_SIGNING_PRIVATE_KEY="${dummyUpdaterSecrets.privateKey}"

          # --skip-jenkins # skip Finder-prettifying AppleScript, useful in Sandbox and non-GUI environments \
          export CI=true

          cargo-tauri bundle \
            --config '{ "bundle": { "useLocalToolsDir": true }, "plugins": { "updater": { "pubkey": "${dummyUpdaterSecrets.publicKey}" } } }' \
            --target ${rustTarget} \
            ${
              lib.optionalString ((rustTarget == "aarch64-apple-darwin")
                || (rustTarget == "x86_64-apple-darwin"))
              "--bundles app,dmg -v \\"
            }
            ${
              lib.optionalString (isWindowsGnu || isWindowsMsvc)
              "--bundles nsis"
            } 
        '';

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
  in {
    dirtywave-updater = {
      build = pkgs.lib.mapAttrs
        (name: target: assert validateTarget name target; buildForTarget target)
        targets;

      bundle = pkgs.lib.mapAttrs (name: target:
        let build = config.outputs.dirtywave-updater.build.${name};
        in assert validateTarget name target; bundleForTarget target build)
        targets;
    };
  };

  packages = [
    inputs.bun2nix.packages."${pkgs.stdenv.system}".default
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

    get-latest-git-tag.exec =
      "git describe --tags --abbrev=0 2>/dev/null || echo ";

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

        BASE_URL="https://github.com/euphemism/dirtywave-updater-releases-mirror/releases/download/''${VERSION}"

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

      packages = [ pkgs.jq pkgs.coreutils ];
    };

    quasar-cli.exec = ''frontend bunx @quasar/cli "$@"'';

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

      packages = [ pkgs.jq pkgs-unstable.sops ];
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
