# actions

Opinionated rules for agentic development, checked on every pull request.

- The skills in [zadykian/skills](https://github.com/zadykian/skills) teach the agent the rules.
- These actions check each pull request against them in CI.
- Each action warns and never blocks. It annotates the pull request, writes a job summary, and
  keeps one comment of its own up to date, and its job passes.

## Usage

`.github/workflows/rules.yml`, with a step for each action:

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

Pin each action by a commit's hash, the release's tag in the comment. One tag covers every action.
The `edited` type checks the title and the description again once they change. Each action reads
the pull request through GitHub's API alone, so the job checks out nothing and runs none of its
code. `pull-requests: write` lets it comment.

Each action's README, in its directory, says what it checks, its inputs, and the rules it links to.

## License

[MIT](LICENSE)
