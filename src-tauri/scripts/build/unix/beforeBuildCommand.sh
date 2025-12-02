#!/usr/bin/env bash
set -euo pipefail

# Inside Nix, the frontend is already built as a separate derivation
if [ -n "${NIX_BUILD_TOP:-}" ]; then
  echo "beforeBuildCommand: skipping frontend build inside Nix"

  exit 0
fi

cd ./src-frontend

pnpm run build
