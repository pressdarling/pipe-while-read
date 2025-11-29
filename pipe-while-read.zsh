#!/usr/bin/env zsh
pipe-while-read () {
	local dry_run=false
	local help=false
	local delimiter_is_set=false
	local delimiter
	while [[ $# -gt 0 ]]
	do
		case $1 in
			(-n | --dry-run) dry_run=true
				shift ;;
			(-h | --help) help=true
				shift ;;
			(-d | --delimiter)
				if [[ -z "$2" ]]; then
					printf 'Error: -d|--delimiter option requires an argument.\n'
					printf 'Usage: command | pipe-while-read [-n|--dry-run] [-h|--help] [-d|--delimiter <delim>] <command> [args...]\n'
					return 1
				fi
				delimiter_is_set=true
				delimiter="$2"
				shift 2
				;;
			(*) break ;;
		esac
	done
	if [[ $help == true ]] || [[ $# -lt 1 ]]
	then
		printf 'Usage: command | pipe-while-read [-n|--dry-run] [-h|--help] [-d|--delimiter <delim>] <command> [args...]\n'
		printf '  Reads stdin line by line and executes <command> with each line as an argument.\n'
		printf '  If a delimiter is provided, each line is split by the delimiter and the command\n'
		printf '  is executed for each resulting token.\n'
		printf '  -n, --dry-run      Show commands without executing\n'
		printf '  -h, --help         Show this help\n'
		printf '  -d, --delimiter    Split lines by <delim> instead of passing the whole line.\n'
		printf 'Example: cat file.txt | pipe-while-read -n echo "Processing:"\n'
		printf 'Example: echo "a,b,c" | pipe-while-read -d "," echo "Got part:"\n'
		return 0
	fi
	local cmd=$1
	shift
	while IFS= read -r line
	do
		if [[ $delimiter_is_set == true ]]; then
			local -a parts=("${(@s:${delimiter}:)line}")
			for part in "${parts[@]}"; do
				if [[ $dry_run == true ]]; then
					echo "[DRY RUN] $cmd $@ $part"
				else
					"$cmd" "$@" "$part"
				fi
			done
		else
			if [[ $dry_run == true ]]
			then
				echo "[DRY RUN] $cmd $@ $line"
			else
				"$cmd" "$@" "$line"
			fi
		fi
	done
}
