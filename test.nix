{ testers, git, builder, writeShellScript, lib, fenceStart, fenceEnd }:
let
  tests = {
    singleHookTest.hooks = [{
      type = "pre-commit";
      cmd = "foo";
    }];
    multipleHooksTest.hooks = [
      {
        type = "post-merge";
        cmd = "foo";
      }
      {
        type = "post-checkout";
        cmd = "foo";
      }
    ];
    singleHookAppendTest.hooks = [{
      type = "pre-checkout";
      cmd = "foo";
    }];
    singleHookModifyTest.hooks = [{
      type = "pre-merge";
      cmd = "foo";
    }];
  };
in
testers.nixosTest {
  name = "file-test";
  nodes.vm = {
    environment.systemPackages = [ git ];
  };

  testScript = ''
    class TestFolder(object):
      def __enter__(self):
        vm.succeed("git init")

      def __exit__(self, *args):
        vm.succeed("rm -r .git")

    def surroundWithFences(s: str):
      return f"${fenceStart}\n{s}\n${fenceEnd}\n"

    with TestFolder():
      vm.succeed("${builder { inherit (tests.singleHookTest) hooks; inherit git writeShellScript; }}")
      actual = vm.succeed("cat .git/hooks/${(builtins.head tests.singleHookTest.hooks).type}")
      expected = surroundWithFences("${(builtins.head tests.singleHookTest.hooks).cmd}")
      assert actual == expected, f"Expected '{expected}' but was '{actual}'"

    with TestFolder():
      vm.succeed("${builder { inherit (tests.multipleHooksTest) hooks; inherit git writeShellScript; }}")
      actual = vm.succeed("cat .git/hooks/${(builtins.head tests.multipleHooksTest.hooks).type}")
      expected = surroundWithFences("${(builtins.head tests.multipleHooksTest.hooks).cmd}")
      assert actual == expected, f"Expected '{expected}' but was '{actual}'"

    with TestFolder():
      previousContent = "bar"
      vm.succeed(f"echo {previousContent} > .git/hooks/${(builtins.head tests.singleHookAppendTest.hooks).type}")
      vm.succeed("${builder { inherit (tests.singleHookAppendTest) hooks; inherit git writeShellScript; }}")
      actual = vm.succeed("cat .git/hooks/${(builtins.head tests.singleHookAppendTest.hooks).type}")
      expected = (f"{previousContent}\n"
        + surroundWithFences("${(builtins.head tests.singleHookAppendTest.hooks).cmd}"))
      assert actual == expected, f"Expected '{expected}' but was '{actual}'"

    with TestFolder():
      vm.succeed("${builder { inherit (tests.singleHookModifyTest) hooks; inherit git writeShellScript; }}")
      user_appended_content = "bar"
      vm.succeed(f"echo {user_appended_content} >> .git/hooks/${(builtins.head tests.singleHookModifyTest.hooks).type}")
      vm.succeed("${builder { inherit (tests.singleHookModifyTest) hooks; inherit git writeShellScript; }}")
      actual = vm.succeed("cat .git/hooks/${(builtins.head tests.singleHookModifyTest.hooks).type}")
      expected = (f"{user_appended_content}\n"
        + surroundWithFences("${(builtins.head tests.singleHookModifyTest.hooks).cmd}"))
      assert actual == expected, f"Expected '{expected}' but was '{actual}'"
  '';
}
