# shellcheck shell=bash
# The report of an action's check.sh, which sources it: its findings, as annotations on the pull
# request and a job summary. Sourcing it defines functions and sets the report_ variables, and runs
# nothing.
#
#   report_start NAME                  starts the report of the action NAME
#   rule KEY TITLE URL FIX             declares the rule KEY
#   finding KEY MESSAGE [FILE [LINE]]  records a finding of the rule KEY
#   report_finish                      reports the findings, and exits 0
#   cannot_check REASON                warns that the check could not run, and exits 0
#
# report_start reads GH_REPO, owner/name, and PR, the pull request's number: where PR is empty,
# as on another event than pull_request, it warns and exits 0. It then traps errors, so that a
# check runs under set -euo pipefail and never fails the job: an error ends it in one warning,
# `NAME could not check #PR: REASON`, and the status 0.
#
# TITLE is a line of text, URL the rule's section of the skill, and FIX how to fix a finding, in
# Markdown. MESSAGE says where and what is wrong, quoting it. FILE is a path from the repository's
# root, and LINE a line of its new side: with both, the annotation shows in Files changed.
#
# report_finish reads the SHA of the pull request's head, then:
#
# - writes the report to $GITHUB_STEP_SUMMARY. It opens with "This check warns and does not block
#   the merge", then gives each rule with findings a section: its title, link, findings and fix;
# - prints a ::warning for each of the first findings, 10 at most, as GitHub shows 10 a step. The
#   last says how many more the summary holds.
#
# A check.sh, for one rule:
#
#   #!/bin/bash
#   set -euo pipefail
#   # shellcheck source=lib/report.sh
#   . "$GITHUB_ACTION_PATH/../lib/report.sh"
#   report_start pr-description
#   rule empty 'The description is empty' "$SKILL#6-stack-mechanics-git--238" \
#       "Describe the change under \`## Problem\` and \`## Changes\`."
#   body=$(gh api "repos/$GH_REPO/pulls/$PR" --jq .body)
#   [ -n "${body//[[:space:]]/}" ] || finding empty "The description of #$PR is empty."
#   report_finish

# The rules by index: their keys, titles, links and fixes.
report_keys=() report_titles=() report_urls=() report_fixes=()
# The findings by index: their rules' indices, messages, files and lines.
report_rules=() report_messages=() report_files=() report_lines=()
report_name='' report_error=''

# report_start starts the report of the action $1, on the pull request $PR.
report_start() {
    report_name=$1
    if [ -z "${PR-}" ]; then
        echo "::warning::$1 checks a pull request, and the ${GITHUB_EVENT_NAME-} event has none:" \
            "run it on pull_request."
        exit 0
    fi
    set -E
    trap 'report_error="${BASH_SOURCE[0]##*/}:$LINENO: $BASH_COMMAND exited with $?"' ERR
    trap 'report_exit $?' EXIT
}

# cannot_check warns that the check could not run, for the reason $1, and exits 0.
cannot_check() {
    printf '::warning::%s could not check #%s: %s\n' "$report_name" "${PR-}" "$(report_escape "$1")"
    exit 0
}

# report_exit turns the check's exit with the status $1, other than 0, into a warning and the
# status 0.
report_exit() {
    [ "$1" = 0 ] || cannot_check "${report_error:-the check exited with $1}"
}

# rule declares the rule $1, titled $2, which the skill's section at the URL $3 sets, and whose
# findings the Markdown $4 says how to fix.
rule() {
    report_keys+=("$1") report_titles+=("$2") report_urls+=("$3") report_fixes+=("$4")
}

# finding records the finding $2 of the rule $1, at the file $3 and its line $4 where given.
finding() {
    local i
    for i in "${!report_keys[@]}"; do
        [ "${report_keys[i]}" = "$1" ] || continue
        report_rules+=("$i") report_messages+=("$2") report_files+=("${3-}") report_lines+=("${4-}")
        return 0
    done
    cannot_check "no rule $1 is declared, for the finding: $2"
}

# report_plural prints the count $1 of the noun $2: 1 finding, or 2 findings.
report_plural() {
    if [ "$1" = 1 ]; then printf '1 %s' "$2"; else printf '%s %ss' "$1" "$2"; fi
}

# report_escape prints the text $1 escaped as a workflow command's message, or as a property
# where $2 is set.
report_escape() {
    local text=${1//'%'/%25}
    text=${text//$'\r'/%0D}
    text=${text//$'\n'/%0A}
    [ -z "${2-}" ] || text=${text//:/%3A} text=${text//,/%2C}
    printf '%s' "$text"
}

# report_annotate prints a ::warning for each of the first $1 findings. The last says how many
# more there are.
report_annotate() {
    local count=${#report_messages[@]} i rule message properties
    for ((i = 0; i < count && i < $1; i++)); do
        rule=${report_rules[i]}
        message="${report_messages[i]}"$'\n'"The rule: ${report_urls[rule]}"
        if [ $((i + 1)) = "$1" ] && [ "$count" -gt "$1" ]; then
            message+=$'\n'"The job summary holds $(report_plural $((count - $1)) 'more finding')."
        fi
        properties="title=$(report_escape "$report_name: ${report_titles[rule]}" property)"
        if [ -n "${report_files[i]}" ]; then
            properties+=",file=$(report_escape "${report_files[i]}" property)"
            [ -z "${report_lines[i]}" ] || properties+=",line=${report_lines[i]}"
        fi
        printf '::warning %s::%s\n' "$properties" "$(report_escape "$message")"
    done
}

# report_text prints the report in Markdown, as of the head commit $1.
report_text() {
    local count=${#report_messages[@]} i j at found
    printf '### %s\n\nThis check warns and does not block the merge. ' "$report_name"
    if [ "$count" = 0 ]; then
        printf "No findings remain as of \`%s\`.\n" "$1"
        return
    fi
    printf "It found %s as of \`%s\`.\n" "$(report_plural "$count" finding)" "$1"
    for i in "${!report_keys[@]}"; do
        found=''
        for j in "${!report_messages[@]}"; do
            [ "${report_rules[j]}" = "$i" ] || continue
            at=${report_files[j]}${report_lines[j]:+:${report_lines[j]}}
            found+="- ${at:+\`$at\`: }${report_messages[j]//$'\n'/$'\n'  }"$'\n'
        done
        [ -z "$found" ] || printf '\n#### %s\n\nThe rule: %s\n\n%s\nHow to fix it:\n\n%s\n' \
            "${report_titles[i]}" "${report_urls[i]}" "$found" "${report_fixes[i]}"
    done
}

# report_finish reports the findings, and exits 0.
report_finish() {
    local head report
    head=$(gh api "repos/$GH_REPO/pulls/$PR" --jq .head.sha)
    report=$(report_text "${head:0:7}")
    printf '%s\n' "$report" >>"${GITHUB_STEP_SUMMARY:-/dev/stdout}"
    report_annotate 10
    exit 0
}
