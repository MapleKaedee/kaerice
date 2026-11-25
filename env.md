# Lingkungan pengembangan

Dipakai untuk `core/` (daemon `kaericed`). Shell QML sendiri tidak memerlukan apa pun di sini.

## Prasyarat

- [Nix](https://nixos.org/download/) dengan `nix-command` dan `flakes` aktif.
- Opsional: [direnv](https://direnv.net/) dan nix-direnv 3.2.0 atau lebih baru.

## Memulai

1. `nix develop` masuk ke devshell (pertama kali mengunduh toolchain Rust).
2. `run-tests` menjalankan tes daemon.
3. `./install.sh` membangun daemon dengan `nix build` dan memasang unit systemd.

Nix hanya melihat file yang dikenal git: `git add` file baru sebelum perintah Nix.

Library Rust dikelola cargo dan dikunci `core/Cargo.lock`. Toolchain dikunci `flake.lock`.

## Aktivasi otomatis dengan direnv

1. `nix profile add nixpkgs#nix-direnv`, lalu muat `direnvrc`-nya di `~/.config/direnv/direnvrc`.
2. `direnv allow` di folder ini.

## Perintah harian

| Perintah    | Guna                                                     |
| ----------- | -------------------------------------------------------- |
| `run-tests` | tes daemon di bus D-Bus pribadi (tidak menyentuh sistem) |
| `fmt`       | format `core/`, `nix/`, `flake.nix`, dan `env.md`        |
| `check`     | pemeriksaan Nix: format dan hook                         |
| `doctor`    | versi toolchain                                          |

## Formatter dan hook

treefmt memakai rustfmt (edisi 2024), taplo, nixfmt, prettier (`env.md`), dan shfmt. File lama (`hypr/`, `quickshell/`,
`tests/`, `systemd/`, `docs/`, `README.md`, `install.sh`) dikecualikan. Masuk ke devshell memasang hook pre-commit:
treefmt dan pemeriksaan penanda konflik.

## Memperbarui dependensi

- Library Rust: `cargo update` di `core/`, lalu `run-tests`.
- Toolchain: `nix flake update`, hanya kalau memang diperlukan.

## Referensi

- [devshell](https://github.com/numtide/devshell)
- [nix-direnv](https://github.com/nix-community/nix-direnv)
- [treefmt-nix](https://github.com/numtide/treefmt-nix)
- [git-hooks.nix](https://github.com/cachix/git-hooks.nix)
