#!/usr/bin/env zsh

# -----------------------------------------------------------------------------
# pipe-while-read
#
# A robust zsh function to map stdin lines to commands.
# Exceeds standard 'xargs' usage by offering smart placeholders,
# interactive safety, and seamless parallel execution.
# -----------------------------------------------------------------------------

pipe-while-read() {
    # Emulate zsh environment for consistency
    emulate -L zsh
    setopt extended_glob

    # -------------------------------------------------------------------------
    # Help & Usage
    # -------------------------------------------------------------------------
    local usage=(
        "Usage: ... | pipe-while-read [options] -- <command> [args...]"
        ""
        "Options:"
        "  -n, --dry-run     Show commands without executing"
        "  -p, --confirm     Interactive mode: ask before executing each line"
        "  -0, --null        Read null-terminated input (safe for filenames)"
        "  -j, --jobs N      Run N jobs in parallel (delegates to zargs)"
        "  -v, --verbose     Print commands as they are executed"
        "  -h, --help        Show this help"
        ""
        "Smart Features:"
        "  - If '{}' is found in the arguments, it is replaced by the input line."
        "  - Otherwise, the input line is appended to the end."
        ""
        "Examples:"
        "  ls *.png | pipe-while-read convert {} {.}.jpg"
        "  find . -print0 | pipe-while-read -0 -n rm"
        "  git branch | pipe-while-read -p git branch -D"
    )

    # -------------------------------------------------------------------------
    # Argument Parsing
    # -------------------------------------------------------------------------
    local dry_run=false
    local verbose=false
    local confirm=false
    local use_null=false
    local jobs=0
    local placeholder="{}"
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n|--dry-run)   dry_run=true ;;
            -v|--verbose)   verbose=true ;;
            -p|--confirm)   confirm=true ;;
            -0|--null)      use_null=true ;;
            -j|--jobs)      
                # Validate positive integer using Zsh's <min-max> glob operator
                if [[ "$2" == <1-> ]]; then
                    jobs="$2"; shift
                else
                    print -u2 "Error: '--jobs' requires a positive integer argument (got: '$2')."
                    return 1
                fi
                ;;
            -h|--help)      print -l $usage; return 0 ;;
            --)             shift; break ;; # End of flags
            -*)             print "Unknown option: $1"; return 1 ;;
            *)              break ;; # Start of command
        esac
        shift
    done

    if [[ $# -eq 0 ]]; then
        print -l $usage
        return 1
    fi

    local cmd_template=("$@")
    
    # -------------------------------------------------------------------------
    # Parallel Execution Path (Delegate to zargs)
    # -------------------------------------------------------------------------
    if (( jobs > 0 )); then
        autoload -U zargs
        
        local zargs_opts=()
        [[ $use_null == true ]] && zargs_opts+=('--null')
        [[ $verbose == true ]]  && zargs_opts+=('--verbose')
        [[ $confirm == true ]]  && zargs_opts+=('--interactive') # Map confirm to zargs interactive
        
        zargs_opts+=("-P" "$jobs")
        
        # Smart placeholder mapping for zargs
        if [[ "${cmd_template[*]}" == *"${placeholder}"* ]]; then
            zargs_opts+=("-I" "${placeholder}")
        fi

        # Handle Dry Run
        if [[ $dry_run == true ]]; then
            # We use `print -r --` as the command to show what zargs *would* have executed.
            # -P enables prompt expansion for colors.
            print -P "%F{yellow}[Parallel Dry Run]%f (Commands that would be executed):"
            zargs "${zargs_opts[@]}" -- print -r -- "${cmd_template[@]}"
        else
            zargs "${zargs_opts[@]}" -- "${cmd_template[@]}"
        fi
        return $?
    fi

    # -------------------------------------------------------------------------
    # Sequential Execution Path (Pure Zsh)
    # -------------------------------------------------------------------------
    
    local use_replacement=false
    if [[ "${cmd_template[*]}" == *"${placeholder}"* ]]; then
        use_replacement=true
    fi

    local line
    local delim=$'\n'
    [[ $use_null == true ]] && delim=$'\0'

    # Read loop using dynamic delimiter (avoids eval)
    while read -r -d "$delim" line; do
        # Skip empty lines if not in null mode
        [[ $use_null == false && -z "$line" ]] && continue

        # Construct the final command
        local final_cmd=()
        if [[ $use_replacement == true ]]; then
            final_cmd=("${(@)cmd_template//$placeholder/$line}")
        else
            final_cmd=("${cmd_template[@]}" "$line")
        fi

        # 1. Dry Run (Yellow)
        if [[ $dry_run == true ]]; then
            print -P "%F{yellow}[DRY RUN]%f ${(q)final_cmd}"
            continue
        fi

        # 2. Verbose (Cyan)
        if [[ $verbose == true ]]; then
            print -P "%F{cyan}[EXEC]%f ${(q)final_cmd}"
        fi

        # 3. Confirmation
        if [[ $confirm == true ]]; then
            if ! read -q "REPLY?Execute? [y/N] "; then
                print "" # Newline after prompt
                continue
            fi
            print "" # Newline after prompt
        fi

        # 4. Execution
        "${final_cmd[@]}"
    done
}