# Development environment

Used for `core/` (the `kaericed` daemon). The QML shell itself needs nothing from here.

## Prerequisites

- [Nix](https://nixos.org/download/) with `nix-command` and `flakes` enabled.
- Optional: [direnv](https://direnv.net/) and nix-direnv 3.2.0 or newer.

## Getting started

1. `nix develop` enters the devshell (the first run downloads the Rust toolchain).
2. `run-tests` runs the daemon tests.
3. `./install.sh` builds the daemon with `nix build` and installs the systemd unit.

Nix only sees files that git knows about: `git add` new files before any Nix command.

Cargo manages the Rust libraries and `core/Cargo.lock` pins them. `flake.lock` pins the toolchain.

## Automatic activation with direnv

1. `nix profile add nixpkgs#nix-direnv`, then source its `direnvrc` in `~/.config/direnv/direnvrc`.
2. `direnv allow` in this folder.

## Daily commands

| Command     | Purpose                                                     |
| ----------- | ----------------------------------------------------------- |
| `run-tests` | daemon tests on a private D-Bus (does not touch the system) |
| `fmt`       | format `core/`, `nix/`, `flake.nix`, and `env.md`           |
| `check`     | Nix checks: formatting and hooks                            |
| `doctor`    | toolchain versions                                          |

## Formatter and hooks

treefmt uses rustfmt (edition 2024), taplo, nixfmt, prettier (`env.md`), and shfmt. Older files (`hypr/`, `quickshell/`,
`tests/`, `systemd/`, `docs/`, `README.md`, `install.sh`) are excluded. Entering the devshell installs the pre-commit hook:
treefmt and a conflict marker check.

## Updating dependencies

- Rust libraries: `cargo update` in `core/`, then `run-tests`.
- Toolchain: `nix flake update`, only when it is really needed.

## References

- [devshell](https://github.com/numtide/devshell)
- [nix-direnv](https://github.com/nix-community/nix-direnv)
- [treefmt-nix](https://github.com/numtide/treefmt-nix)
- [git-hooks.nix](https://github.com/cachix/git-hooks.nix)
