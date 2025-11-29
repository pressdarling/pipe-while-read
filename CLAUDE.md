# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a zsh plugin providing a single function `pipe-while-read` that reads stdin line-by-line and executes a command with each line as an argument.

## Testing

Source the plugin and test manually:

```zsh
source pipe-while-read.zsh

# Test with dry-run
echo -e "foo\nbar\nbaz" | pipe-while-read -n echo "Got:"

# Test execution
echo -e "one\ntwo" | pipe-while-read echo "Line:"
```

## Architecture

Single-file plugin (`pipe-while-read.zsh`) containing one function that:
- Parses `-n`/`--dry-run` and `-h`/`--help` flags
- Reads stdin via `while IFS= read -r line`
- Executes the provided command with each line appended as the final argument

Compatible with oh-my-zsh plugin system (place in `$ZSH_CUSTOM/plugins/`).
