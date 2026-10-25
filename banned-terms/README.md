# banned-terms

Warns on vague names and fillers, such as `helper`, `utils` and `simply`, in what a pull request
adds. The [banned-terms](https://github.com/zadykian/skills/blob/main/skills/banned-terms/SKILL.md)
skill teaches the agent to keep them out, and each finding links to it. The action never blocks the
merge: its job passes, whatever it finds.

## Usage

`.github/workflows/rules.yml`:

```yaml
name: rules

on:
  pull_request:
    types: [opened, edited, reopened, synchronize]

permissions: {}

jobs:
  rules:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    permissions:
      contents: read
      pull-requests: write
    steps:
      - uses: zadykian/actions/banned-terms@SHA # vX.Y.Z
```

The `edited` type checks the title and the description again once they change, and
`pull-requests: write` lets the action keep its comment. [Versions](../README.md#versions) says
which hash to pin.

## The terms

[terms.txt](terms.txt) is the source of the list, in the skill's order. Each line is a group of
terms, then a colon and the group's hint:

```text
helper, helpers: Names no responsibility: name what it does
util, utils, utility, utilities: Names no responsibility: name what it does
misc, miscellaneous: A grab bag: group by purpose
stuff, thing, things: Names nothing: name it
etc: An open list: name each item, or lead the examples with "such as"
various: Say which ones, or how many
simply, basically, obviously: Filler: delete it
```

Each group is a rule of the report: its title lists the terms, and its fix is the hint.

A term matches a token. A text splits into tokens at each character other than an ASCII letter or
digit, then before each hump of camelCase and PascalCase, and each token is lowercased. So
`HTTPHelper` gives `http` and `helper`, and `使用helper` gives `helper`.

- `StringHelper`, `str_utils.py` and `MiscStuff` match.
- `utilize`, `helpful`, `etcd` and `utils2` don't, as none of their tokens is a term.

A line gives one finding a term, even where it holds the term twice.

## What it reads

It reads the pull request through GitHub's API alone, and checks out nothing:

1. The lines that it adds, from each file's patch: code, comments and docs alike. A finding shows
   inline in Files changed, at the line's number on the new side.
2. The paths of the files that it adds or renames.
3. Its title and its description, line by line.
4. The message of each of its commits. A finding names the commit by its sha7 and subject.
