#!/usr/bin/env zsh
# pipe-while-read - A powerful stdin-to-command processor
# Exceeds xargs, GNU parallel, rush in features while remaining simple
#
# Features:
#   - Parallel execution with job control
#   - Rich placeholder substitution ({}, {.}, {/}, {//}, {/.}, {#}, {n})
#   - Progress indicator with ETA
#   - Timeout and retry support
#   - Keep output order option
#   - Field extraction with custom delimiters
#   - Null-delimited input support
#   - Verbose, quiet, and dry-run modes
#   - Pass line to stdin instead of argument

pipe-while-read() {
    # Default options
    local dry_run=false
    local verbose=false
    local quiet=false
    local help=false
    local jobs=1
    local timeout=0
    local retries=0
    local retry_delay=1
    local keep_order=false
    local progress=false
    local null_delim=false
    local delimiter=$'\t'
    local placeholder='{}'
    local tag_output=false
    local fail_fast=false
    local pass_stdin=false
    local delay=0
    local trim_input=false

    # Colors for output (respects NO_COLOR)
    local c_reset='' c_dim='' c_green='' c_yellow='' c_red='' c_cyan=''
    if [[ -t 2 ]] && [[ -z "${NO_COLOR:-}" ]]; then
        c_reset=$'\e[0m'
        c_dim=$'\e[2m'
        c_green=$'\e[32m'
        c_yellow=$'\e[33m'
        c_red=$'\e[31m'
        c_cyan=$'\e[36m'
    fi

    # Parse options
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--dry-run)
                dry_run=true; shift ;;
            -v|--verbose)
                verbose=true; shift ;;
            -q|--quiet)
                quiet=true; shift ;;
            -h|--help)
                help=true; shift ;;
            -j|--jobs)
                jobs=${2:-1}; shift 2 ;;
            -j*)
                jobs=${1#-j}; shift ;;
            --jobs=*)
                jobs=${1#--jobs=}; shift ;;
            -t|--timeout)
                timeout=${2:-0}; shift 2 ;;
            -t*)
                timeout=${1#-t}; shift ;;
            --timeout=*)
                timeout=${1#--timeout=}; shift ;;
            -r|--retries)
                retries=${2:-0}; shift 2 ;;
            -r*)
                retries=${1#-r}; shift ;;
            --retries=*)
                retries=${1#--retries=}; shift ;;
            --retry-delay)
                retry_delay=${2:-1}; shift 2 ;;
            --retry-delay=*)
                retry_delay=${1#--retry-delay=}; shift ;;
            -k|--keep-order)
                keep_order=true; shift ;;
            -P|--progress)
                progress=true; shift ;;
            -0|--null)
                null_delim=true; shift ;;
            -d|--delimiter)
                delimiter=${2:-$'\t'}; shift 2 ;;
            --delimiter=*)
                delimiter=${1#--delimiter=}; shift ;;
            -I|--replace)
                placeholder=${2:-'{}'}; shift 2 ;;
            --replace=*)
                placeholder=${1#--replace=}; shift ;;
            --tag)
                tag_output=true; shift ;;
            --fail-fast)
                fail_fast=true; shift ;;
            --stdin)
                pass_stdin=true; shift ;;
            --delay)
                delay=${2:-0}; shift 2 ;;
            --delay=*)
                delay=${1#--delay=}; shift ;;
            --trim)
                trim_input=true; shift ;;
            --)
                shift; break ;;
            -*)
                printf "${c_red}Error: Unknown option: %s${c_reset}\n" "$1" >&2
                return 1 ;;
            *)
                break ;;
        esac
    done

    # Show help
    if [[ $help == true ]] || [[ $# -lt 1 ]]; then
        cat >&2 <<'EOF'
pipe-while-read - Process stdin line-by-line with powerful features

USAGE:
    command | pipe-while-read [OPTIONS] <command> [args...]

OPTIONS:
    -n, --dry-run           Show commands without executing
    -v, --verbose           Show detailed execution info
    -q, --quiet             Suppress command output
    -h, --help              Show this help

    -j, --jobs <N>          Run N jobs in parallel (default: 1)
    -k, --keep-order        Preserve output order when parallel
    -P, --progress          Show progress indicator with ETA

    -t, --timeout <SEC>     Kill jobs after SEC seconds (0=none)
    -r, --retries <N>       Retry failed commands N times
    --retry-delay <SEC>     Wait SEC seconds between retries (default: 1)
    --fail-fast             Stop all jobs on first failure

    -0, --null              Use NUL as input delimiter (like xargs -0)
    -d, --delimiter <D>     Field delimiter for {1}, {2}, etc (default: tab)
    --trim                  Trim leading/trailing whitespace from input

    -I, --replace <STR>     Placeholder string (default: {})
    --tag                   Prefix each output line with input
    --stdin                 Pass line to command's stdin, not as argument
    --delay <SEC>           Wait SEC seconds before each job

PLACEHOLDERS:
    {}                      Full input line
    {.}                     Input with last extension removed
    {/}                     Basename (filename only)
    {//}                    Directory path
    {/.}                    Basename without extension
    {#}                     Job sequence number (1, 2, 3, ...)
    {%}                     Job slot number (1 to N jobs)
    {1}, {2}, ...           Nth field (using delimiter)
    {-1}, {-2}, ...         Nth field from end
    {ext}                   File extension (without dot)
    {len}                   Length of input line

EXAMPLES:
    # Basic usage
    ls *.txt | pipe-while-read echo "File:"

    # Dry-run with placeholder
    find . -name "*.log" | pipe-while-read -n rm {}

    # Parallel with progress
    cat urls.txt | pipe-while-read -j4 -P curl -O {}

    # Extract fields
    cat data.tsv | pipe-while-read -d$'\t' echo "Name: {1}, Value: {2}"

    # Rename files (basename without extension)
    ls *.jpeg | pipe-while-read mv {} {/.}.jpg

    # With timeout and retries
    cat hosts.txt | pipe-while-read -t5 -r3 ping -c1 {}

    # Null-delimited input (safe for filenames with spaces)
    find . -name "*.tmp" -print0 | pipe-while-read -0 rm {}

    # Keep output in order when parallel
    seq 10 | pipe-while-read -j4 -k sh -c 'sleep $((RANDOM%3)); echo {}'

    # Tag output with source
    cat servers.txt | pipe-while-read --tag ssh {} uptime
EOF
        return 0
    fi

    # Build command template
    local cmd=("$@")
    local has_placeholder=false

    # Check if any argument contains a placeholder
    for arg in "${cmd[@]}"; do
        if [[ "$arg" == *'{}'* ]] || [[ "$arg" == *'{.'* ]] || \
           [[ "$arg" == *'{/'* ]] || [[ "$arg" == *'{#}'* ]] || \
           [[ "$arg" == *'{%}'* ]] || [[ "$arg" == *'{-'* ]] || \
           [[ "$arg" =~ '\{[0-9]+\}' ]] || [[ "$arg" == *'{ext}'* ]] || \
           [[ "$arg" == *'{len}'* ]]; then
            has_placeholder=true
            break
        fi
    done

    # Function to expand placeholders in a string
    _pwr_expand() {
        local template="$1"
        local line="$2"
        local job_num="$3"
        local job_slot="$4"
        local result="$template"

        # Trim if requested
        local processed_line="$line"
        if [[ $trim_input == true ]]; then
            processed_line="${line#"${line%%[![:space:]]*}"}"
            processed_line="${processed_line%"${processed_line##*[![:space:]]}"}"
        fi

        # Split into fields
        local -a fields
        if [[ -n "$delimiter" ]]; then
            IFS="$delimiter" read -rA fields <<< "$processed_line"
        else
            fields=("$processed_line")
        fi

        # Path components
        local basename="${processed_line##*/}"
        local dirname="${processed_line%/*}"
        [[ "$dirname" == "$processed_line" ]] && dirname="."
        local noext="${processed_line%.*}"
        local basename_noext="${basename%.*}"
        local ext="${basename##*.}"
        [[ "$ext" == "$basename" ]] && ext=""

        # Expand placeholders
        result="${result//\{#\}/$job_num}"
        result="${result//\{%\}/$job_slot}"
        result="${result//\{len\}/${#processed_line}}"
        result="${result//\{ext\}/$ext}"
        result="${result//\{\/.\}/$basename_noext}"
        result="${result//\{\/\/\}/$dirname}"
        result="${result//\{\/\}/$basename}"
        result="${result//\{.\}/$noext}"

        # Field extraction {1}, {2}, {-1}, {-2}, etc.
        local i
        for i in {1..20}; do
            if [[ "$result" == *"{$i}"* ]]; then
                local field_val="${fields[$i]:-}"
                result="${result//\{$i\}/$field_val}"
            fi
            if [[ "$result" == *"{-$i}"* ]]; then
                local neg_idx=$((${#fields[@]} - i + 1))
                local field_val="${fields[$neg_idx]:-}"
                result="${result//\{-$i\}/$field_val}"
            fi
        done

        # Finally expand {} (must be last to avoid partial matches)
        result="${result//\{\}/$processed_line}"

        printf '%s' "$result"
    }

    # Function to run a single command with timeout and retries
    _pwr_run_cmd() {
        local -a expanded_cmd=()
        local line="$1"
        local job_num="$2"
        local job_slot="$3"
        shift 3
        local -a cmd_template=("$@")

        # Expand placeholders in each argument
        for arg in "${cmd_template[@]}"; do
            expanded_cmd+=("$(_pwr_expand "$arg" "$line" "$job_num" "$job_slot")")
        done

        # If no placeholder was used, append line as final argument
        if [[ $has_placeholder == false ]] && [[ $pass_stdin == false ]]; then
            local processed_line="$line"
            if [[ $trim_input == true ]]; then
                processed_line="${line#"${line%%[![:space:]]*}"}"
                processed_line="${processed_line%"${processed_line##*[![:space:]]}"}"
            fi
            expanded_cmd+=("$processed_line")
        fi

        local attempt=0
        local max_attempts=$((retries + 1))
        local exit_code=1

        while (( attempt < max_attempts )); do
            (( attempt++ ))

            if [[ $verbose == true ]] && (( attempt > 1 )); then
                printf "${c_yellow}[RETRY %d/%d]${c_reset} %s\n" "$attempt" "$max_attempts" "${expanded_cmd[*]}" >&2
            fi

            if [[ $pass_stdin == true ]]; then
                # Pass line to stdin
                if (( timeout > 0 )); then
                    printf '%s\n' "$line" | timeout "$timeout" "${expanded_cmd[@]}"
                else
                    printf '%s\n' "$line" | "${expanded_cmd[@]}"
                fi
            else
                if (( timeout > 0 )); then
                    timeout "$timeout" "${expanded_cmd[@]}"
                else
                    "${expanded_cmd[@]}"
                fi
            fi
            exit_code=$?

            if (( exit_code == 0 )); then
                break
            elif (( exit_code == 124 )); then
                # Timeout occurred
                [[ $verbose == true ]] && printf "${c_red}[TIMEOUT]${c_reset} %s\n" "${expanded_cmd[*]}" >&2
            fi

            if (( attempt < max_attempts )); then
                sleep "$retry_delay"
            fi
        done

        return $exit_code
    }

    # Read all input into array for progress tracking
    local -a lines=()
    local read_delim=""
    [[ $null_delim == true ]] && read_delim="-d ''"

    if [[ $null_delim == true ]]; then
        while IFS= read -r -d '' line; do
            lines+=("$line")
        done
    else
        while IFS= read -r line; do
            lines+=("$line")
        done
    fi

    local total=${#lines[@]}

    if (( total == 0 )); then
        [[ $verbose == true ]] && printf "${c_dim}No input lines to process${c_reset}\n" >&2
        return 0
    fi

    [[ $verbose == true ]] && printf "${c_dim}Processing %d lines with %d job(s)${c_reset}\n" "$total" "$jobs" >&2

    # Progress tracking
    local processed=0
    local failed=0
    local start_time=$SECONDS

    _pwr_show_progress() {
        if [[ $progress == true ]] && [[ -t 2 ]]; then
            local elapsed=$((SECONDS - start_time))
            local rate=0
            local eta="--:--"
            if (( processed > 0 )) && (( elapsed > 0 )); then
                rate=$((processed * 100 / elapsed))
                local remaining=$(( (total - processed) * elapsed / processed ))
                eta=$(printf '%02d:%02d' $((remaining / 60)) $((remaining % 60)))
            fi
            local pct=$((processed * 100 / total))
            local bar_width=20
            local filled=$((pct * bar_width / 100))
            local bar=""
            for ((i=0; i<bar_width; i++)); do
                if ((i < filled)); then
                    bar+="█"
                else
                    bar+="░"
                fi
            done
            printf "\r${c_cyan}[%s]${c_reset} %3d%% (%d/%d) ETA: %s  " \
                "$bar" "$pct" "$processed" "$total" "$eta" >&2
        fi
    }

    # Execute commands
    if (( jobs == 1 )); then
        # Sequential execution
        local job_num=0
        for line in "${lines[@]}"; do
            (( job_num++ ))

            (( delay > 0 )) && (( job_num > 1 )) && sleep "$delay"

            if [[ $dry_run == true ]]; then
                local -a preview_cmd=()
                for arg in "${cmd[@]}"; do
                    preview_cmd+=("$(_pwr_expand "$arg" "$line" "$job_num" "1")")
                done
                if [[ $has_placeholder == false ]] && [[ $pass_stdin == false ]]; then
                    local processed_line="$line"
                    if [[ $trim_input == true ]]; then
                        processed_line="${line#"${line%%[![:space:]]*}"}"
                        processed_line="${processed_line%"${processed_line##*[![:space:]]}"}"
                    fi
                    preview_cmd+=("$processed_line")
                fi
                printf "${c_yellow}[DRY RUN]${c_reset} %s\n" "${preview_cmd[*]}"
            else
                [[ $verbose == true ]] && printf "${c_dim}[%d/%d]${c_reset} " "$job_num" "$total" >&2

                local output
                local exit_code
                if [[ $quiet == true ]]; then
                    _pwr_run_cmd "$line" "$job_num" "1" "${cmd[@]}" >/dev/null 2>&1
                    exit_code=$?
                elif [[ $tag_output == true ]]; then
                    output=$(_pwr_run_cmd "$line" "$job_num" "1" "${cmd[@]}" 2>&1)
                    exit_code=$?
                    if [[ -n "$output" ]]; then
                        while IFS= read -r out_line; do
                            printf "${c_dim}%s:${c_reset} %s\n" "$line" "$out_line"
                        done <<< "$output"
                    fi
                else
                    _pwr_run_cmd "$line" "$job_num" "1" "${cmd[@]}"
                    exit_code=$?
                fi

                (( processed++ ))
                if (( exit_code != 0 )); then
                    (( failed++ ))
                    [[ $verbose == true ]] && printf "${c_red}[FAILED]${c_reset} exit code %d\n" "$exit_code" >&2
                    if [[ $fail_fast == true ]]; then
                        printf "${c_red}Stopping due to --fail-fast${c_reset}\n" >&2
                        return 1
                    fi
                fi

                _pwr_show_progress
            fi
        done
    else
        # Parallel execution
        local -a pids=()
        local -a job_lines=()
        local -a tmpfiles=()
        local job_num=0
        local job_slot=0
        local running=0

        # Create temp directory for ordered output
        local tmpdir=""
        if [[ $keep_order == true ]]; then
            tmpdir=$(mktemp -d)
            trap "rm -rf '$tmpdir'" EXIT
        fi

        for line in "${lines[@]}"; do
            (( job_num++ ))
            (( job_slot = (job_slot % jobs) + 1 ))

            (( delay > 0 )) && (( job_num > 1 )) && sleep "$delay"

            if [[ $dry_run == true ]]; then
                local -a preview_cmd=()
                for arg in "${cmd[@]}"; do
                    preview_cmd+=("$(_pwr_expand "$arg" "$line" "$job_num" "$job_slot")")
                done
                if [[ $has_placeholder == false ]] && [[ $pass_stdin == false ]]; then
                    local processed_line="$line"
                    if [[ $trim_input == true ]]; then
                        processed_line="${line#"${line%%[![:space:]]*}"}"
                        processed_line="${processed_line%"${processed_line##*[![:space:]]}"}"
                    fi
                    preview_cmd+=("$processed_line")
                fi
                printf "${c_yellow}[DRY RUN %d]${c_reset} %s\n" "$job_num" "${preview_cmd[*]}"
                continue
            fi

            # Wait for a slot if we're at max jobs
            while (( running >= jobs )); do
                for i in "${!pids[@]}"; do
                    if ! kill -0 "${pids[$i]}" 2>/dev/null; then
                        wait "${pids[$i]}" 2>/dev/null
                        local exit_code=$?
                        (( processed++ ))
                        if (( exit_code != 0 )); then
                            (( failed++ ))
                            if [[ $fail_fast == true ]]; then
                                # Kill remaining jobs
                                for pid in "${pids[@]}"; do
                                    kill "$pid" 2>/dev/null
                                done
                                printf "${c_red}Stopping due to --fail-fast${c_reset}\n" >&2
                                [[ -n "$tmpdir" ]] && rm -rf "$tmpdir"
                                return 1
                            fi
                        fi
                        unset 'pids[i]'
                        (( running-- ))
                        _pwr_show_progress
                    fi
                done
                (( running >= jobs )) && sleep 0.05
            done

            # Start new job
            if [[ $keep_order == true ]]; then
                local tmpfile="$tmpdir/$job_num"
                (
                    if [[ $quiet == true ]]; then
                        _pwr_run_cmd "$line" "$job_num" "$job_slot" "${cmd[@]}" >/dev/null 2>&1
                    elif [[ $tag_output == true ]]; then
                        local output
                        output=$(_pwr_run_cmd "$line" "$job_num" "$job_slot" "${cmd[@]}" 2>&1)
                        if [[ -n "$output" ]]; then
                            while IFS= read -r out_line; do
                                printf "%s: %s\n" "$line" "$out_line"
                            done <<< "$output"
                        fi
                    else
                        _pwr_run_cmd "$line" "$job_num" "$job_slot" "${cmd[@]}"
                    fi
                ) > "$tmpfile" 2>&1 &
                tmpfiles+=("$tmpfile")
            else
                (
                    if [[ $quiet == true ]]; then
                        _pwr_run_cmd "$line" "$job_num" "$job_slot" "${cmd[@]}" >/dev/null 2>&1
                    elif [[ $tag_output == true ]]; then
                        local output
                        output=$(_pwr_run_cmd "$line" "$job_num" "$job_slot" "${cmd[@]}" 2>&1)
                        if [[ -n "$output" ]]; then
                            while IFS= read -r out_line; do
                                printf "%s: %s\n" "$line" "$out_line"
                            done <<< "$output"
                        fi
                    else
                        _pwr_run_cmd "$line" "$job_num" "$job_slot" "${cmd[@]}"
                    fi
                ) &
            fi

            pids+=($!)
            job_lines+=("$line")
            (( running++ ))
        done

        # Wait for remaining jobs
        for i in "${!pids[@]}"; do
            wait "${pids[$i]}" 2>/dev/null
            local exit_code=$?
            (( processed++ ))
            if (( exit_code != 0 )); then
                (( failed++ ))
            fi
            _pwr_show_progress
        done

        # Output in order if requested
        if [[ $keep_order == true ]] && [[ $dry_run == false ]]; then
            for tmpfile in "${tmpfiles[@]}"; do
                [[ -f "$tmpfile" ]] && cat "$tmpfile"
            done
            rm -rf "$tmpdir"
            trap - EXIT
        fi
    fi

    # Final progress line
    if [[ $progress == true ]] && [[ -t 2 ]] && [[ $dry_run == false ]]; then
        local elapsed=$((SECONDS - start_time))
        printf "\r${c_green}[████████████████████]${c_reset} 100%% (%d/%d) Done in %ds" \
            "$total" "$total" "$elapsed" >&2
        if (( failed > 0 )); then
            printf " ${c_red}(%d failed)${c_reset}" "$failed" >&2
        fi
        printf "\n" >&2
    fi

    [[ $verbose == true ]] && printf "${c_dim}Completed: %d succeeded, %d failed${c_reset}\n" \
        "$((total - failed))" "$failed" >&2

    # Return failure if any job failed
    (( failed > 0 )) && return 1
    return 0
}

# Alias for shorter usage
alias pwr='pipe-while-read'
