# Verification and release gates

Local verification was performed on 2026-10-10. This is an implementation review candidate, not a certified device release.

Local tools: PHP 8.4.1, Node 23.11.0, Apple Swift 6.2.4 in Swift 5 language mode, iOS Simulator SDK 26.2 targeting iOS 18, Android SDK Platform 36, Kotlin 2.3.10 targeting JVM 17, and Android Studio's JRE 25. The prepared CI uses PHP 8.3, Node 22 and Kotlin 2.1.21; its hosted runs remain unexecuted.

## Executed checks

| Check | Result | Evidence / command |
| --- | --- | --- |
| Composer metadata | Pass | `composer validate --strict` |
| Manifest/source mappings | Pass | `php scripts/check.php` checks all 14 mappings, constructor arguments, resources and event class. |
| Upstream NativePHP manifest parser | Pass | `php scripts/check.php /path/to/PluginManifest.php`, using the researched source snapshot. |
| PHP contract/API/configurator checks | 131 pass | `php tests/run.php` |
| PHP response transport checks | 9 pass | `php tests/transport.php` |
| JavaScript client tests | 3 pass | `npm test` |
| Swift contract parity | 76 fixtures pass | Native verification script. |
| Kotlin contract parity | 76 fixtures pass | Same fixture file and native verification script. |
| Swift queue persistence | Pass | Overflow, non-destructive reads, restart replay, acknowledgement, idempotent acknowledgement and clearing cached root. |
| Swift native sources | Pass | All bridge/scene/renderers typechecked against the real iOS Simulator SDK, deployment target iOS 18. |
| Kotlin native sources | Pass | All service/session/screen/bridge sources compiled against Android SDK Platform 36 and real AndroidX Car App 1.7.0 classes. |

The shared fixtures include missing/unknown fields, empty/loading lists, sections, grids, all template types, duplicate identifiers, tab nesting, disabled items, UTF-8/identifier size boundaries, item/action limits and geographic boundaries. PHP also verifies all bridge methods, navigation payloads, runtime absence, plist preservation, configuration idempotency and conflicting categories.

The native compile harness substitutes **only** NativePHP's bridge protocol/response helpers and event sink. UIKit/CarPlay/MapKit and Android/AndroidX APIs are real. The harness therefore detects incorrect SDK method names/signatures and Kotlin constructor types, but cannot prove that NativePHP starts its PHP runtime or that an OEM accepts every template.

The included GitHub Actions workflow mirrors the checks on separate PHP/JS, macOS Swift and Linux Kotlin jobs. That workflow runs on GitHub Actions in [noelp-dev/CarPlaySDK](https://github.com/noelp-dev/CarPlaySDK/actions) for every push and pull request. It repeats the source/compile checks only; it does not replace the signed app, simulator, DHU or vehicle tests. Android dependencies used by the compile harness have pinned SHA-256 checksums; they are downloaded into ignored build output, not committed.

## Reproduce

```sh
composer validate --strict
php scripts/check.php
php tests/run.php
php tests/transport.php
npm test
python3 scripts/verify-native.py
```

Use `--platform ios` or `--platform android` when only one SDK is available. `--dependencies /path/to/cache --no-download` reuses an existing pinned Android archive cache. Xcode's Command Line Tools, JDK 17+, Kotlin and Android SDK Platform 36 are required. On macOS the script detects Android Studio's bundled Kotlin/JDK.

The compile dependencies describe the isolated harness, not forced upgrades for every transitive dependency in a Laravel host. The plugin manifest contributes only AndroidX Car App's `app` and `app-projected` artifacts; the real host build resolves its complete dependency graph.

## Acceptance still required

| Scenario | Expected result | Status |
| --- | --- | --- |
| Register plugin in a clean NativePHP Mobile 4.x app | Manifest validation, generated registrations and native app builds succeed. | Pending |
| Signed iOS app with approved parking/charging/food entitlement | App appears in CarPlay and renders its root. | Pending |
| CarPlay Simulator interactions | Lists, grids, information, POI, alerts, stack/back controls and all callbacks operate. | Pending |
| iOS audio configuration with a real external player | Search and Now Playing presentation match player state. | Pending |
| Android debug APK with DHU | Service discovery, all supported templates, selection, search and navigation handoff operate. | Pending |
| Android release APK on a real Google host | Signature validation permits the host and rejects an untrusted one. | Pending |
| Android API 1/2/5/6 host behavior | Fallback limits, enabled rows, refresh callbacks and tab gates match negotiated support. | Pending |
| Car starts before handset UI / PHP runtime | Cached root appears, events remain available when the phone app resumes. | Pending |
| Disconnect during a queued host operation | Completion reports failure without committing data into another scene/session. | Pending |
| Host Back, repeated replacement and maximum task depth | Native and bridge stack states stay coherent; no refresh rule bypass. | Pending |
| Corrupt cache / storage failure / queue overflow | Safe startup, reported persistence error, counted overflow and replay behavior. | Queue logic tested; device scenarios pending |
| Logout/account switch | No stale root or old-user handler performs an action. | Application integration pending |
| Rotary input, touch, language expansion and accessibility | Host focus, titles, icons and action labels remain usable. | Pending |
| Physical CarPlay / Android Auto vehicle | Actual connection, screen and lifecycle behavior match the simulator/DHU. | Pending |

Record app/framework version, OS version, device, head-unit/API level, signing/build type, expected/actual outcome and relevant event IDs for each result. Attach screenshots or short recordings where useful. Do not relabel SDK compilation as a passed vehicle test.
