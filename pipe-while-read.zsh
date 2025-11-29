#!/usr/bin/env zsh

# Shows usage instructions.
_pipe-while-read_usage() {
	printf 'Usage: command | pipe-while-read [-n|--dry-run] [-h|--help] <command> [args...]\n'
	printf '  Reads stdin line by line and executes <command> with each line as argument\n'
	printf '  -n, --dry-run  Show commands without executing\n'
	printf '  -h, --help     Show this help\n'
	printf 'Example: cat file.txt | pipe-while-read -n echo "Processing:"\n'
}

# Reads from stdin line by line and executes a command for each line.
pipe-while-read() {
	local dry_run=false
	local help=false

	# Parse options
	while [[ $# -gt 0 ]]; do
		case $1 in
			(-n | --dry-run)
				dry_run=true
				shift
				;;
			(-h | --help)
				help=true
				shift
				;;
			(*) break ;;
		esac
	done

	# Show help and exit if requested or if no command is provided.
	if [[ "$help" == "true" ]] || [[ $# -lt 1 ]]; then
		_pipe-while-read_usage
		return 0
	fi

	local cmd="$1"
	shift

	# Process stdin line by line.
	while IFS= read -r line; do
		if [[ "$dry_run" == "true" ]]; then
			echo "[DRY RUN] $cmd" "$@" "$line"
		else
			"$cmd" "$@" "$line"
		fi
	done
}
