fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios verify

```sh
[bundle exec] fastlane ios verify
```

Clean, validate, test, build, and audit the iOS paid release

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Verify and upload a production-signed IPA to TestFlight

### ios genesis

```sh
[bundle exec] fastlane ios genesis
```

Build a locally signed Genesis IPA without profile sync or upload

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
