#!/usr/bin/env bash
# source code generated using shource: https://github.com/oliverisaac/shource
# vim: autoindent tabstop=4 shiftwidth=4 expandtab softtabstop=4 ft=sh

set -e # Exit on any error. Use `COMMAND || true` to nullify
set -E # Functions inherit error trap
set -u # Error on unset variables. Use ${var:-alternate value} to bypass
set -f # Error on failed file globs (e.g. *.txt )
set -o pipefail # Failed commands in pipes cause the whole pipe to fail

LOG_LEVEL=2

function main()
{
    # Execution starts here
    
    sectionStart="start-slack-theme"
    sectionEnd="end-slack-theme"

    srcFile="/Applications/Slack.app/Contents/Resources/app.asar.unpacked/src/static/ssb-interop.js"

    sed -E -i"" -e "/^.. $sectionStart/,/^.. $sectionEnd/d" "$srcFile"

    cd "$( dirname "$( readlink "$0" )" )" 

    {
        echo "// $sectionStart"
        cat ssb-interop.js 
        echo "// $sectionEnd"
    } | tee -a "$srcFile"

    return 0
}



# On exit is called on every exit
function _on_exit()
{
    # Cleanup code goes here
    local exit_status="$?"
}

function _on_term()
{
    echo "Terminated!" >&2
    # A termination also tends to call an error, so we block that
    trap '' ERR
}

function _on_error()
{
    local lineno=$1
    shift
    local pipe_fails=( "${@}" )
    echo "ERROR (${pipe_fails[@]}) on line $lineno: Most recent call last:" >&2
    _print_stack >&2
    local x
    for x in ${pipe_fails[@]}; do
        if [[ $x -ne 0 ]]; then
            exit $x
        fi
    done
    exit 1
}


function _print_stack()
{
   local STACK=""
   local i 
   local stack_size="${#FUNCNAME[@]}"
   # to avoid noise we start with 1 to skip the get_stack function
   for (( i=( stack_size - 1 ); i>=2; i-- )); do
      local func="${FUNCNAME[$i]}"
      [ x$func = x ] && func=MAIN
      local linen="${BASH_LINENO[$(( i - 1 ))]}"
      local src="${BASH_SOURCE[$i]}"
      [ x"$src" = x ] && src=non_file_source

      echo "   at: $func $src:$linen"
   done
}


trap '_on_term' HUP TERM INT
trap '_on_error $LINENO ${PIPESTATUS[@]}' ERR
trap '_on_exit' EXIT



function json_escape()
{
    local str="$1"
    str=${str//\\/\\\\} # \
    str=${str//\//\\\/} # /
    str=${str//\"/\\\"} # "
    str=${str//   /\\t} # \t (tab)
    str=${str//
/\\\n} # \n (newline)
    str=${str//^M/\\\r} # \r (carriage return)
    str=${str//^L/\\\f} # \f (form feed)
    str=${str//^H/\\\b} # \b (backspace)
    printf "%s" "$str"
}

function json_print()
{
    local args=( "${@}" )
    local num_args=${#args[@]}

    printf "%s" "{"
    for (( i=0; i<$num_args; i=i+2 )); do
        local format="%s"
        local key="${args[$i]}"
        local value="${args[$i+1]}"

        local type="${key##*:}"
        if [[ $type != "" ]]; then
            format="%$type"
        fi

        # IF it's a string type, then wrap in quotes
        if [[ $format =~ s$ ]]; then
            format="\"$format\""
            value=$( json_escape "$value" )
        fi

        local comma=","
        if [[ $i -eq 0 ]]; then
            comma=""
        fi

        printf -- "$comma \"%s\": $format" "${key%%:*}" "$value"
    done

    printf "%s\n" "}"
}


function log()
{
    local level="$1"
    shift
    local args=( "${@}" )
    if [[ $level -le ${LOG_LEVEL:-0} ]]; then
        local time=$( date "+%Y-%m-%d %H:%M:%S.%3N" )
        local message="${@}"

        if [[ ${JSON_LOG_FORMAT:-false} == "false" ]]; then
            echo "$time [log $level]: $message" >&2
        else
            time=$( date -u +"%Y-%m-%dT%H:%M:%S.%3NZ" )
            json_print time:s "$time" level:d "$level" msg:s "$message" >&2
        fi
    fi
}

# Loops through passed in args and sets variables for each of them
# Call like this: _parse_args help refresh debug -- "${@}"
function parse_args()
{
    local boolean_flags=()
    local input_args=( "${@}" )
    local num_args=${#input_args[@]}
    local this_arg i key value

    for (( i=0; i<num_args; i++ )); do
        this_arg="${input_args[$i]}"
        log 4 "$i : $this_arg"
        if [[ $this_arg == "--" ]]; then
            i=$(( i + 1 ))
            break
        fi
        boolean_flags+=( "$( echo "${this_arg}" | tr '_-' '.' | sed 's/^-*//' )" )
    done

    local boolean_regex=$( IFS='|'; echo "${boolean_flags[*]}" )
    boolean_regex="^--(no-)?(${boolean_regex})(=(true|false))?$"

    local populate_args=false
    declare -g -a _args=()
    for (( ; i<num_args; i++ )); do
        this_arg="${input_args[$i]}"
        log 4 "$i : $this_arg"
        if $populate_args; then
            log 4 "Appending $this_arg to _args[]"
            _args+=( "$this_arg" )
            continue
        fi

        if [[ $this_arg == "--" ]]; then
            populate_args=true
            continue
        fi

        key=""
        value=true
        # Boolean flags
        if [[ ${#boolean_flags[@]} -gt 0 ]] && [[ $this_arg =~ $boolean_regex ]]; then
            key="${BASH_REMATCH[2]}"

            if [[ ${BASH_REMATCH[4]} == "false" ]]; then
                if [[ ${BASH_REMATCH[1]} == "no-" ]]; then
                    value=true
                else
                    value=false
                fi
            else
                if [[ ${BASH_REMATCH[1]} == "no-" ]]; then
                    value=false
                else
                    value=true
                fi
            fi
        elif [[ $this_arg =~ ^--([^=]+)=(.*)$ ]]; then
            key="${BASH_REMATCH[1]}"
            value="${BASH_REMATCH[2]}"
        elif [[ $this_arg =~ ^--(.+)$ ]]; then
            key="${BASH_REMATCH[1]}"
            ((i++))
            value="${input_args[$i]}"
        fi
        key="${key//-/_}"
        if [[ $key == "" ]]; then
            _args+=( "$this_arg" )
        else
            log 4 "Setting $key to $value"
            declare -g "$key"="$value"
        fi
    done
}

function _display_help()
{
    cat - > >( sed -r -e "s/^ {,8}//" ) <<EOF
        Sample help file
        TADA!
EOF
}

trap '_on_term' HUP TERM INT
trap '_on_error $LINENO ${PIPESTATUS[@]}' ERR
trap '_on_exit' EXIT

# Check if any of the args are a cry for help
if echo "${@}" | grep -q -wiEe "-h|--help|help"; then
    _display_help
    exit 4
fi

# Edit parse args to indicate which flags are boolean. Then pass each of those arguments to main
parse_args -- "${@}"
main "${@}"

exit $?


