#!/bin/bash
# Warns on the terms of terms.txt in what pull request $PR of $GH_REPO adds: its title. It reads
# the environment that lib/report.sh names, and never fails the job.
# shellcheck disable=SC2016 # The jq programs' $ variables are jq's, in single quotes.

set -euo pipefail

# shellcheck source=lib/report.sh
. "$GITHUB_ACTION_PATH/../lib/report.sh"
report_start banned-terms
skill=https://github.com/zadykian/skills/blob/main/skills/banned-terms/SKILL.md

# The list: on its first line the index, {TERM: KEY}, then each group's rule, its KEY, TITLE and
# HINT. A group's key is its number, and a term that two groups name goes to the later one.
config=$(jq -Rnr '[inputs | select(test("^\\s*(#|$)") | not)
    | capture("^(?<terms>[^:]*):\\s*(?<hint>.*)")
    | .terms |= [ascii_downcase | splits("[^a-z0-9]+") | select(. != "")]]
    | (reduce to_entries[] as $group ({}; .[$group.value.terms[]] = "\($group.key)")) as $index
    | ($index | tojson), (to_entries[] | "\(.key)" as $key
        | [.value.terms[] | select($index[.] == $key)] as $terms | select($terms != [])
        | [$key, ($terms | join(", ")), .value.hint] | map(gsub("\t"; " ")) | join("\t"))' \
    "$GITHUB_ACTION_PATH/terms.txt")
{
    read -r index
    while IFS=$'\t' read -r key title hint; do
        rule "$key" "$title" "$skill" "$hint"
    done
} <<<"$config"

# The jq functions of a scan. terms gives each term of $index that the text . holds, once: its
# tokens split at each character other than a letter or a digit, then at each hump of camelCase,
# as getHTTPResponse gives get, http and response. A test of the text first skips most lines.
# find gives a finding of each, a line of KEY, MESSAGE, FILE and LINE, separated by tabs.
defs='($index | keys | join("|")) as $any
| def terms: select(test($any; "i"))
    | gsub("(?<a>[a-z0-9])(?<b>[A-Z])"; "\(.a) \(.b)")
    | gsub("(?<a>[A-Z])(?=[A-Z][a-z])"; "\(.a) ")
    | [ascii_downcase | splits("[^a-z0-9]+") | select($index[.])] | unique[];
  def code: gsub("\\s+"; " ") | sub("^ "; "") | sub(" $"; "")
    | if length > 120 then .[:119] + "…" else . end | "`\(.)`";
  def find($where; $file; $line): . as $text | terms
    | [$index[.], "\($where) says `\(.)`: \($text | code)", $file, $line]
    | map(tostring | gsub("[\t\n]"; " ")) | join("\t");'

# scan prints the findings of the jq filter $1, of defs, on its input.
scan() {
    jq -r --argjson index "$index" "$defs $1"
}

found=$(gh api "repos/$GH_REPO/pulls/$PR" | scan '.title | find("The title"; ""; "")')$'\n'
while IFS=$'\t' read -r key message file line; do
    [ -z "$key" ] || finding "$key" "$message" "$file" "$line"
done <<<"$found"
report_finish
