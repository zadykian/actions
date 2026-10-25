# pr-description

Warns on a pull request whose description strays from the compact form that
[atomic-commits §6][section] sets: the problem it solves, then its high-level changes. It never
blocks the merge: it annotates the pull request, writes a job summary, keeps one comment of its
own up to date, and its job passes, findings or not.

## The format

```markdown
## Problem

What is wrong or missing today, and why it matters: one to three sentences. Closes #12.

## Changes

- One bullet per high-level change, said by behavior, not by file.

## Stack

PR 2 of 3. Base: #41. Next: feat(checkout): retry failed gateway calls.

BREAKING CHANGE: what changed, and what callers must do.
```

`## Stack` goes in each pull request of a stack, and the `BREAKING CHANGE:` footer where the
title has `!`. An attribution line, such as `🤖 Generated with [Claude Code](...)`, may end the
description.

## Rules

Each rule links to [section 6][section]. Its finding quotes the heading or the text at fault, and
its fix shows the form. A heading may be an ATX one, as `# Title`, or a setext one, a line
underlined with `===` or `---`. A heading in a fenced code block or an HTML comment is none, and
an HTML comment or a code block is no prose: a template's comments, left alone, are no
description.

| Key | Finding when |
| --- | --- |
| `empty` | The description is empty, or blank |
| `problem` | `## Problem` is missing, has text or a heading before it, or holds no prose |
| `changes` | `## Changes` is missing, comes before Problem, or holds no bullet |
| `sections` | A heading other than the three, at any level, or one out of order or repeated |
| `stack` | Into a branch other than the default, with no `## Stack`; or Stack lacks `PR N of M` |
| `breaking` | The title has `!`, but no `BREAKING CHANGE:` footer ends the body; or vice versa |

## Inputs

| Input | Default | What it sets |
| --- | --- | --- |
| `token` | `${{ github.token }}` | The token that reads the pull request and comments on it |
| `comment` | `true` | `true` keeps one comment of the report on the pull request |

## Usage

```yaml
on:
  pull_request:
    types: [opened, edited, reopened, synchronize]

permissions: {}

jobs:
  pr-description:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    permissions:
      pull-requests: write
    steps:
      - uses: zadykian/actions/pr-description@SHA # vX.Y.Z
```

The `edited` type checks the description again once it changes. `pull-requests: write` lets the
action comment. It reads the pull request through GitHub's API alone, so the job checks out
nothing.

[section]: https://github.com/zadykian/skills/blob/main/skills/atomic-commits/SKILL.md#6-stack-mechanics-git--238
