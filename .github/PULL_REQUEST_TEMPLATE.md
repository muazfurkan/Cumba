## Summary

<!-- What does this change and why? Link related issues, e.g. "Closes #12". -->

## How to test

<!-- Steps a reviewer can follow to see the change working. -->

## Checklist

- [ ] Builds and tests pass locally
- [ ] `xcrun swift-format lint --strict --recursive Cumba CumbaTests` passes
- [ ] New user-facing strings are in `Localizable.xcstrings` with Turkish translations
- [ ] Features that make network requests are listed in the README privacy section
- [ ] `CHANGELOG.md` updated under "Unreleased"
- [ ] No secrets, tokens, personal paths or `Local.xcconfig` in the diff
- [ ] No code copied from other projects
