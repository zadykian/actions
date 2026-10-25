# shellcheck shell=bash
# Path exclusion by glob, which a check.sh sources to skip the files its exclude input names:
#
#   excluded PATH   succeeds where PATH, from the repository's root, matches a glob of $EXCLUDE
#
# EXCLUDE holds a glob a line; blank lines and the spaces around a glob are dropped. A glob
# matches as git's :(glob) pathspec does:
#
# - * and ? match within a directory, never a /;
# - **/ matches zero or more directories, and a trailing /** everything inside;
# - every other character matches itself.
#
# Sourcing it defines functions and sets the glob_ variables, and runs nothing.

# The globs of EXCLUDE as excluded last read it, and their regular expressions.
glob_source='' glob_regexes=()

# glob_regex prints the extended regular expression that matches the paths the glob $1 matches.
glob_regex() {
    local glob=$1 regex='' rest i=0
    while [ "$i" -lt "${#glob}" ]; do
        rest=${glob:i}
        if [ "$i" = 0 ] || [ "${glob:i-1:1}" = / ]; then
            case $rest in
            '**/'*) regex+='(.*/)?' i=$((i + 3)) && continue ;;
            '**') regex+='.*' && break ;;
            esac
        fi
        case ${rest:0:1} in
        '*') regex+='[^/]*' ;;
        '?') regex+='[^/]' ;;
        '.' | '+' | '^' | '$' | '|' | '(' | ')' | '{' | '}' | '[' | \\) regex+="\\${rest:0:1}" ;;
        *) regex+=${rest:0:1} ;;
        esac
        i=$((i + 1))
    done
    printf '^%s$' "$regex"
}

# excluded succeeds where the path $1 matches one of the globs of $EXCLUDE.
excluded() {
    local glob regex
    if [ "${EXCLUDE-}" != "$glob_source" ]; then
        glob_source=${EXCLUDE-}
        glob_regexes=()
        while IFS= read -r glob; do
            glob=${glob#"${glob%%[![:space:]]*}"}
            glob=${glob%"${glob##*[![:space:]]}"}
            [ -z "$glob" ] || glob_regexes+=("$(glob_regex "$glob")")
        done <<<"$glob_source"
    fi
    for regex in "${glob_regexes[@]}"; do
        [[ $1 =~ $regex ]] && return 0
    done
    return 1
}
