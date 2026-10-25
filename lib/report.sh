# shellcheck shell=bash
# The report of an action's check.sh, which sources it: its findings, as annotations on the pull
# request. Sourcing it defines functions and sets the report_ variables, and runs nothing.
#
#   report_start NAME                  starts the report of the action NAME
#   rule KEY TITLE URL FIX             declares the rule KEY
#   finding KEY MESSAGE [FILE [LINE]]  records a finding of the rule KEY
#   report_finish                      reports the findings, and exits 0
#
# TITLE is a line of text, URL the rule's section of the skill, and FIX how to fix a finding, in
# Markdown. MESSAGE says where and what is wrong, quoting it. FILE is a path from the repository's
# root, and LINE a line of its new side: with both, the annotation shows in Files changed.
#
# report_finish prints a ::warning for each of the first findings, 10 at most, as GitHub shows 10
# a step. The last says how many more are not annotated.
#
# The rules by index: their keys, titles, links and fixes.
report_keys=() report_titles=() report_urls=() report_fixes=()
# The findings by index: their rules' indices, messages, files and lines.
report_rules=() report_messages=() report_files=() report_lines=()
report_name=''

# report_start starts the report of the action $1.
report_start() {
    report_name=$1
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
    echo "report.sh: no rule $1 is declared" >&2
    return 1
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
            message+=$'\n'"$(report_plural $((count - $1)) 'more finding') not annotated."
        fi
        properties="title=$(report_escape "$report_name: ${report_titles[rule]}" property)"
        if [ -n "${report_files[i]}" ]; then
            properties+=",file=$(report_escape "${report_files[i]}" property)"
            [ -z "${report_lines[i]}" ] || properties+=",line=${report_lines[i]}"
        fi
        printf '::warning %s::%s\n' "$properties" "$(report_escape "$message")"
    done
}

# report_finish reports the findings, and exits 0.
report_finish() {
    report_annotate 10
    exit 0
}
