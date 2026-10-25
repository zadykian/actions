#!/bin/bash
# Warns where the commits of pull request $PR of $GH_REPO break the rules of the atomic-commits
# skill. TYPES, MAX_COMMIT_LINES, MAX_PR_LINES and EXCLUDE hold the inputs that action.yml
# describes.

set -euo pipefail
# A $(...) fails as its command fails. A length counts characters, not bytes.
shopt -s inherit_errexit
export LC_ALL=C.UTF-8
# shellcheck source=lib/report.sh
. "$GITHUB_ACTION_PATH/../lib/report.sh"
# shellcheck source=lib/glob.sh
. "$GITHUB_ACTION_PATH/../lib/glob.sh"

# changed prints the lines changed in the files that the gh api path $1 lists, as the jq filter $2
# gives them, out of the files that EXCLUDE matches.
changed() {
    local files count path sum=0
    files=$(gh api --paginate "$1" --jq "$2 | \"\\(.additions + .deletions)\\t\\(.filename)\"")
    while IFS=$'\t' read -r count path; do
        [ -z "$path" ] || excluded "$path" || sum=$((sum + count))
    done <<<"$files"
    echo "$sum"
}

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

# trailers prints the index of the first trailer among the message lines $@, or $# where they end
# in none. As git reads them, the trailers are the last paragraph, other than the header's, where
# each line is `Token: value` or continues the line before it.
trailers() {
    local lines=("$@") start=$# i
    while [ "$start" -gt 2 ] && [ -n "${lines[start - 1]//[[:space:]]/}" ]; do
        start=$((start - 1))
    done
    { [ "$start" -gt 1 ] && [ -z "${lines[start - 1]//[[:space:]]/}" ]; } || start=$#
    for ((i = start; i < $#; i++)); do
        [[ ${lines[i]} =~ ^[[:alnum:]-]+[[:blank:]]*: ]] ||
            { [ "$i" -gt "$start" ] && [[ ${lines[i]} =~ ^[[:blank:]] ]]; } || start=$#
    done
    echo "$start"
}

# message records the findings of the body and the footers of the commit $1, whose message has
# the lines $2...
message() {
    local lines=("${@:2}") start i bang=false footer=false refs=false
    start=$(trailers "${lines[@]}")
    if [ $# -gt 2 ] && [ -n "${lines[1]//[[:space:]]/}" ]; then
        finding body-blank "Commit $1: line 2 is \`${lines[1]}\`, not blank."
    fi
    for ((i = 1; i < start; i++)); do
        [ "${#lines[i]}" -le 72 ] || [[ ${lines[i]} == *://* ]] || finding body-width \
            "Commit $1: line $((i + 1)) is ${#lines[i]} characters long: \`${lines[i]}\`."
    done
    [[ ${lines[0]%%: *} != *! ]] || bang=true
    for ((i = 1; i < $# - 1; i++)); do
        [[ ${lines[i]} != BREAKING[\ -]CHANGE:* ]] || footer=true
        [ "$i" -lt "$start" ] || [[ ! ${lines[i],,} =~ ^refs[[:blank:]]*: ]] || refs=true
    done
    if $bang && ! $footer; then
        finding breaking "Commit $1: the header has \`!\`, but no \`BREAKING CHANGE:\` footer."
    elif $footer && ! $bang; then
        finding breaking "Commit $1: a \`BREAKING CHANGE:\` footer, but no \`!\` in the header."
    fi
    if [[ ${lines[0]%%[:(!]*} == revert ]] && ! $refs; then
        finding revert "Commit $1: no \`Refs:\` footer names the reverted commit."
    fi
}

report_start atomic-commits
skill=https://github.com/zadykian/skills/blob/main/skills/atomic-commits/SKILL.md
pull=$(gh api "repos/$GH_REPO/pulls/$PR" --jq '"\(.base.ref) \(.commits // 0)"')
read -r base total <<<"$pull"
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
rule body-blank 'Line 2 of the message is not blank' "$messages" \
    "Leave line 2 blank, between the header and the body. $reword"
rule body-width 'A line of the body is over 72 characters' "$messages" "Wrap the body at 72 \
characters. A trailer, such as \`Co-Authored-By:\`, and a line that holds a URL may be longer. \
$reword"
rule breaking 'A breaking change lacks its ! or its footer' "$messages" "Mark a breaking change \
both ways: a \`!\` before the header's colon, and a footer \`BREAKING CHANGE: <what changed and \
what callers must do>\`. Where nothing breaks, drop both. $reword"
rule revert 'A revert has no Refs footer' "$messages" \
    "End the message with a footer \`Refs: <sha>\`, the reverted commit's. $reword"
rule fixup 'A fixup or WIP commit' "$skill#2-shape-each-commit" "Fold it into the commit it \
belongs to. A \`fixup!\`, \`squash!\` or \`amend!\` commit squashes in with \
\`GIT_SEQUENCE_EDITOR=: git rebase -i --autosquash --update-refs $base\`. Reword a WIP commit \
into a \`fixup!\` of that commit first. $reword"
rule merge 'A merge commit' "$skill#6-stack-mechanics-git--238" "Rebase the branch onto \
\`$base\` instead of merging it in, which drops the merge commits: \`git fetch origin && git \
rebase --update-refs origin/$base\`. Then push it with \`git push --force-with-lease\`."
rule commit-count 'More commits than GitHub lists' "$skill#5-choose-pr-boundaries" \
    "Split the pull request into a stack of smaller ones, as sections 5 and 6 of the skill say."
rule commit-size "A commit is over $MAX_COMMIT_LINES changed lines" "$skill#hard-rules" "Split it \
into commits of one logical change each, of $MAX_COMMIT_LINES changed lines at most. A purely \
mechanical commit, such as a rename, a move, formatting or regenerated code, may be larger where \
its body says so: \`mechanical\`. $reword"
rule pr-size "The pull request is over $MAX_PR_LINES changed lines" "$skill#hard-rules" "Split it \
into a stack of pull requests, each of $MAX_PR_LINES changed lines at most against its own base. \
Section 5 of the skill says where to cut it, and section 6 how to stack the branches."

# Each commit, as its SHA and its counts of parents and lines, then the lines of its message.
commits=$(gh api --paginate "repos/$GH_REPO/pulls/$PR/commits?per_page=100" --jq '.[] | {sha,
    parents: (.parents | length), lines: (.commit.message | sub("\\s+$"; "") | split("\n"))} |
    "\(.sha) \(.parents) \(.lines | length)", .lines[]')
[ -n "$commits" ] || cannot_check 'GitHub lists none of its commits.'
# A commit to fold in or rebase away gets that finding alone.
temporary='^((fixup|squash|amend)!|wip([^[:alnum:]]|$))'
listed=0
while read -r sha parents count; do
    lines=()
    for ((i = 0; i < count; i++)); do IFS= read -r line && lines+=("$line"); done
    commit="\`${sha:0:7} ${lines[0]-}\`"
    listed=$((listed + 1))
    if [ "$parents" -gt 1 ]; then
        finding merge "Commit $commit is a merge commit, of $parents parents."
    elif [[ ${lines[0],,} =~ $temporary ]]; then
        finding fixup "Commit $commit is temporary: its header starts \`${lines[0]%% *}\`."
    else
        header "Commit $commit" "${lines[0]-}"
        message "$commit" "${lines[@]}"
        size=0 body=${lines[*]:1}
        [[ ${body,,} == *mechanical* ]] ||
            size=$(changed "repos/$GH_REPO/commits/$sha?per_page=100" '.files[]')
        [ "$size" -le "$MAX_COMMIT_LINES" ] || finding commit-size \
            "Commit $commit changes $size lines, and its body does not say \`mechanical\`."
    fi
done <<<"$commits"
# GitHub lists 250 commits of a pull request at most.
[ "$total" -le "$listed" ] || finding commit-count "#$PR has $total commits, and GitHub lists the \
first $listed alone: the check skipped the other $((total - listed))."
size=$(changed "repos/$GH_REPO/pulls/$PR/files?per_page=100" '.[]')
[ "$size" -le "$MAX_PR_LINES" ] || finding pr-size "#$PR changes $size lines against \`$base\`."
report_finish
