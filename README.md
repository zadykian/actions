# actions

Opinionated rules for agentic development, as GitHub Actions of two kinds:

- The checks warn on a pull request and never block. Each annotates the pull request, writes a job
  summary, and keeps one comment of its own up to date, and its job passes.
- `ff` lands a pull request by fast-forward on a `/ff` comment. Where it refuses, it fails, with a
  comment that says why.

The skills in [zadykian/skills](https://github.com/zadykian/skills) teach the agent the same rules.

## The actions

| Action | What it does |
| --- | --- |
| [`ff`](ff/README.md) | Lands a pull request by fast-forward on a `/ff` comment |

## Usage

The checks run in one workflow, `.github/workflows/rules.yml`, with a step for each:

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
      - uses: zadykian/actions/NAME@SHA # vX.Y.Z
```

[Versions](#versions) says which hash to pin. The `edited` type checks the title and the
description again once they change. Each check reads the pull request through GitHub's API
alone, so the job checks out nothing and runs none of its code. `pull-requests: write` lets it
comment.

`ff` runs in a workflow of its own, on a comment: [its README](ff/README.md#usage) gives it, with
the permissions it needs.

Each action's README, in its directory, says what it does. A check's README also gives its inputs
and the rules it links to.

## Versions

One version covers every action: a tag `vX.Y.Z` on `main`, which no file repeats. Pin an action
by the full hash of the tag's commit, `git rev-parse vX.Y.Z^{commit}`, with the tag in the
comment: `zadykian/actions/NAME@SHA # vX.Y.Z`. Dependabot's `github-actions` updates move the
hash and the comment to each new tag.

The Conventional Commits since the previous tag set the next version:

- a breaking change, a `!` in the header or a `BREAKING CHANGE:` footer, bumps the major, or the
  minor before 1.0;
- a `feat` bumps the minor, and any other commit the patch.

Each tag gets a GitHub Release, whose notes list those commits: breaking changes, features, fixes
and the rest. A released tag is never moved or deleted, and no major tag, such as `v1`, follows
the releases.

## License

[MIT](LICENSE)
