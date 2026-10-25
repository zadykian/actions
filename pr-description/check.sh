#!/bin/bash
# Warns where the description of pull request $PR of $GH_REPO strays from the form that
# atomic-commits §6 sets. It reads the pull request with $GH_TOKEN, and lib/report.sh reports the
# findings.

set -euo pipefail

# shellcheck source=lib/report.sh
. "$GITHUB_ACTION_PATH/../lib/report.sh"
report_start pr-description

skill=https://github.com/zadykian/skills/blob/main/skills/atomic-commits/SKILL.md
url=$skill#6-stack-mechanics-git--238
# The form of a description, as section 6 shows it, in the parts that the fixes quote.
problem_md='## Problem

What is wrong or missing today, and why it matters: one to three sentences. Closes #12.'
changes_md='## Changes

- One bullet per high-level change, said by behavior, not by file.'
stack_md='## Stack

PR 2 of 3. Base: #41. Next: feat(checkout): retry failed gateway calls.'
footer_md='BREAKING CHANGE: what changed, and what callers must do.'

# template prints the parts $1, $2... of the form as a Markdown code block.
template() {
    local text
    text=$(printf '%s\n\n' "$@")
    printf '~~~markdown\n%s\n~~~' "$text"
}

# quote prints the text $1 as a Markdown code span, without its outer blanks, cut to 60 characters.
quote() {
    local text=$1
    text=${text#"${text%%[![:blank:]]*}"} text=${text%"${text##*[![:blank:]]}"}
    [ "${#text}" -le 60 ] || text="${text:0:59}…"
    if [[ $text == *"\`"* ]]; then printf "\`\` %s \`\`" "$text"; else printf "\`%s\`" "$text"; fi
}

# words prints the count of words in the text $1: runs of characters between spaces, other than
# those of ASCII punctuation alone, such as a bullet's - or a heading's ##.
words() {
    { LC_ALL=C grep -o '[^[:space:]]*[^[:space:][:punct:]][^[:space:]]*' <<<"$1" || true; } | wc -l
}

# heading records a heading from the line $1 to the line $2, of the level $3 and the text $4, as
# the Markdown $5 quotes it.
heading() {
    h_starts+=("$1") h_ends+=("$2") h_levels+=("$3") h_texts+=("${4%"${4##*[![:blank:]]}"}")
    h_quotes+=("$5")
}

# first prints the index of the first heading `## $1`, or -1.
first() {
    local i
    for i in "${!h_texts[@]}"; do
        [ "${h_levels[i]} ${h_texts[i]}" != "2 $1" ] || { echo "$i" && return; }
    done
    echo -1
}

# section prints the text lines of the heading $1's section, up to the next heading.
section() {
    local i end=${#kinds[@]}
    [ "$1" = $((${#h_starts[@]} - 1)) ] || end=${h_starts[$1 + 1]}
    for ((i = h_ends[$1] + 1; i < end; i++)); do
        [ "${kinds[i]}" != text ] || printf '%s\n' "${texts[i]}"
    done
}

rule empty 'The description is empty' "$url" "Describe the pull request in the form that section \
6 sets. \`## Stack\` goes in a pull request of a stack alone, and the footer where the title has \
\`!\`.

$(template "$problem_md" "$changes_md" "$stack_md" "$footer_md")"

pull=$(gh api "repos/$GH_REPO/pulls/$PR")
# GitHub keeps the line ends that the browser sent, \r\n.
body=$(jq -r '.body // ""' <<<"$pull")
body=${body//$'\r'/}
if [ -z "${body//[[:space:]]/}" ]; then
    finding empty "The description of #$PR is empty."
    report_finish
fi

# The description's lines from 0, as Markdown reads them: kinds[i] is text, code or heading, and
# texts[i] the line without its HTML comments. A comment that opens a line hides the lines up to
# its end, as an HTML block does; one within a line hides itself alone.
kinds=() texts=() fence='' hidden=false para=-1
# The headings by index: their first and last lines, levels, texts, and quotes of their source.
h_starts=() h_ends=() h_levels=() h_texts=() h_quotes=()
opener="^ {0,3}((\`{3,})[^\`]*|(~{3,}).*)\$" closer="^ {0,3}(\`{3,}|~{3,})[[:blank:]]*\$"
atx='^ {0,3}(#{1,6})([[:blank:]]+(.*))?$'
closing='^((.*[^[:blank:]])[[:blank:]]+)?#+[[:blank:]]*$'
# A setext heading underlines a paragraph, but not a list item or a quote: there, a line of
# dashes is a thematic break.
setext='^ {0,3}(=+|-+)[[:blank:]]*$' item='^ {0,3}(>|([-*+]|[0-9]{1,9}[.)])([[:blank:]]|$))'
while IFS= read -r line; do
    if [ -n "$fence" ] || { ! $hidden && [[ $line =~ $opener ]]; }; then
        if [ -z "$fence" ]; then
            fence=${BASH_REMATCH[2]}${BASH_REMATCH[3]}
        elif [[ $line =~ $closer && ${BASH_REMATCH[1]} == "$fence"* ]]; then
            fence=''
        fi
        kinds+=(code) texts+=("$line") para=-1
        continue
    fi
    visible='' rest=$line
    while :; do
        if $hidden; then
            [[ $rest == *'-->'* ]] || break
            rest=${rest#*'-->'} hidden=false
        elif [[ $rest == *'<!--'*'-->'* ]]; then
            visible+=${rest%%'<!--'*} rest=${rest#*'<!--'} rest=${rest#*'-->'}
        else
            if [[ $rest != *'<!--'* || "$visible${rest%%'<!--'*}" == *[![:blank:]]* ]]; then
                visible+=$rest
            else
                hidden=true
            fi
            break
        fi
    done
    texts+=("$visible") n=${#kinds[@]}
    if [[ $visible =~ $atx ]]; then
        # A closing run of #, as in `## Problem ##`, is no part of the text.
        level=${#BASH_REMATCH[1]} text=${BASH_REMATCH[3]}
        [[ ! $text =~ $closing ]] || text=${BASH_REMATCH[2]}
        heading "$n" "$n" "$level" "$text" "$(quote "$visible")"
        kinds+=(heading) para=-1
    elif [ "$para" != -1 ] && [[ $visible =~ $setext && ! ${texts[para]} =~ $item ]]; then
        level=1
        [[ $visible != *-* ]] || level=2
        text=$(printf '%s ' "${texts[@]:para:n-para}")
        text=${text#"${text%%[![:blank:]]*}"}
        heading "$para" "$n" "$level" "$text" "$(quote "$text") over $(quote "$visible")"
        for ((i = para; i <= n; i++)); do kinds[i]=heading; done
        para=-1
    else
        kinds+=(text)
        # The first line of the paragraph that this line is in, or -1 for a blank line.
        if [ -z "${visible//[[:blank:]]/}" ]; then para=-1; elif [ "$para" = -1 ]; then para=$n; fi
    fi
done <<<"$body"

rule problem 'The description does not open with a Problem section in prose' "$url" "Open the \
description with \`## Problem\`: one to three sentences on what is wrong or missing today, and \
why it matters. An HTML comment holds no prose.

$(template "$problem_md")"
p=$(first Problem)
if [ "$p" = -1 ]; then
    finding problem "The description has no \`## Problem\` heading."
else
    at="\`## Problem\`, line $((h_starts[p] + 1)) of the description,"
    before=''
    for ((i = 0; i < h_starts[p]; i++)); do
        if [ "${kinds[i]}" = code ] || (($(words "${texts[i]}"))); then
            before=$(quote "${texts[i]}") && break
        fi
    done
    [ -z "$before" ] || finding problem "$at is not its first section: $before comes before it."
    (($(words "$(section "$p")"))) || finding problem "$at holds no prose."
fi

rule changes 'The description has no Changes section of bullets after Problem' "$url" "Follow \
\`## Problem\` with \`## Changes\`: a bullet for each high-level change, said by behavior, not \
by file.

$(template "$changes_md")"
c=$(first Changes)
if [ "$c" = -1 ]; then
    finding changes "The description has no \`## Changes\` heading."
else
    at="\`## Changes\`, line $((h_starts[c] + 1)) of the description,"
    [ "$p" = -1 ] || [ "$c" -gt "$p" ] ||
        finding changes "$at comes before \`## Problem\`, line $((h_starts[p] + 1))."
    # A bullet holds text, which a thematic break, such as - - -, lacks.
    bullet='^[[:blank:]]*[-*+][[:blank:]]+[^[:blank:]]' content='[^-*[:blank:]]'
    bullets=0 opening=''
    while IFS= read -r line; do
        [ -n "$opening" ] || [ -z "${line//[[:blank:]]/}" ] || opening=$(quote "$line")
        [[ ! $line =~ $bullet || ! $line =~ $content ]] || bullets=$((bullets + 1))
    done <<<"$(section "$c")"
    [ "$bullets" != 0 ] || finding changes "$at holds no bullet${opening:+: it opens $opening}."
fi

rule sections 'The description has a heading other than the three, or out of order' "$url" "Keep \
to these headings, at level 2 and in this order, each once: fold any other into them. A heading \
in a code block is no heading.

$(template "$problem_md" "$changes_md" "$stack_md")"
names=(Problem Changes Stack) last=-1
for i in "${!h_texts[@]}"; do
    at="The heading ${h_quotes[i]}, line $((h_starts[i] + 1)) of the description,"
    k=-1
    for j in 0 1 2; do [ "${h_levels[i]} ${h_texts[i]}" != "2 ${names[j]}" ] || k=$j; done
    if [ "$k" = -1 ]; then
        finding sections "$at is not one of \`## Problem\`, \`## Changes\` and \`## Stack\`."
    elif [ "$k" -le "$last" ]; then
        finding sections "$at comes after \`## ${names[last]}\`: they go Problem, Changes, Stack,\
 each once."
    else
        last=$k
    fi
done
report_finish
