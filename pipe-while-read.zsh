#!/usr/bin/env zsh
# pipe-while-read - A powerful stdin-to-command processor
# Exceeds xargs, GNU parallel, rush in features while remaining simple
#
# Features:
#   - Parallel execution with job control
#   - Rich placeholder substitution ({}, {.}, {/}, {//}, {/.}, {#}, {n})
#   - Progress indicator with ETA
#   - Timeout and retry support (pure zsh fallback for macOS)
#   - Keep output order option
#   - Field extraction with custom delimiters
#   - Null-delimited input support
#   - Verbose, quiet, and dry-run modes
#   - Pass line to stdin instead of argument
#   - Streaming mode for memory efficiency (when progress not needed)

pipe-while-read() {
    # Default options
    local dry_run=false
    local verbose=false
    local quiet=false
    local help=false
    local jobs=1
    local timeout_secs=0
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
                timeout_secs=${2:-0}; shift 2 ;;
            -t*)
                timeout_secs=${1#-t}; shift ;;
            --timeout=*)
                timeout_secs=${1#--timeout=}; shift ;;
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
                printf '%s%s%s\n' "${c_red}Error: Unknown option: " "$1" "${c_reset}" >&2
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

NOTES:
    - The timeout feature requires GNU coreutils 'timeout' command, or falls
      back to a pure-zsh implementation using background jobs.
    - Without -P/--progress, input is processed in streaming mode (memory
      efficient for large inputs). With progress, all input is buffered.
EOF
        return 0
    fi

    # Build command template
    local -a cmd=("$@")
    local has_placeholder=false

    # Check if any argument contains a placeholder
    local arg
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

    # Helper: trim whitespace from a string
    _pwr_trim() {
        local str="$1"
        str="${str#"${str%%[![:space:]]*}"}"
        str="${str%"${str##*[![:space:]]}"}"
        printf '%s' "$str"
    }

    # Helper: expand placeholders in a string
    _pwr_expand() {
        local template="$1"
        local line="$2"
        local job_num="$3"
        local job_slot="$4"
        local result="$template"

        # Trim if requested
        local processed_line="$line"
        if [[ $trim_input == true ]]; then
            processed_line="$(_pwr_trim "$line")"
        fi

        # Split into fields
        local -a fields
        if [[ -n "$delimiter" ]]; then
            IFS="$delimiter" read -rA fields <<< "$processed_line"
        else
            fields=("$processed_line")
        fi

        # Path components
        local base="${processed_line##*/}"
        local dir="${processed_line%/*}"
        [[ "$dir" == "$processed_line" ]] && dir="."
        local noext="${processed_line%.*}"
        local base_noext="${base%.*}"
        local ext="${base##*.}"
        [[ "$ext" == "$base" ]] && ext=""

        # Expand placeholders
        result="${result//\{#\}/$job_num}"
        result="${result//\{%\}/$job_slot}"
        result="${result//\{len\}/${#processed_line}}"
        result="${result//\{ext\}/$ext}"
        result="${result//\{\/.\}/$base_noext}"
        result="${result//\{\/\/\}/$dir}"
        result="${result//\{\/\}/$base}"
        result="${result//\{.\}/$noext}"

        # Field extraction {1}, {2}, {-1}, {-2}, etc.
        local i field_val neg_idx
        for i in {1..20}; do
            if [[ "$result" == *"{$i}"* ]]; then
                field_val="${fields[$i]:-}"
                result="${result//\{$i\}/$field_val}"
            fi
            if [[ "$result" == *"{-$i}"* ]]; then
                neg_idx=$((${#fields[@]} - i + 1))
                field_val="${fields[$neg_idx]:-}"
                result="${result//\{-$i\}/$field_val}"
            fi
        done

        # Finally expand {} (must be last to avoid partial matches)
        result="${result//\{\}/$processed_line}"

        printf '%s' "$result"
    }

    # Helper: run command with timeout (pure zsh fallback for macOS)
    _pwr_timeout() {
        local secs="$1"
        shift
        local -a cmd_to_run=("$@")

        # Try GNU timeout first (Linux, Homebrew on macOS)
        if command -v timeout &>/dev/null; then
            timeout "$secs" "${cmd_to_run[@]}"
            return $?
        fi

        # Pure zsh fallback using background job
        local pid
        "${cmd_to_run[@]}" &
        pid=$!

        # Wait with timeout
        local elapsed=0
        while (( elapsed < secs )); do
            if ! kill -0 "$pid" 2>/dev/null; then
                wait "$pid" 2>/dev/null
                return $?
            fi
            sleep 0.1
            elapsed=$((elapsed + 1))
            # Check 10 times per second
            (( elapsed % 10 == 0 )) || elapsed=$((elapsed - 1))
        done

        # Timeout reached, kill the process
        kill -TERM "$pid" 2>/dev/null
        sleep 0.1
        kill -KILL "$pid" 2>/dev/null
        wait "$pid" 2>/dev/null
        return 124  # Standard timeout exit code
    }

    # Helper: run a single command with timeout and retries
    _pwr_run_cmd() {
        local line="$1"
        local job_num="$2"
        local job_slot="$3"
        shift 3
        local -a cmd_template=("$@")
        local -a expanded_cmd=()

        # Expand placeholders in each argument
        local arg
        for arg in "${cmd_template[@]}"; do
            expanded_cmd+=("$(_pwr_expand "$arg" "$line" "$job_num" "$job_slot")")
        done

        # If no placeholder was used, append line as final argument
        if [[ $has_placeholder == false ]] && [[ $pass_stdin == false ]]; then
            local processed_line="$line"
            if [[ $trim_input == true ]]; then
                processed_line="$(_pwr_trim "$line")"
            fi
            expanded_cmd+=("$processed_line")
        fi

        local attempt=0
        local max_attempts=$((retries + 1))
        local cmd_exit_code=1

        while (( attempt < max_attempts )); do
            (( attempt++ ))

            if [[ $verbose == true ]] && (( attempt > 1 )); then
                printf '%s[RETRY %d/%d]%s %s\n' "${c_yellow}" "$attempt" "$max_attempts" "${c_reset}" "${expanded_cmd[*]}" >&2
            fi

            if [[ $pass_stdin == true ]]; then
                # Pass line to stdin
                if (( timeout_secs > 0 )); then
                    printf '%s\n' "$line" | _pwr_timeout "$timeout_secs" "${expanded_cmd[@]}"
                else
                    printf '%s\n' "$line" | "${expanded_cmd[@]}"
                fi
            else
                if (( timeout_secs > 0 )); then
                    _pwr_timeout "$timeout_secs" "${expanded_cmd[@]}"
                else
                    "${expanded_cmd[@]}"
                fi
            fi
            cmd_exit_code=$?

            if (( cmd_exit_code == 0 )); then
                break
            elif (( cmd_exit_code == 124 )); then
                # Timeout occurred
                [[ $verbose == true ]] && printf '%s[TIMEOUT]%s %s\n' "${c_red}" "${c_reset}" "${expanded_cmd[*]}" >&2
            fi

            if (( attempt < max_attempts )); then
                sleep "$retry_delay"
            fi
        done

        return $cmd_exit_code
    }

    # Helper: build preview command for dry-run
    _pwr_build_preview() {
        local line="$1"
        local job_num="$2"
        local job_slot="$3"
        local -a preview_cmd=()
        local arg
        for arg in "${cmd[@]}"; do
            preview_cmd+=("$(_pwr_expand "$arg" "$line" "$job_num" "$job_slot")")
        done
        if [[ $has_placeholder == false ]] && [[ $pass_stdin == false ]]; then
            local processed_line="$line"
            if [[ $trim_input == true ]]; then
                processed_line="$(_pwr_trim "$line")"
            fi
            preview_cmd+=("$processed_line")
        fi
        printf '%s' "${preview_cmd[*]}"
    }

    # Determine if we need to buffer all input (for progress bar or {#} placeholder)
    local needs_buffering=false
    if [[ $progress == true ]] || (( jobs > 1 )); then
        needs_buffering=true
    fi

    # Check if {#} is used - we need total count for that
    for arg in "${cmd[@]}"; do
        if [[ "$arg" == *'{#}'* ]]; then
            needs_buffering=true
            break
        fi
    done

    # Progress tracking variables
    local processed=0
    local failed=0
    local total=0
    local start_time=$SECONDS

    # Helper: show progress bar
    _pwr_show_progress() {
        if [[ $progress == true ]] && [[ -t 2 ]] && (( total > 0 )); then
            local elapsed=$((SECONDS - start_time))
            local eta="--:--"
            if (( processed > 0 )) && (( elapsed > 0 )); then
                local remaining=$(( (total - processed) * elapsed / processed ))
                eta=$(printf '%02d:%02d' $((remaining / 60)) $((remaining % 60)))
            fi
            local pct=$((processed * 100 / total))
            local bar_width=20
            local filled=$((pct * bar_width / 100))
            local bar=""
            local i
            for ((i=0; i<bar_width; i++)); do
                if ((i < filled)); then
                    bar+="█"
                else
                    bar+="░"
                fi
            done
            printf '\r%s[%s]%s %3d%% (%d/%d) ETA: %s  ' \
                "${c_cyan}" "$bar" "${c_reset}" "$pct" "$processed" "$total" "$eta" >&2
        fi
    }

    # Build read options array
    local -a read_opts=(-r)
    [[ $null_delim == true ]] && read_opts+=(-d '')

    # STREAMING MODE: Process line-by-line without buffering
    if [[ $needs_buffering == false ]]; then
        local line
        local job_num=0
        local cmd_exit_code=0

        while IFS= read "${read_opts[@]}" line; do
            (( job_num++ ))
            (( delay > 0 )) && (( job_num > 1 )) && sleep "$delay"

            if [[ $dry_run == true ]]; then
                printf '%s[DRY RUN]%s %s\n' "${c_yellow}" "${c_reset}" "$(_pwr_build_preview "$line" "$job_num" "1")"
            else
                [[ $verbose == true ]] && printf '%s[%d]%s ' "${c_dim}" "$job_num" "${c_reset}" >&2

                if [[ $quiet == true ]]; then
                    _pwr_run_cmd "$line" "$job_num" "1" "${cmd[@]}" >/dev/null 2>&1
                    cmd_exit_code=$?
                elif [[ $tag_output == true ]]; then
                    local cmd_output
                    cmd_output=$(_pwr_run_cmd "$line" "$job_num" "1" "${cmd[@]}" 2>&1)
                    cmd_exit_code=$?
                    if [[ -n "$cmd_output" ]]; then
                        local out_line
                        while IFS= read -r out_line; do
                            printf '%s%s:%s %s\n' "${c_dim}" "$line" "${c_reset}" "$out_line"
                        done <<< "$cmd_output"
                    fi
                else
                    _pwr_run_cmd "$line" "$job_num" "1" "${cmd[@]}"
                    cmd_exit_code=$?
                fi

                (( processed++ ))
                if (( cmd_exit_code != 0 )); then
                    (( failed++ ))
                    [[ $verbose == true ]] && printf '%s[FAILED]%s exit code %d\n' "${c_red}" "${c_reset}" "$cmd_exit_code" >&2
                    if [[ $fail_fast == true ]]; then
                        printf '%sStopping due to --fail-fast%s\n' "${c_red}" "${c_reset}" >&2
                        return 1
                    fi
                fi
            fi
        done

        if (( processed == 0 )) && [[ $dry_run == false ]]; then
            [[ $verbose == true ]] && printf '%sNo input lines to process%s\n' "${c_dim}" "${c_reset}" >&2
        fi

        [[ $verbose == true ]] && (( processed > 0 )) && printf '%sCompleted: %d succeeded, %d failed%s\n' \
            "${c_dim}" "$((processed - failed))" "$failed" "${c_reset}" >&2

        (( failed > 0 )) && return 1
        return 0
    fi

    # BUFFERED MODE: Read all input for progress tracking or parallel execution
    local -a lines=()
    local line

    while IFS= read "${read_opts[@]}" line; do
        lines+=("$line")
    done

    total=${#lines[@]}

    if (( total == 0 )); then
        [[ $verbose == true ]] && printf '%sNo input lines to process%s\n' "${c_dim}" "${c_reset}" >&2
        return 0
    fi

    [[ $verbose == true ]] && printf '%sProcessing %d lines with %d job(s)%s\n' "${c_dim}" "$total" "$jobs" "${c_reset}" >&2

    # Execute commands
    if (( jobs == 1 )); then
        # Sequential execution (buffered for progress)
        local job_num=0
        local cmd_exit_code=0
        for line in "${lines[@]}"; do
            (( job_num++ ))

            (( delay > 0 )) && (( job_num > 1 )) && sleep "$delay"

            if [[ $dry_run == true ]]; then
                printf '%s[DRY RUN]%s %s\n' "${c_yellow}" "${c_reset}" "$(_pwr_build_preview "$line" "$job_num" "1")"
            else
                [[ $verbose == true ]] && printf '%s[%d/%d]%s ' "${c_dim}" "$job_num" "$total" "${c_reset}" >&2

                if [[ $quiet == true ]]; then
                    _pwr_run_cmd "$line" "$job_num" "1" "${cmd[@]}" >/dev/null 2>&1
                    cmd_exit_code=$?
                elif [[ $tag_output == true ]]; then
                    local cmd_output
                    cmd_output=$(_pwr_run_cmd "$line" "$job_num" "1" "${cmd[@]}" 2>&1)
                    cmd_exit_code=$?
                    if [[ -n "$cmd_output" ]]; then
                        local out_line
                        while IFS= read -r out_line; do
                            printf '%s%s:%s %s\n' "${c_dim}" "$line" "${c_reset}" "$out_line"
                        done <<< "$cmd_output"
                    fi
                else
                    _pwr_run_cmd "$line" "$job_num" "1" "${cmd[@]}"
                    cmd_exit_code=$?
                fi

                (( processed++ ))
                if (( cmd_exit_code != 0 )); then
                    (( failed++ ))
                    [[ $verbose == true ]] && printf '%s[FAILED]%s exit code %d\n' "${c_red}" "${c_reset}" "$cmd_exit_code" >&2
                    if [[ $fail_fast == true ]]; then
                        printf '%sStopping due to --fail-fast%s\n' "${c_red}" "${c_reset}" >&2
                        return 1
                    fi
                fi

                _pwr_show_progress
            fi
        done
    else
        # Parallel execution
        local -a pids=()
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
                printf '%s[DRY RUN %d]%s %s\n' "${c_yellow}" "$job_num" "${c_reset}" "$(_pwr_build_preview "$line" "$job_num" "$job_slot")"
                continue
            fi

            # Wait for a slot if we're at max jobs
            while (( running >= jobs )); do
                # Try to use 'wait -n' for efficiency (zsh 5.8+)
                if [[ ${ZSH_VERSION:-} ]] && is-at-least 5.8 2>/dev/null; then
                    wait -n 2>/dev/null
                    local wait_exit=$?
                    if (( wait_exit >= 0 )); then
                        (( processed++ ))
                        if (( wait_exit != 0 )); then
                            (( failed++ ))
                            if [[ $fail_fast == true ]]; then
                                for pid in "${pids[@]}"; do
                                    kill "$pid" 2>/dev/null
                                done
                                printf '%sStopping due to --fail-fast%s\n' "${c_red}" "${c_reset}" >&2
                                [[ -n "$tmpdir" ]] && rm -rf "$tmpdir"
                                return 1
                            fi
                        fi
                        (( running-- ))
                        _pwr_show_progress
                    fi
                else
                    # Fallback: poll for finished jobs
                    local i job_exit
                    for i in "${!pids[@]}"; do
                        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
                            wait "${pids[$i]}" 2>/dev/null
                            job_exit=$?
                            (( processed++ ))
                            if (( job_exit != 0 )); then
                                (( failed++ ))
                                if [[ $fail_fast == true ]]; then
                                    local pid
                                    for pid in "${pids[@]}"; do
                                        kill "$pid" 2>/dev/null
                                    done
                                    printf '%sStopping due to --fail-fast%s\n' "${c_red}" "${c_reset}" >&2
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
                fi
            done

            # Start new job
            if [[ $keep_order == true ]]; then
                local tmpfile="$tmpdir/$job_num"
                (
                    if [[ $quiet == true ]]; then
                        _pwr_run_cmd "$line" "$job_num" "$job_slot" "${cmd[@]}" >/dev/null 2>&1
                    elif [[ $tag_output == true ]]; then
                        local cmd_output
                        cmd_output=$(_pwr_run_cmd "$line" "$job_num" "$job_slot" "${cmd[@]}" 2>&1)
                        if [[ -n "$cmd_output" ]]; then
                            local out_line
                            while IFS= read -r out_line; do
                                printf '%s: %s\n' "$line" "$out_line"
                            done <<< "$cmd_output"
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
                        local cmd_output
                        cmd_output=$(_pwr_run_cmd "$line" "$job_num" "$job_slot" "${cmd[@]}" 2>&1)
                        if [[ -n "$cmd_output" ]]; then
                            local out_line
                            while IFS= read -r out_line; do
                                printf '%s: %s\n' "$line" "$out_line"
                            done <<< "$cmd_output"
                        fi
                    else
                        _pwr_run_cmd "$line" "$job_num" "$job_slot" "${cmd[@]}"
                    fi
                ) &
            fi

            pids+=($!)
            (( running++ ))
        done

        # Wait for remaining jobs
        local i job_exit
        for i in "${!pids[@]}"; do
            wait "${pids[$i]}" 2>/dev/null
            job_exit=$?
            (( processed++ ))
            if (( job_exit != 0 )); then
                (( failed++ ))
            fi
            _pwr_show_progress
        done

        # Output in order if requested
        if [[ $keep_order == true ]] && [[ $dry_run == false ]]; then
            local tmpfile
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
        printf '\r%s[████████████████████]%s 100%% (%d/%d) Done in %ds' \
            "${c_green}" "${c_reset}" "$total" "$total" "$elapsed" >&2
        if (( failed > 0 )); then
            printf ' %s(%d failed)%s' "${c_red}" "$failed" "${c_reset}" >&2
        fi
        printf '\n' >&2
    fi

    [[ $verbose == true ]] && printf '%sCompleted: %d succeeded, %d failed%s\n' \
        "${c_dim}" "$((total - failed))" "$failed" "${c_reset}" >&2

    # Return failure if any job failed
    (( failed > 0 )) && return 1
    return 0
}

# Alias for shorter usage
alias pwr='pipe-while-read'
