#!/usr/bin/env bash

run-quasar-command() {
    local PREFIX=

    if [ -z "$DEVENV_ROOT" ]; then
        PREFIX="cd ./src-frontend && bun install && bun @quasar/cli"
    else
        PREFIX="quasar-cli"
    fi

    local COMMAND="$PREFIX $*"

    echo "Running command: $COMMAND"

    eval "$COMMAND"
}
