# shellcheck shell=bash
# The cases of pr-description/check.sh, each a description of pull request #1.

# describe starts the case $1, of pull request #1 into main, its default branch, with the
# description $2 and the fields of the JSON $3 over it. It checks it with the VAR=VALUE arguments
# after them.
describe() {
    setup "$1"
    answer repos/o/r/pulls/1 "$(pull "$(jq -n --arg body "$2" --argjson over "${3:-null}" \
        '{body: $body, base: {repo: {default_branch: "main"}}} * ($over // {})')")"
    check pr-description "${@:4}"
}

setup warns-on-an-empty-description
check pr-description
warns '::warning title=pr-description%3A The description is empty::The description of #1 is empty.'
summarizes '## Problem

What is wrong or missing today'
warnings 1

describe warns-on-a-blank-description $' \r\n\t\n'
warns 'The description of #1 is empty.'

describe warns-on-no-description '' '{"body": null}'
warns 'The description of #1 is empty.'
