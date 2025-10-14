#!/usr/bin/env bash

# shellcheck source=./quasar.sh
source "$(dirname "$0")/quasar.sh"

cd ./src-quasar || exit

# bun install
bunx @quasar/cli prepare

bunx @quasar/cli build

# run-quasar-command build
