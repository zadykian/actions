# shellcheck shell=bash
# The cases of banned-terms/check.sh. Their fixtures hold the terms of banned-terms/terms.txt.

# start starts the case $1, of a pull request with no commit and no file.
start() {
    setup "$1"
    answer repos/o/r/pulls/1/commits '[]'
    answer repos/o/r/pulls/1/files '[]'
}

start passes-a-clean-pull-request
check banned-terms
warnings 0
summarizes "No findings remain as of \`0123456\`."
writes 0
