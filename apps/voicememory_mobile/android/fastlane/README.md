fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## Android

### android verify

```sh
[bundle exec] fastlane android verify
```

Clean, validate, test, and audit the Android paid release configuration

### android internal

```sh
[bundle exec] fastlane android internal
```

Verify and upload a production-signed AAB to Play Internal

### android genesis

```sh
[bundle exec] fastlane android genesis
```

Build locally signed Genesis APK and AAB without upload actions

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
