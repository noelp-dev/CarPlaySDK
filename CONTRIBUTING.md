# Contributing

Run `php scripts/check.php`, `php tests/run.php`, `php tests/transport.php`, `npm test` and `python3 scripts/verify-native.py` before proposing changes. The last command requires the platform SDKs; use `--platform ios` or `--platform android` on a single-platform machine.

Add shared fixture cases when changing the wire contract. Keep PHP, Swift, Kotlin, TypeScript and the structural schema consistent. Maintain explicit platform/category capability gates and complete every native callback. Do not wait synchronously for PHP inside a car host callback.

Record native host/device results separately from SDK compilation. A real feature needs its native lifecycle, error handling and documented category support. Follow [verification](docs/VERIFICATION.md) for acceptance and [architecture](docs/ARCHITECTURE.md) for extension points.

Release contributions must retain MIT attribution and dependency notices. Do not include signing profiles, certificates, personal tokens, proprietary NativePHP distributions or app data in the repository.
