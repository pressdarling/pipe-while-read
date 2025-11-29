# GEMINI.md

This file provides guidance to Gemini when working with code in this repository.

## Overview

This is a zsh plugin providing a single function `pipe-while-read` that reads stdin line-by-line and executes a command with each line as an argument.

The plugin is contained in a single file, `pipe-while-read.zsh`.

## Functionality

The `pipe-while-read` function:
- Parses `-n`/`--dry-run` and `-h`/`--help` flags.
- Reads stdin using `while IFS= read -r line`.
- Executes the provided command with each line from stdin appended as the final argument.

## Testing

To test the plugin, source it and run the following commands:

```zsh
source pipe-while-read.zsh

# Test with dry-run to see the commands that would be executed
echo -e "foo\nbar\nbaz" | pipe-while-read -n echo "Got:"

# Test actual execution
echo -e "one\ntwo" | pipe-while-read echo "Line:"
```

## Architecture

This is a simple, single-file oh-my-zsh compatible plugin. The main logic is within the `pipe-while-read` function in `pipe-while-read.zsh`.
