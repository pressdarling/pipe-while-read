#!/usr/bin/env zsh
pipe-while-read () {
	local dry_run=false 
	local help=false 
	while [[ $# -gt 0 ]]
	do
		case $1 in
			(-n | --dry-run) dry_run=true 
				shift ;;
			(-h | --help) help=true 
				shift ;;
			(*) break ;;
		esac
	done
	if [[ $help == true ]] || [[ $# -lt 1 ]]
	then
		printf 'Usage: command | pipe-while-read [-n|--dry-run] [-h|--help] <command> [args...]\n'
		printf '  Reads stdin line by line and executes <command> with each line as argument\n'
		printf '  -n, --dry-run  Show commands without executing\n'
		printf '  -h, --help     Show this help\n'
		printf 'Example: cat file.txt | pipe-while-read -n echo "Processing:"\n'
		return 0
	fi
	local cmd=$1 
	shift
	while IFS= read -r line
	do
		if [[ $dry_run == true ]]
		then
			echo "[DRY RUN] ${(q)cmd} ${(@q)@} ${(q)line}"
		else
			"$cmd" "$@" "$line"
		fi
	done
}
