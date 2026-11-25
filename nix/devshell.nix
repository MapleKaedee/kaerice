{
  pkgs,
  treefmt,
  hooks,
  ...
}:
{
  devshell = {
    name = "kaerice";
    packages = [
      pkgs.git
      pkgs.direnv
      pkgs.nix-direnv
      pkgs.cargo
      pkgs.rustc
      pkgs.clippy
      pkgs.rust-analyzer
      pkgs.rustfmt
      pkgs.gcc
      pkgs.dbus
      treefmt.config.build.wrapper
    ]
    ++ hooks.enabledPackages;
    startup.git-hooks.text = ''
      if ${pkgs.git}/bin/git rev-parse --git-dir >/dev/null 2>&1; then
        ${hooks.shellHook}
      fi
    '';
  };

  env = [
    {
      name = "RUST_SRC_PATH";
      value = "${pkgs.rustPlatform.rustLibSrc}";
    }
  ];

  commands = [
    {
      name = "doctor";
      category = "Quality";
      help = "Print toolchain versions";
      command = ''
        set -euo pipefail
        cargo --version
        rustc --version
        cargo clippy --version
      '';
    }
    {
      name = "run-tests";
      category = "Quality";
      help = "Run the daemon tests on a private D-Bus session";
      command = ''
        set -euo pipefail
        cd "$PRJ_ROOT/core"
        exec dbus-run-session --config-file=${pkgs.dbus}/share/dbus-1/session.conf -- cargo test "$@" -- --include-ignored
      '';
    }
    {
      name = "fmt";
      category = "Quality";
      help = "Format source files with treefmt";
      command = ''exec ${treefmt.config.build.wrapper}/bin/treefmt "$@"'';
    }
    {
      name = "check";
      category = "Quality";
      help = "Run sandboxed Nix and formatting checks";
      command = ''
        set -euo pipefail
        cd "$PRJ_ROOT"
        exec nix flake check "$@"
      '';
    }
  ];
}
