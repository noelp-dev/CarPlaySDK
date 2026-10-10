# NativePHP submission dossier

This document is ready to use as listing/review material. The source is published at [github.com/noelp-dev/CarPlaySDK](https://github.com/noelp-dev/CarPlaySDK) on `main` without a tag. Packagist registration and NativePHP marketplace submission have not happened. Resolve the outstanding [host/device release gates](VERIFICATION.md) before presenting this candidate as production-ready.

## Suggested listing

**Name:** CarPlay & Android Auto

**Composer package:** `noelp-dev/carplay-sdk`

**Target repository:** [noelp-dev/CarPlaySDK](https://github.com/noelp-dev/CarPlaySDK)

**Documentation URL:** [README](https://github.com/noelp-dev/CarPlaySDK#readme)

**Support URL:** [GitHub issues](https://github.com/noelp-dev/CarPlaySDK/issues)

**License:** MIT

**Platforms:** iOS / Android

**Framework target:** NativePHP Mobile 4.x

**Short description:** Native in-car templates for Apple CarPlay and Kotlin Android Auto, with one PHP API, native cached startup and acknowledged interaction events.

**Long description:**

Build an in-car experience from PHP using native lists, grids, information screens, search, tabs and geographic points of interest. The plugin renders Swift CarPlay templates and runs an Android Auto CarAppService in Kotlin. It includes native stack navigation, supported in-place updates, navigation handoff, capability negotiation and an atomic event queue so interactions can be processed after the handset interface resumes. CarPlay category configuration and Android service registration integrate with NativePHP's plugin build system. A Laravel facade, JS/TypeScript client, examples and test documentation are included.

This release targets POI-style Android Auto apps and approved CarPlay parking, charging, quick food ordering or audio categories. Platform-specific features and category gates are explicit. Navigation routing, audio playback, communication and Android Automotive distribution are separate integrations; Now Playing support is presentation only.

## Maintainer review note

**Proposed review title:** Add a native CarPlay and Android Auto template/event bridge for NativePHP Mobile

**Problem:** A PHP application cannot draw its ordinary phone interface into CarPlay or Android Auto. The car may also start before the phone UI or PHP runtime is available. A useful bridge must own its car scenes/services and preserve native content and interactions across that lifecycle.

**Implementation:** This package contributes 14 mapped bridge functions, Swift templates/scene delegates, Kotlin CarAppService/Session/Screen implementations, root persistence and bounded acknowledged events. PHP/Swift/Kotlin validate one wire contract. UI commands report asynchronous completion rather than blocking a host callback on PHP. iOS category/entitlement selection uses a post-compilation hook; Android's service defaults to POI and validates release hosts.

**Validation:** Composer/manifest checks, the upstream NativePHP manifest parser, 131 PHP checks, 9 transport checks, 3 JS tests, 76 shared contract cases on both native languages, Swift queue persistence tests and both native SDK compilation checks pass. Full signed NativePHP app integration, CarPlay Simulator, DHU and real-vehicle tests are still outstanding.

**Review focus:** confirm host lifecycle compatibility with the target NativePHP release, build-hook ordering, cached startup before PHP, event dispatch behavior for the chosen host renderer, and real host task/category constraints. Please treat the package as a review candidate until those gates pass.

## Delivery contents

- Composer package metadata, MIT license, attribution and change log.
- Manifest, PHP facade/value builders/configuration and build hook.
- Swift and Kotlin source implementations.
- JS/TypeScript client and example parking experience.
- API, setup, architecture, support matrix and primary-source research.
- Shared fixtures, compiler harness, local check scripts and CI workflow.
- Honest verification record distinguishing executed and pending checks.

## Publication steps

1. Done: `noelp-dev/carplay-sdk` is published to [noelp-dev/CarPlaySDK](https://github.com/noelp-dev/CarPlaySDK). Composer metadata and listing use that owner; the existing PHP and Kotlin namespaces remain stable. It installs from `dev-main` through a VCS repository.
2. The included CI runs in that repository (PHP/JS, Swift and Kotlin jobs; see [verification](VERIFICATION.md)). Still open: complete and record the signed app/simulator/DHU acceptance cases.
3. Create a versioned review/stable tag according to the actual verification status, then register the public Composer package with Packagist if public distribution is intended.
4. Sign in through NativePHP's [developer onboarding](https://nativephp.com/dashboard/developer/onboarding), reached from its [plugin page](https://nativephp.com/plugins). Use the listing copy and documentation URL above. Required dashboard fields must be confirmed after authentication.
5. If seeking inclusion in the framework itself, agree scope with NativePHP maintainers first. A marketplace package and a core pull request are separate review paths; do not assume that an unrelated PR adds marketplace distribution.
6. Attach the actual verification record, platform matrix and a small native-demo recording. Rebuild the downloadable archive after any changes.

Run `python3 scripts/package.py` to create `build/nativephp-carplay-0.1.0-review.zip` and its SHA-256 file. The archive contains source, fixtures and documentation only; generated binaries, native SDKs and local app data are excluded.

No account credentials, signing material or proprietary host binaries belong in this package. There is no fabricated approval, publication URL, review response or benchmark result in the dossier.
