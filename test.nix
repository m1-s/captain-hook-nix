{ testers, git, builder, writeShellScript, lib }:
let
  tests = [
    {
      hooks = [{
        type = "commit";
        cmd = "exit 1";
      }];
    }
    {
      hooks = [
        {
          type = "commit";
          cmd = "exit 1";
        }
        {
          type = "post-checkout";
          cmd = "exit 2";
        }
      ];
    }
  ];

  assertSingleHook = hook:
    let
      type = lib.getAttrFromPath [ "type" ] hook;
      cmd = lib.getAttrFromPath [ "cmd" ] hook;
    in
    ''
      if [ `cat .git/hooks/${type}` != '${cmd}' ]; then
        echo 'Expected `cat .git/hooks/${type}` but found $CONTENT'
      fi
    '';

  singleTest = test:
    let
      hooksFromTest = lib.getAttrFromPath [ "hooks" ] test;
      setup = builder { hooks = hooksFromTest; inherit git writeShellScript; };
      asserts =
        let script = lib.concatMapStrings (hook: assertSingleHook hook) hooksFromTest;
        in writeShellScript "nix-commit-hooks-asserts" ("set -eoux\n" + script);
    in
    ''
      print("setting up...")
      vm.succeed("${setup}")
      print("asserting...")
      vm.succeed("${asserts}")
      print("cleaning up...")
      vm.succeed("rm .git/hooks/*")
    '';
  execAllTests = lib.concatMapStrings singleTest tests;
in
testers.nixosTest {
  name = "file-test";
  nodes.vm = {
    environment.systemPackages = [ git ];
  };

  testScript = ''
    vm.start()
    vm.succeed("git init")
  '' + execAllTests;
}
