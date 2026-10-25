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

rule empty 'The description is empty' "$url" "Describe the pull request in the form that section \
6 sets. \`## Stack\` goes in a pull request of a stack alone, and the footer where the title has \
\`!\`.

$(template "$problem_md" "$changes_md" "$stack_md" "$footer_md")"

pull=$(gh api "repos/$GH_REPO/pulls/$PR")
# GitHub keeps the line ends that the browser sent, \r\n.
body=$(jq -r '.body // ""' <<<"$pull")
body=${body//$'\r'/}
[ -n "${body//[[:space:]]/}" ] || finding empty "The description of #$PR is empty."
report_finish
