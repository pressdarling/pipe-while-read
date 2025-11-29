use predicates::prelude::*;

#[test]
fn dry_run_echoes_commands() {
    let mut cmd = assert_cmd::cargo::cargo_bin_cmd!("pipe-while-read");

    cmd.args(["-n", "echo", "Got:"])
        .write_stdin("foo\nbar\n")
        .assert()
        .success()
        .stdout(
            predicate::str::contains("[DRY RUN] echo Got: foo")
                .and(predicate::str::contains("[DRY RUN] echo Got: bar")),
        );
}

#[test]
fn executes_command_per_line() {
    let mut cmd = assert_cmd::cargo::cargo_bin_cmd!("pipe-while-read");

    cmd.args(["printf", "X:%s\\n"])
        .write_stdin("one\ntwo\n")
        .assert()
        .success()
        .stdout("X:one\nX:two\n");
}
