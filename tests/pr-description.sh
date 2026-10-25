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

clean=$'## Problem\n\nA check is missing.\n\n## Changes\n\n- Add it.'
changes=$'\n\n## Changes\n\n- Add it.'

describe passes-a-clean-description "$clean"
warnings 0
summarizes 'No findings remain'

describe passes-line-ends-of-a-browser "${clean//$'\n'/$'\r\n'}"
warnings 0

describe passes-a-closing-run $'## Problem ##\n\nA `<!--` within a line hides nothing.'"$changes"
warnings 0

describe warns-on-no-problem "${changes:2}"
warns "The description has no \`## Problem\` heading."
warnings 1

describe ignores-headings-in-code $'```md\n## Problem\n```\n~~~~\n## Problem\n~~~\n~~~~'"$changes"
warns "The description has no \`## Problem\` heading."
warnings 1

describe ignores-headings-in-comments $'<!--\n## Problem\n-->\n<!-- ## Problem -->'"$changes"
warns "The description has no \`## Problem\` heading."
warnings 1

describe warns-on-text-before-problem $'Adds a check.\n\n'"$clean"
warns "\`## Problem\`, line 3 of the description, is not its first section: \`Adds a check.\` comes"
warnings 1

describe warns-on-a-heading-before-problem $'# Add a check\n'"$clean"
warns "\`## Problem\`, line 2 of the description, is not its first section: \`# Add a check\` comes"

describe warns-on-a-template-of-comments $'## Problem\n\n<!-- What is wrong? -->'"$changes"
warns "\`## Problem\`, line 1 of the description, holds no prose."
warnings 1

describe warns-on-code-alone $'## Problem\n\n~~~\n# log\n~~~~'"$changes"
warns "\`## Problem\`, line 1 of the description, holds no prose."
warnings 1

problem=$'## Problem\n\nA check is missing.'

describe passes-bullets-of-each-marker "$problem"$'\n\n## Changes\n\n* A check.\n+ Its cases.'
warnings 0

describe warns-on-no-changes "$problem"
warns "The description has no \`## Changes\` heading."
warnings 1

describe warns-on-changes-before-problem "${changes:2}"$'\n\n'"$problem"
warns "\`## Changes\`, line 1 of the description, comes before \`## Problem\`, line 5."

describe warns-on-changes-without-bullets "$problem"$'\n\n## Changes\n\nAdds it.\n\n- - -'
warns "\`## Changes\`, line 5 of the description, holds no bullet: it opens \`Adds it.\`"
warnings 1

template=$'## Problem\n\n<!-- What is wrong? -->\n\n## Changes\n\n<!--\n- A change.\n-->'
describe warns-on-a-template-left-alone "$template"
warns "\`## Problem\`, line 1 of the description, holds no prose."
warns "\`## Changes\`, line 5 of the description, holds no bullet."
warnings 2

describe warns-on-another-heading "$clean"$'\n\n### Testing\n\nRan it.'
warns "The heading \`### Testing\`, line 9 of the description, is not one of \`## Problem\`,"
warnings 1

describe warns-on-a-setext-title $'Add a check\n===\n\n'"$clean"
warns "The heading \`Add a check\` over \`===\`, line 1 of the description, is not one of"
warns "is not its first section: \`Add a check\` comes before it."
warnings 2

describe warns-on-a-setext-heading "$clean"$'\n---\n\nA note\n---'
warns "The heading \`A note\` over \`---\`, line 10 of the description, is not one of"
warnings 1

describe warns-on-sections-out-of-order "$problem"$'\n\n## Stack\n\nPR 1 of 2.'"$changes"
warns "The heading \`## Changes\`, line 9 of the description, comes after \`## Stack\`: they go"
warnings 1

describe warns-on-a-repeated-section "$clean$changes"
warns "The heading \`## Changes\`, line 9 of the description, comes after \`## Changes\`"
warnings 1

describe ignores-headings-in-fences "$clean"$'\n\n```sh\n# Notes\n```\n\n~~~\nNotes\n---\n~~~'
warnings 0

stack=$'\n\n## Stack\n\nPR 2 of 2. Base: #41.'
describe passes-a-stacked-pull-request "$clean$stack" '{"base": {"ref": "feat-1"}}'
warnings 0

describe passes-a-default-branch-of-its-own "$clean" '{"base": {"ref": "trunk",
    "repo": {"default_branch": "trunk"}}}'
warnings 0

describe warns-on-a-stack-without-a-section "$clean" '{"base": {"ref": "feat-1"}}'
warns "#1 is into \`feat-1\`, not the default branch \`main\`, and its description has no"
warnings 1

describe warns-on-a-stack-without-its-place "$clean"$'\n\n## Stack\n\nBase: #41.'
warns "\`## Stack\`, line 9 of the description, does not say \`PR N of M\`: it opens \`Base: #41.\`"
warnings 1

footer=$'\n\nBREAKING CHANGE: the v1 inputs are gone.'
by=$'\n\n🤖 Generated with [Claude Code](https://claude.com/claude-code)'
describe passes-a-breaking-change "$clean$footer" '{"title": "feat(api)!: drop the v1 inputs"}'
warnings 0

describe passes-a-footer-and-an-attribution "$clean${footer/ /-}$by" '{"title": "feat!: drop it"}'
warnings 0

describe passes-an-attribution "$clean$by<!-- end -->" '{"title": "fix: keep it!"}'
warnings 0

describe warns-on-a-bang-without-a-footer "$clean" '{"title": "feat(api)!: drop the v1 inputs"}'
warns "The title \`feat(api)!: drop the v1 inputs\` has \`!\`, but the description does not end in"
warns "a \`BREAKING CHANGE:\` footer: it ends in \`- Add it.\`"
warnings 1

describe warns-on-text-after-the-footer "$clean$footer"$'\n\nThanks!' '{"title": "feat!: drop it"}'
warns "does not end in a \`BREAKING CHANGE:\` footer: it ends in \`Thanks!\`"
warnings 1

describe warns-on-a-footer-without-a-bang "$clean$footer"
warns "The description has a \`BREAKING CHANGE:\` footer, line 9, but the title"
warnings 1
