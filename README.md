# pipe-while-read

A robust Zsh function that supercharges your shell pipelines. It seamlessly maps stdin to commands, acting as a friendlier, smarter `xargs` or `parallel`.

## Why use this over `xargs`?

* **Smart Placeholders**: No need for `-I {}`. If you write `mv {} destination/`, it just works.
* **Pure Zsh**: Functions are easier to debug and alias than binary wrappers.
* **Interactive Safety**: The `-p` flag lets you approve destructive commands line-by-line.
* **Zero Dependencies**: Just source and go.

## Installation

### Oh-My-Zsh

```zsh
cd $ZSH_CUSTOM/plugins
git clone [https://github.com/pressdarling/pipe-while-read](https://github.com/pressdarling/pipe-while-read)
# Add 'pipe-while-read' to your plugins list in .zshrc
```

### Manual

Source `pipe-while-read.zsh` in your `.zshrc`.

## Usage

```zsh
... | pipe-while-read [options] -- <command>
```

### Examples

1. **The Classic (Append Mode)** Like `xargs`, arguments are appended to the end by default.

```zsh
# Delete all text files
find . -name "*.txt" | pipe-while-read rm
```

2. **Smart Placeholders** If you include `{}` anywhere in your command, the input line is injected there.

```zsh
# Rename files (impossible with standard xargs append)
ls *.png | pipe-while-read mv {} {.}.backup
```

3. **Interactive Safety** Not sure about that regex? Ask for confirmation before running.

```zsh
# Prompts [y/N] for every branch
git branch | grep 'feature/' | pipe-while-read -p git branch -D
```

4. **Null Safety** Handling filenames with spaces or newlines? Use `-0`.

```zsh
find . -type f -print0 | pipe-while-read -0 -n echo "Safe file:"
```

5. **Parallelism** Want speed? Use `-j` to offload execution to Zsh's built-in `zargs` for threaded performance.

```zsh
# Compress 4 files at a time
find . -name "*.log" | pipe-while-read -j 4 gzip
```

## Options

**Flag**

**Description**

`-n`, `--dry-run`

Print commands without running them.

`-p`, `--confirm`

Ask for confirmation before executing each command.

`-j`, `--jobs N`

Run N jobs in parallel (uses `zargs` backend).

`-0`, `--null`

Expect null-terminated input (use with `find -print0`).

`-v`, `--verbose`

Print commands as they run.

## License

[Unlicense (Public Domain)](./UNLICENSE).
