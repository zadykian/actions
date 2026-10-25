# atomic-commits

Warns on a pull request whose commits break the rules of the [atomic-commits][skill] skill. It
never blocks the merge: it annotates the pull request, writes a job summary and keeps one comment
of its report up to date, and its job passes.

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
      - uses: zadykian/actions/atomic-commits@SHA # vX.Y.Z
```

Pin it by the full hash of a version tag's commit, as the repository's
[README](../README.md#versions) says. `pull-requests: write` lets it comment. It reads the pull
request through GitHub's API alone and checks out nothing, so it runs none of the pull request's
code.

## What it checks

Each finding names the commit and quotes what is wrong. It links to the rule's section of the
skill, and says how to fix it, with the skill's commands for rewording a commit.

Each commit's header, as [section 3][s3] sets it:

- `header`: the header is `type(scope)!: description`, its type one of `types` and its scope
  lowercase.
- `header-length`: the header is 72 characters at most.
- `description`: the description starts lowercase, and ends without a period.

## Inputs

- `token`, `${{ github.token }}` by default: reads the pull request, and comments on it.
- `comment`, `true` by default: `false` leaves the report to the annotations and the job summary.
- `types`, `feat fix refactor perf test docs style build ci chore revert` by default: the types
  that a header may take, separated by spaces.

## What it cannot check

It reads what GitHub's API says of the commits, and runs none of their code. So it cannot check
that each commit builds and passes the tests on its own, or that it holds one logical change, as
[the hard rules][rules] say. The review of each commit checks those.

[skill]: https://github.com/zadykian/skills/blob/main/skills/atomic-commits/SKILL.md
[rules]: https://github.com/zadykian/skills/blob/main/skills/atomic-commits/SKILL.md#hard-rules
[s3]: https://github.com/zadykian/skills/blob/main/skills/atomic-commits/SKILL.md#3-commit-messages-conventional-commits-100
