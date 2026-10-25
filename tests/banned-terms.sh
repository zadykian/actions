# shellcheck shell=bash
# The cases of banned-terms/check.sh. Their fixtures hold the terms of banned-terms/terms.txt.

skill=https://github.com/zadykian/skills/blob/main/skills/banned-terms/SKILL.md

# start starts the case $1, of a pull request with no commit and no file.
start() {
    setup "$1"
    answer repos/o/r/pulls/1/commits '[]'
    answer repos/o/r/pulls/1/files '[]'
}

# titled answers the pull request with the title $1.
titled() {
    answer repos/o/r/pulls/1 "$(pull "$(jq -n --arg title "$1" '{title: $title}')")"
}

# matches checks that the title $1 gives a finding of each term after it, and no other.
matches() {
    local term
    start "matches-$1"
    titled "$1"
    check banned-terms
    for term in "${@:2}"; do warns "::The title says \`$term\`: \`$1\`"; done
    warnings $(($# - 1))
}

matches StringHelper helper
matches str_utils.py utils
matches MiscStuff misc stuff
matches HTTPHelper helper
matches 'getHTTPResponse, XMLHttpHelpers and HTTP2Util' helpers util
matches 'Etc. and SIMPLY' etc simply
matches 'utilize, helpful and etcd'
matches 'utils2, Thingy and miscount'

start reports-a-group-as-its-rule
titled 'feat: add a string helper and its helper test'
check banned-terms
warns "::warning title=banned-terms%3A helper%2C helpers::The title says \`helper\`"
warnings 1
summarizes "#### helper, helpers

The rule: $skill

- The title says \`helper\`: \`feat: add a string helper and its helper test\`

How to fix it:

Names no responsibility: name what it does"

start passes-a-clean-pull-request
check banned-terms
warnings 0
summarizes "No findings remain as of \`0123456\`."
writes 0
