#!/bin/bash
# Comments on pull request $PR why /ff did not move $MAIN: the refusal that fast-forward.sh left,
# or the run's failure where it left none.

set -euo pipefail

reason="$(cat "$RUNNER_TEMP/refusal" 2>/dev/null || echo 'The run failed.')"
run="$GITHUB_SERVER_URL/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID"
body="$(printf "\`/ff\` did not move %s: %s\n\n[The run](%s)" "$MAIN" "$reason" "$run")"
gh pr comment "$PR" --body "$body"
