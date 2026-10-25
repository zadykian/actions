#!/bin/bash
# Closes the issues of pull request $PR, which fast-forward.sh landed on the default branch: those
# its description closes, `Closes #N`, and those linked to it by hand. GitHub closes them after a
# merge of its own, but not after a push with GITHUB_TOKEN, as fast-forward.sh's is. As GitHub
# does, it closes them as completed. An issue it leaves open gets a warning.

set -euo pipefail

# leave warns that the issue $1 stays open, for the reason $2.
leave() {
    echo "::warning::$1 stays open: $2"
}

query="{ repository(owner: \"${GH_REPO%%/*}\", name: \"${GH_REPO#*/}\") {
    pullRequest(number: $PR) { closingIssuesReferences(first: 100) {
        nodes { number state repository { nameWithOwner } } } } } }"
issues="$(gh api graphql -f query="$query" --jq '.data.repository.pullRequest
    | .closingIssuesReferences.nodes[] | select(.state == "OPEN")
    | "\(.repository.nameWithOwner)#\(.number)"')"
for issue in $issues; do
    if [ "${issue%#*}" != "$GH_REPO" ]; then
        leave "$issue" "GITHUB_TOKEN may not close another repository's issues."
    elif ! gh api -X PATCH "repos/$GH_REPO/issues/${issue##*#}" -f state=closed \
        -f state_reason=completed >/dev/null; then
        leave "$issue" "GitHub refused to close it."
    fi
done
