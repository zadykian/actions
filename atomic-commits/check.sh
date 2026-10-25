#!/bin/bash
# Warns where the commits of pull request $PR of $GH_REPO break the rules of the atomic-commits
# skill. TYPES holds the types that a header may take.

set -euo pipefail
# A $(...) fails as its command fails. A length counts characters, not bytes.
shopt -s inherit_errexit
export LC_ALL=C.UTF-8
# shellcheck source=lib/report.sh
. "$GITHUB_ACTION_PATH/../lib/report.sh"

# header records the findings of the header $2, which $1 names, under the rule $3, or each under
# its own rule where $3 is omitted.
header() {
    local description=${2#*: }
    [[ $2 =~ $header_form ]] ||
        finding "${3:-header}" "$1: the header is not \`type(scope)!: description\`."
    [ "${#2}" -le 72 ] || finding "${3:-header-length}" "$1: the header is ${#2} characters long."
    [[ $2 == *': '* ]] || return 0
    if [[ $description =~ ^[[:upper:]] ]]; then
        finding "${3:-description}" "$1: the description \`$description\` starts uppercase."
    fi
    if [[ $description == *. ]]; then
        finding "${3:-description}" "$1: the description \`$description\` ends with a period."
    fi
}

report_start atomic-commits
skill=https://github.com/zadykian/skills/blob/main/skills/atomic-commits/SKILL.md
base=$(gh api "repos/$GH_REPO/pulls/$PR" --jq .base.ref)
read -r -d '' -a allowed <<<"$TYPES" || true
header_form="^($(IFS='|' && echo "${allowed[*]}"))(\([a-z0-9._/-]+\))?!?: [^ ]"
# How to reword a commit, as section 4 of the skill says.
reword=$(
    cat <<'FIX'
Reword the commit, then push it with `git push --force-with-lease`. The last one:
`git commit --amend -m "<header>" -m "<body>"`. An earlier one: write its whole message to
`/tmp/msg.txt`, then run this, with its sha7 for `<sha7>`:

```sh
GIT_SEQUENCE_EDITOR="perl -pi -e 's/^pick <sha7>/reword <sha7>/'" GIT_EDITOR="cp /tmp/msg.txt" \
    git rebase -i --update-refs <base>
```
FIX
)
reword=${reword//<base>/"$base"}

messages=$skill#3-commit-messages-conventional-commits-100
rule header 'The header is not Conventional Commits' "$messages" "Write the header as \
\`type(scope)!: description\`, its type one of \`$TYPES\` and its scope lowercase. $reword"
rule header-length 'The header is over 72 characters' "$messages" \
    "Shorten the header to 72 characters at most. $reword"
rule description 'The description starts uppercase or ends with a period' "$messages" \
    "Write the description as an imperative, lowercase, with no period at its end. $reword"

# Each commit, as its SHA and its count of lines, then the lines of its message.
commits=$(gh api --paginate "repos/$GH_REPO/pulls/$PR/commits?per_page=100" --jq '.[] |
    {sha, lines: (.commit.message | sub("\\s+$"; "") | split("\n"))} |
    "\(.sha) \(.lines | length)", .lines[]')
[ -n "$commits" ] || cannot_check 'GitHub lists none of its commits.'
while read -r sha count; do
    lines=()
    for ((i = 0; i < count; i++)); do IFS= read -r line && lines+=("$line"); done
    commit="\`${sha:0:7} ${lines[0]-}\`"
    header "Commit $commit" "${lines[0]-}"
done <<<"$commits"
report_finish
