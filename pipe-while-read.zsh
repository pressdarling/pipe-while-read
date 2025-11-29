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
		cat <<-EOF
		Usage: <command> | pipe-while-read [-n|--dry-run] [-h|--help] <command> [args...]

		Reads stdin line by line and executes <command> for each line, appending the line as the final argument.

		Options:
		  -n, --dry-run  Show the commands that would be executed without running them.
		  -h, --help     Show this help message.

		Examples:
		  # Basic execution: list files and print their names
		  ls | pipe-while-read echo "Found file:"

		  # Dry run: preview commands to move files without actually moving them
		  echo -e "file1.txt\nfile2.txt" | pipe-while-read -n mv -t /path/to/dest

		  # Chaining commands: find all .log files and gzip them
		  find . -name "*.log" | pipe-while-read gzip
		EOF
		return 0
	fi
	local cmd=$1 
	shift
	while IFS= read -r line
	do
		if [[ $dry_run == true ]]
		then
			echo "[DRY RUN] $cmd $@ $line"
		else
			"$cmd" "$@" "$line"
		fi
	done
}
