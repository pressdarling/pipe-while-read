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
    
    # Zparseopts is robust, but for a single function without deps, 
    # a manual loop is often more portable and easier to debug.
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n|--dry-run)   dry_run=true ;;
            -v|--verbose)   verbose=true ;;
            -p|--confirm)   confirm=true ;;
            -0|--null)      use_null=true ;;
            -j|--jobs)      
                if [[ -n "$2" && "$2" != -* ]]; then
                    jobs="$2"; shift
                else
                    jobs=1 # Fallback or error could go here
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

    # The command template
    local cmd_template=("$@")
    
    # -------------------------------------------------------------------------
    # Parallel Execution Path (Delegate to zargs)
    # -------------------------------------------------------------------------
    if (( jobs > 0 )); then
        # zargs is the standard zsh equivalent to xargs, safer and built-in.
        autoload -U zargs
        
        local zargs_opts=()
        [[ $dry_run == true ]] && zargs_opts+=('--interactive') # zargs uses -p for interactive/dryish
        [[ $use_null == true ]] && zargs_opts+=('--null')
        [[ $verbose == true ]] && zargs_opts+=('--verbose')
        
        # zargs requires -P for procs
        zargs_opts+=("-P" "$jobs")
        
        # Check for placeholder usage in parallelism
        # zargs uses --replace/-I. We need to map our smart detection to zargs.
        if [[ "${cmd_template[*]}" == *"${placeholder}"* ]]; then
            zargs_opts+=("-I" "${placeholder}")
        else
            # If no placeholder, zargs appends by default, which matches our logic.
            :
        fi

        # Execute zargs
        # Note: zargs reads from stdin automatically if no input files are given.
        if [[ $dry_run == true ]]; then
             print -P "%B[Parallel Dry Run]%b zargs ${zargs_opts} -- ${cmd_template}"
             # We can't easily preview exact execution paths of zargs without running it
             # so we just show the zargs command invocation.
        else
             zargs "${zargs_opts[@]}" -- "${cmd_template[@]}"
        fi
        return $?
    fi

    # -------------------------------------------------------------------------
    # Sequential Execution Path (Pure Zsh)
    # -------------------------------------------------------------------------
    
    # Detect if we are using replacement or appending
    local use_replacement=false
    if [[ "${cmd_template[*]}" == *"${placeholder}"* ]]; then
        use_replacement=true
    fi

    local line
    local read_cmd
    
    # Choose delimiter strategy
    if [[ $use_null == true ]]; then
        # -d $'\0' is safe for zsh read
        read_cmd="read -r -d $'\0'"
    else
        read_cmd="read -r"
    fi

    # Main Loop
    while eval "$read_cmd line"; do
        # Skip empty lines if not in null mode (standard text behavior)
        [[ $use_null == false && -z "$line" ]] && continue

        # Construct the final command
        local final_cmd=()
        if [[ $use_replacement == true ]]; then
            # Iterate and replace exact matches of placeholder
            # Optimization: Zsh substitution ${var//pattern/repl} works on arrays
            final_cmd=("${(@)cmd_template//$placeholder/$line}")
        else
            final_cmd=("${cmd_template[@]}" "$line")
        fi

        # 1. Dry Run / Verbose
        if [[ $dry_run == true || $verbose == true ]]; then
            local pretty_cmd="${(q)final_cmd}" # (q) quotes arguments for display
            print -P "%F{cyan}[EXEC]%f $pretty_cmd"
            [[ $dry_run == true ]] && continue
        fi

        # 2. Confirmation
        if [[ $confirm == true ]]; then
            if ! read -q "REPLY?Execute? [y/N] "; then
                print "" # Newline after prompt
                continue
            fi
            print "" # Newline after prompt
        fi

        # 3. Execution
        "${final_cmd[@]}"
    done
}
