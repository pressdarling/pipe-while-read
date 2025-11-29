# Repository Guidelines

## Project Structure & Key Files
- `pipe-while-read.zsh`: Original zsh function; reads stdin line-by-line and appends each line to a command.
- `src/main.rs`: Rust CLI port with the same behavior and `-n/--dry-run` support via clap.
- `tests/cli.rs`: Integration tests covering dry-run output and execution.
- `Cargo.toml`: Rust dependencies (`clap`, `anyhow`) plus dev tools (`assert_cmd`, `predicates`).
- `README.md`: Usage for both the zsh plugin and the Rust binary.
- `CLAUDE.md`: Quick manual test recipes; keep updated when behavior changes.
- `UNLICENSE`: Public domain dedication.

## Build, Test, and Development
- Zsh plugin: no build step; reload with `source pipe-while-read.zsh` after edits.
- Rust CLI: `cargo build` (or `cargo run -- <args>`) to compile and try changes; run `cargo fmt` before committing.
- Tests: `cargo test` exercises dry-run and execution paths. Manual checks remain helpful:
  - Dry run: `echo -e "foo\nbar\nbaz" | pipe-while-read -n echo "Got:"`
  - Execute: `echo -e "one\ntwo" | pipe-while-read echo "Line:"`
- Prefer small fixture input when iterating; avoid side-effecting commands unless using `-n`.

## Coding Style & Naming
- Shell: keep function name `pipe-while-read`; flags remain `-n/--dry-run`, `-h/--help`. Maintain tab indentation and quote expansions that may contain spaces.
- Rust: edition 2024; `anyhow::Result` for `main`; `clap` for argument parsing. Keep help/dry-run output aligned with the zsh version. Propagate the invoked command’s exit code when possible.
- Formatting: run `cargo fmt`; keep lines ~100 chars. When adding options, update both implementations and docs/examples.

## Testing Guidelines
- Automated: `cargo test` (integration tests in `tests/cli.rs`). Add cases when output format or flags change.
- Manual: ensure the sample pipelines in `CLAUDE.md` stay accurate; include a dry-run example for any new behavior.

## Commit & Pull Request Expectations
- Commits: short, imperative subjects; avoid mixing unrelated changes.
- PRs: explain what and why; include sample command outputs (dry-run + real) for behavior changes. Note doc updates and any backward-compat considerations.
- Keep diffs minimal; the repo is intentionally small—favor clarity over abstraction.
- When working from a worktree, run git commands with `git -C /Users/brady/tmp/trees/pipe-while-read/rust-cli-mvp` to avoid affecting other checkouts.

## Compatibility & Distribution Notes
- Target zsh users; avoid bashisms unless guarded. Test on macOS default zsh; avoid external dependencies.
- Rust binary should not assume GNU-only tools; tests rely on `echo`/`printf` which are widely available.
- For oh-my-zsh distribution, keep `pipe-while-read.zsh` standalone and not coupled to repo layout.
