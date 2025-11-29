# Repository Guidelines

## Project Structure & Key Files
- `pipe-while-read.zsh`: Single-function plugin; parses flags, reads stdin line-by-line, executes a command per line.
- `README.md`: Install and usage quickstart for oh-my-zsh or manual sourcing.
- `CLAUDE.md`: Short project brief and manual test examples; keep this file in sync when behavior changes.
- `UNLICENSE`: Public domain dedication; no contributor license agreement required.

## Build, Test, and Development
- No build step; plugin is sourced directly. Reload with `source pipe-while-read.zsh` after edits.
- Manual sanity checks (from `CLAUDE.md`):
  - Dry run: `echo -e "foo\nbar\nbaz" | pipe-while-read -n echo "Got:"`
  - Execution: `echo -e "one\ntwo" | pipe-while-read echo "Line:"`
- For local iterations, prefer piping small fixtures; avoid commands that mutate state when not using `-n`.

## Coding Style & Naming
- Shell: zsh; keep function name `pipe-while-read` and flag forms `-n/--dry-run`, `-h/--help`.
- Indentation: match existing style (tabs in current file); keep lines under ~100 chars and quote variables that can contain spaces.
- Error handling: print concise usage/help to stdout; return success (0) on help, propagate failures from invoked commands where practical.
- New options should preserve backward compatibility and update usage text plus examples.

## Testing Guidelines
- There is no automated test suite; rely on manual piping examples above.
- When adding behavior, include at least one new manual check command in PR description and, if relevant, a dry-run variant to prevent accidental writes.

## Commit & Pull Request Expectations
- Commits: short, imperative subjects (e.g., "Add dry-run flag note", "Improve usage text"). Avoid bundling unrelated changes.
- PRs: include what changed, why, and before/after behavior. Attach sample command outputs for new behaviors. If flags or usage change, note doc updates and backward-compatibility considerations.
- Keep diffs minimal; this repo is intentionally small—prefer clarity over abstraction.

## Compatibility & Distribution Notes
- Target zsh users; avoid bashisms unless guarded. Test on macOS default zsh; avoid external dependencies.
- For oh-my-zsh distribution, ensure the file remains standalone and does not rely on repo layout beyond `pipe-while-read.zsh`.
