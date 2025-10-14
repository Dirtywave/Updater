{ config, inputs, lib, pkgs, ... }:

let
  pkgs-unstable =
    import inputs.nixpkgs-unstable { system = pkgs.stdenv.system; };
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

        install.enable = true;
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

    quasar-cli.exec = ''
      (cd ${config.env.QUASAR_ROOT} && bunx @quasar/cli "$@")
    '';

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
      exec sops set $FILE \
        "[\"$KEY\"]" "\"$VALUE\""
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
