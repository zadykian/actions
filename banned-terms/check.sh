#!/bin/bash
# Warns on the terms of terms.txt in what pull request $PR of $GH_REPO adds. It reads the
# environment that lib/report.sh names, and never fails the job.

set -euo pipefail

# shellcheck source=lib/report.sh
. "$GITHUB_ACTION_PATH/../lib/report.sh"
report_start banned-terms
skill=https://github.com/zadykian/skills/blob/main/skills/banned-terms/SKILL.md

# The list: each group's rule, its KEY, TITLE and HINT. A group's key is its number, and a term
# that two groups name goes to the later one.
config=$(jq -Rnr '[inputs | select(test("^\\s*(#|$)") | not)
    | capture("^(?<terms>[^:]*):\\s*(?<hint>.*)")
    | .terms |= [ascii_downcase | splits("[^a-z0-9]+") | select(. != "")]]
    | (reduce to_entries[] as $group ({}; .[$group.value.terms[]] = "\($group.key)")) as $index
    | to_entries[] | "\(.key)" as $key
    | [.value.terms[] | select($index[.] == $key)] as $terms | select($terms != [])
    | [$key, ($terms | join(", ")), .value.hint] | map(gsub("\t"; " ")) | join("\t")' \
    "$GITHUB_ACTION_PATH/terms.txt")
while IFS=$'\t' read -r key title hint; do
    rule "$key" "$title" "$skill" "$hint"
done <<<"$config"

report_finish
