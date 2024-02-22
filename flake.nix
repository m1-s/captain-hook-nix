{
  description = "Define Git hooks in Nix";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";

  outputs = { self, nixpkgs, flake-utils, pre-commit-hooks }:
    let
      fenceStart = "# captain-hook-nix start";
      fenceEnd = "# captain-hook-nix end";
    in
    flake-utils.lib.eachDefaultSystem
      (system:
        let pkgs = import nixpkgs { inherit system; };
        in {
          devShells.default = nixpkgs.legacyPackages.${system}.mkShell {
            inherit (self.checks.${system}.pre-commit-check) shellHook;
          };

          checks = {
            fileTests = pkgs.callPackage ./test.nix { builder = self.lib.builder; inherit fenceStart fenceEnd; };
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
          # taken from https://git-scm.com/docs/githooks
          possibleHooks = [
            "applypatch-msg"
            "commit-msg"
            "fsmonitor-watchman"
            "p4-changelist"
            "p4-post-changelist"
            "p4-pre-submit"
            "p4-prepare-changelist"
            "post-applypatch"
            "post-checkout"
            "post-commit"
            "post-index-change"
            "post-merge"
            "post-rewrite"
            "pre-applypatch"
            "pre-auto-gc"
            "pre-commit"
            "pre-merge-commit"
            "pre-push"
            "pre-rebase"
            "prepare-commit-msg"
            "reference-transaction"
            "sendemail-validate"
          ];
          singleHook = attrs:
            let
              type = assert (nixpkgs.lib.assertOneOf "hook" attrs.type possibleHooks); attrs.type;
            in
            ''
              HOOK_PATH=".git/hooks/${attrs.type}"
              CONTENT=`cat $HOOK_PATH` || true

              perl -0777 -pi -e 's/^# captain-hook-nix start$([\S\s])*^# captain-hook-nix end[\n]?//gm' "$HOOK_PATH"
              echo -e '${fenceStart}\n${attrs.cmd}\n${fenceEnd}' >> "$HOOK_PATH";
            '';
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
