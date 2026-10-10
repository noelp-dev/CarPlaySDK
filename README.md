# CarPlaySDK for NativePHP

One PHP API for native Apple CarPlay templates and a Kotlin Android Auto `CarAppService`. This is a community plugin for NativePHP Mobile 4.x, with Swift and Kotlin implementations, a Laravel facade, a JavaScript/TypeScript client, and documentation for maintainers.

**Status: 0.1.0 review candidate.** Both native implementations compile against real platform SDKs. Shared PHP/Swift/Kotlin contract tests pass. A signed NativePHP app, simulator/DHU sessions and physical vehicle tests remain release gates; see [verification](docs/VERIFICATION.md). This package has not been published or submitted.

## Features

- Lists and sections, grids, information panes, messages, search, tabs and points of interest.
- CarPlay alerts and Now Playing presentation, subject to the application's approved category.
- Root/push/pop navigation, supported in-place updates, lifecycle and interaction events.
- Navigation handoff to Apple Maps or the Android Auto host's navigation app.
- Native startup from cached content, independent of the handset interface.
- Atomic, bounded event storage with explicit acknowledgement and observable overflow.
- Capability negotiation, host content limits, native validation and structured errors.
- Automatic iOS scene/category/entitlement configuration through a NativePHP build hook.

CarPlay is an Apple platform. The Android implementation uses Android Auto rather than attempting to run CarPlay on Kotlin. Embedded turn-by-turn navigation, a media playback engine, communication/SiriKit and Android Automotive distribution are outside this release. The [platform matrix](docs/PLATFORMS.md) explains the exact mappings.

## Local installation

The Composer package is `noelp-dev/carplay-sdk`. Add this checkout as a Composer path repository in your **NativePHP application**:

```json
{
  "repositories": [{"type": "path", "url": "../carplayapp"}]
}
```

```sh
composer require noelp-dev/carplay-sdk:@dev
php artisan vendor:publish --tag=nativephp-plugins-provider
php artisan native:plugin:register noelp-dev/carplay-sdk
```

For iOS, set `CARPLAY_CATEGORY=parking`, `charging`, `food` or `audio` in the application's `.env`, selecting the category Apple approved. Obtain its entitlement and matching provisioning profile. The build hook inserts that entitlement and the CarPlay scene while retaining phone scenes. Android defaults to Google's POI category. Full instructions are in [installation](docs/INSTALLATION.md).

```php
use Fatsoenlijk\CarPlay\Facades\CarPlay;
use Fatsoenlijk\CarPlay\Templates\Template;

$operation = CarPlay::setRoot(Template::list('parking', 'Nearby parking', [
    ['title' => 'Amsterdam', 'items' => [
        ['id' => 'garage', 'title' => 'Centrum', 'detail' => '24 spaces',
         'icon' => 'parking', 'action' => 'open-garage'],
    ]],
]));
```

UI commands return `{accepted: true, operationId: ...}`. Their actual result arrives as an `operationCompleted` event. Check it before assuming a screen appeared:

```php
foreach (CarPlay::events()['events'] as $event) {
    // Handle idempotently using $event['id']; see the event-delivery documentation.
    logger()->debug($event['type'], $event['payload']);
    CarPlay::acknowledge([$event['id']]);
}
```

An optional immediate `CarEvent` notification supplements the stored queue. Polling remains available when the handset UI was absent during an interaction. See [API and events](docs/API.md) and the [parking example](examples/ParkingExperience.php).

## Development

```sh
composer validate --strict
php scripts/check.php
php tests/run.php
php tests/transport.php
npm test
python3 scripts/verify-native.py
```

Native checks require Xcode, Android SDK Platform 36, JDK 17+ and a Kotlin compiler. Android Studio's bundled compiler/JDK are detected on macOS. The verification script fetches checksum-pinned Android dependencies into `build/`. It substitutes only the NativePHP host boundary; it does not simulate a car. See [verification](docs/VERIFICATION.md).

## Documentation

| Document | Contents |
| --- | --- |
| [Installation](docs/INSTALLATION.md) | NativePHP registration, build hook, signing, CarPlay simulator and Android DHU |
| [API](docs/API.md) | All methods, templates, events, errors and delivery semantics |
| [Platform support](docs/PLATFORMS.md) | Template mappings, category gates and deliberate limitations |
| [Architecture](docs/ARCHITECTURE.md) | Threads, native startup, persistence, host validation and extension points |
| [Research](docs/RESEARCH.md) | Primary sources and upstream code used for the implementation |
| [Verification](docs/VERIFICATION.md) | Executed checks and remaining acceptance tests |
| [Submission dossier](docs/SUBMISSION.md) | Marketplace listing text, maintainer review notes and release checklist |
| [Nederlandse overdracht](docs/NL.md) | Praktische samenvatting voor de eigenaar |

MIT licensed. CarPlay, Android Auto and NativePHP names identify their respective platforms; this package does not imply their endorsement.
