{ ... }:
{
  projectRootFile = "flake.nix";
  programs = {
    nixfmt.enable = true;
    rustfmt = {
      enable = true;
      edition = "2024";
    };
    taplo.enable = true;
    prettier = {
      enable = true;
      includes = [
        "*.md"
        "*.yaml"
        "*.yml"
        "*.json"
      ];
    };
    shfmt.enable = true;
  };
  settings = {
    global.excludes = [
      ".direnv/**"
      ".git/**"
      ".pre-commit-config.yaml"
      "flake.lock"
      "core/Cargo.lock"
      "core/target/**"
      # existing files keep their own style
      "hypr/**"
      "quickshell/**"
      "tests/**"
      "systemd/**"
      "wallpapers/**"
      "docs/**"
      "README.md"
      "CLAUDE.md"
      "TODO.md"
      "install.sh"
    ];
    formatter.shfmt.includes = [
      "*.sh"
      ".envrc"
    ];
  };
}
