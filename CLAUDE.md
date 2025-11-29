# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a powerful zsh plugin providing the `pipe-while-read` function that processes stdin line-by-line and executes commands with rich features exceeding xargs, GNU parallel, and rush.

## Key Features

- **Parallel execution** with configurable job count (`-j`)
- **Rich placeholders**: `{}`, `{.}`, `{/}`, `{//}`, `{/.}`, `{#}`, `{%}`, `{1}..{n}`, `{-1}`, `{ext}`, `{len}`
- **Progress indicator** with ETA (`-P`)
- **Timeout and retry** support (`-t`, `-r`)
- **Keep output order** when parallel (`-k`)
- **Null-delimited input** (`-0`)
- **Field extraction** with custom delimiters (`-d`)
- **Output tagging** (`--tag`)
- **Fail-fast mode** (`--fail-fast`)
- **Pass line to stdin** (`--stdin`)

## Testing

Source the plugin and test manually:

```zsh
source pipe-while-read.zsh

# Basic usage (line appended as argument)
echo -e "foo\nbar\nbaz" | pipe-while-read echo "Got:"

# Dry-run mode
echo -e "one\ntwo" | pipe-while-read -n echo "Line:"

# Parallel execution with progress
seq 1 10 | pipe-while-read -j4 -P sleep 0.5 && echo

# Placeholder substitution
echo -e "/path/to/file.txt\n/another/doc.pdf" | pipe-while-read -n echo "Base: {/} Ext: {ext}"

# Field extraction
printf "alice\t100\nbob\t200" | pipe-while-read -d$'\t' echo "Name: {1}, Score: {2}"

# File renaming pattern
echo "photo.jpeg" | pipe-while-read -n mv {} {/.}.jpg

# With timeout and retries
echo -e "example.com\nbadhost.invalid" | pipe-while-read -t2 -r1 -v ping -c1 {}

# Null-delimited input (safe for special filenames)
printf "file one\0file two\0" | pipe-while-read -0 -n echo "Processing:"

# Keep output order when parallel
seq 5 | pipe-while-read -j3 -k sh -c 'sleep $((RANDOM%2)); echo "Job {#}: {}"'

# Tag output with source
echo -e "one\ntwo" | pipe-while-read --tag echo "result"
```

## Architecture

Single-file plugin (`pipe-while-read.zsh`) containing:
- Main `pipe-while-read()` function with comprehensive option parsing
- `_pwr_expand()` helper for placeholder substitution
- `_pwr_run_cmd()` helper for timeout/retry execution
- `_pwr_show_progress()` helper for progress bar display
- `pwr` alias for quick access

Compatible with oh-my-zsh plugin system (place in `$ZSH_CUSTOM/plugins/`).

## Comparison with Similar Tools

| Feature | pipe-while-read | xargs | GNU parallel | rush |
|---------|----------------|-------|--------------|------|
| Parallel jobs | `-j N` | `-P N` | `-j N` | `-j N` |
| Progress bar | `-P` | No | `--bar` | `--eta` |
| Placeholders | Rich set | `-I {}` | Rich set | Rich set |
| Timeout | `-t SEC` | No | `--timeout` | `-t` |
| Retries | `-r N` | No | `--retries` | `-r` |
| Keep order | `-k` | No | `-k` | `-k` |
| Field extract | `{1}`, `{2}` | No | `{1}`, `{2}` | `{1}`, `{2}` |
| Tag output | `--tag` | No | `--tag` | No |
| Fail-fast | `--fail-fast` | No | `--halt` | `-e` |
| Null input | `-0` | `-0` | `-0` | No |
| Pass to stdin | `--stdin` | No | No | No |
| Pure zsh | Yes | No | No | No |
