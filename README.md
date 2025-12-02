# Dirtywave Updater

## Description

Firmware update tool for the Dirtywave M8 Tracker.

## Contributing

### Development Environment Setup

Follow these steps to set up your development environment:

We recommend using [Visual Studio Code](https://code.visualstudio.com/) as your editor for this project. To ensure that you have the best development experience, please install the workspace-recommended extensions.

The tools below are used for the development environment; a script is provided to install and configure everything needed:

Run `./bootstrap-environment.sh` to get the base tooling in place for automatic environment setup.

#### Prerequisites

- [devenv](https://devenv.sh/)

##### Recommended

- [direnv](https://direnv.net/) - Automatic environment activation (No need to invoke `devenv shell`, and your existing shell is maintained/used)

#### Clone the Repository

```sh
git clone git@github.com:Dirtywave/Updater.git dirtywave-updater
cd dirtywave-updater
```

#### Enter the Development Environment

The first time the environment is loaded, it will take some time to be initialized due to pulling
down dependencies and doing initial building and preparations.

##### With direnv

The environment will automatically activate when entering the repository directory tree.

##### Without direnv

This will start a separate, Bash shell:

```sh
devenv shell
```

#### Starting Application for Development

For Desktop development, run:

```sh
tauri-cli dev
```
