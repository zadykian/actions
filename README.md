# actions

The actions have moved to [zadykian/toolkit](https://github.com/zadykian/toolkit), under
`actions/NAME`. From v4.0.0 on, they are released with the skills at one version, and each
action's README there says how to use it.

## Versions

A workflow that pins `zadykian/actions/NAME@SHA` keeps working, as this repository keeps its code
and its tags, v1.0.0 and v2.0.0. To get the actions' changes from now on:

- pin `zadykian/toolkit/actions/NAME@SHA # vX.Y.Z` instead, and the skills' marketplace to the
  same tag. `tools/pin vX.Y.Z DIR`, run from a clone of the toolkit, moves both pins;
- have the `github-actions` update in `.github/dependabot.yml` ignore `zadykian/toolkit*`, as
  Dependabot would move the actions' hash but not the marketplace's ref.

The toolkit's README says how, in [Pin a release][pin].

[pin]: https://github.com/zadykian/toolkit#pin-a-release

## License

[MIT](LICENSE)
