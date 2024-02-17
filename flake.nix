{
  description = "Define Git hooks in Nix";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";

  outputs = { self, nixpkgs, flake-utils, pre-commit-hooks }:
    flake-utils.lib.eachDefaultSystem
      (system:
        let pkgs = import nixpkgs { inherit system; };
        in {
          devShells.default = nixpkgs.legacyPackages.${system}.mkShell {
            inherit (self.checks.${system}.pre-commit-check) shellHook;
          };

          checks = {
            fileTests = pkgs.callPackage ./test.nix { builder = self.lib.builder; };
            pre-commit-check = pre-commit-hooks.lib.${system}.run {
              src = ./.;
              hooks = {
                nixpkgs-fmt.enable = true;
              };
            };
          };
        }) // {
      lib.builder = { git, hooks, writeShellScript }:
        let
          singleHook = attrs:
            let
              type = nixpkgs.lib.getAttrFromPath [ "type" ] attrs;
              cmd = nixpkgs.lib.getAttrFromPath [ "cmd" ] attrs;
            in
            "echo '${cmd}' > .git/hooks/${type};";
          createHooks = nixpkgs.lib.concatMapStrings (attrs: singleHook attrs) hooks;
        in
        writeShellScript "nix-commit-hooks-setup" ''
          set -eoux pipefail

          REPO_ROOT=`${git}/bin/git rev-parse --show-toplevel`
          REPO_GIT=`${git}/bin/git rev-parse --path-format=absolute --git-common-dir`

          ${createHooks}
          # Convert the absolute path to a path relative to the toplevel working directory.
          REPO_GIT_RELATIVE=''${REPO_GIT#''$REPO_ROOT/}
          ${git}/bin/git config --local core.hooksPath "''$REPO_GIT_RELATIVE/hooks"
        '';
    };
}
