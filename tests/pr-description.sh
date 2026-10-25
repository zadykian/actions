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
