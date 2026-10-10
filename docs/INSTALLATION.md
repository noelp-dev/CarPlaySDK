# Installation and host setup

## Requirements

Use a NativePHP **Mobile 4.x** application. Desktop NativePHP does not host this bridge. The plugin manifest targets iOS 18+ and Android SDK 29+, matching NativePHP's current baseline. AndroidX Car App is pinned to stable 1.7.0. A host negotiating Car App API 6+ is necessary for tabs.

The repository is a Composer plugin rather than a complete Laravel application. Add a path repository pointing to this directory, require `noelp-dev/carplay-sdk:@dev`, then register its provider through `native:plugin:register`. Composer's Laravel provider discovery supplies the PHP bindings; NativePHP's separate plugin registration compiles the native sources. [NativePHP registration guide](https://nativephp.com/docs/mobile/4/plugins/creating-plugins).

## iOS

1. Request the CarPlay capability for the application's actual category. Apple must approve it; adding a plist key does not grant it. This release implements parking, EV charging, quick food ordering and audio template integrations.
2. Enable the approved capability on the App ID and obtain a provisioning profile containing the entitlement. Configure signing for the generated NativePHP target.
3. Set one of these values in the Laravel application's `.env`:

   ```dotenv
   CARPLAY_CATEGORY=parking
   ```

4. If the application caches configuration, refresh that cache after changing the category. Optionally publish configuration with `php artisan vendor:publish --tag=carplay-config`.
5. Run `php artisan native:install` for a new host, followed by `php artisan native:run` and select iOS.

The plugin's `post_compile` hook runs `carplay:configure`. It prepares edits to:

- `NativePHP/Info.plist`: category and CarPlay scene.
- `NativePHP-simulator-Info.plist`, if present: the same settings.
- `NativePHP/NativePHP.entitlements`: the selected category's entitlement.

The XML editor preserves unrelated entitlements, phone scenes and bundle metadata. The operation is idempotent. It rejects an absent/unsupported category, malformed plist, or another existing CarPlay category entitlement. It cannot obtain Apple's approval or select a signing identity. A category change may require a fresh generated host and a different provisioning profile.

To inspect configuration independently of a build:

```sh
php artisan carplay:configure --platform=ios --build-path=/absolute/path/to/app/nativephp/ios --dry-run
```

Use the actual generated iOS project directory containing `NativePHP/Info.plist`. Remove `--dry-run` to apply the edits. The hook normally supplies that path automatically. Every file is prepared before writing; individual replacements are atomic, but the three-file update is not a filesystem transaction.

| Category | Entitlement |
| --- | --- |
| parking | `com.apple.developer.carplay-parking` |
| charging | `com.apple.developer.carplay-charging` |
| food | `com.apple.developer.carplay-quick-ordering` |
| audio | `com.apple.developer.carplay-audio` |

For audio applications, supply a real player/audio session separately. `nowPlaying` only presents the system's Now Playing template. This package does not provide background playback or media metadata management.

Launch the iOS Simulator and select **I/O → External Displays → CarPlay**. Publish a root template from PHP, select rows, inspect `operationCompleted`, then disconnect/reconnect and test cached startup. Repeat on a signed device. See Apple's [entitlement instructions](https://developer.apple.com/documentation/carplay/requesting-carplay-entitlements) and [scene documentation](https://developer.apple.com/documentation/carplay/cptemplateapplicationscene).

## Android Auto / Kotlin

The manifest registers `dev.fatsoenlijk.carplay.NativeCarAppService` as an exported `androidx.car.app.CarAppService` with the POI category. It also declares the minimum Car App API level, includes `app` and `app-projected` dependencies, and copies `nativephp_car_app_desc.xml` to Android resources. This installs real Android Auto templates; no handset Activity or WebView is used to draw the car interface.

Rebuild the host with `php artisan native:run` and select Android. In Android Auto developer settings, enable development support as needed for a locally installed app. Install Google's **Android Auto Desktop Head Unit** through Android Studio's SDK Tools and follow the [official DHU setup](https://developer.android.com/training/cars/testing/dhu). Connect a device with Android Auto, start its head-unit server, forward the DHU connection using `adb`, and launch the DHU for your operating system.

Debug APKs permit development hosts only when Android marks the app `FLAG_DEBUGGABLE`. Release APKs use signature checks for Google's Android Auto host plus the Car App Library's privileged renderer validation. Test a release APK separately: a debug DHU run does not exercise the release host validator.

The POI category fits parking, charging and location discovery applications. An arbitrary Laravel application does not automatically qualify. Changing the service category requires a reviewed category-specific implementation and corresponding Google Play declarations. Use Google's [Car App Library guide](https://developer.android.com/training/cars/apps/library) and [car quality requirements](https://developer.android.com/docs/quality-guidelines/car-app-quality).

Android Automotive OS needs additional activity/manifest/packaging work. The Kotlin service shares its template model with that ecosystem, but this package currently ships an Android **Auto projected** integration only.

## JavaScript and TypeScript

```sh
php artisan vendor:publish --tag=carplay-js
```

```js
import { CarPlay } from './vendor/nativephp-carplay/carplay.mjs';

const state = await CarPlay.status();
const capabilities = await CarPlay.capabilities();
```

The client calls the NativePHP `/_native/api/call` controller and unwraps its success envelope. It does not expose an external HTTP service. TypeScript declarations are included. The optional root `package.json` is private and is used for local tests, not a published npm package.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| `RUNTIME_UNAVAILABLE` in PHP | Run inside a NativePHP Mobile host, or inject a test transport. |
| Method not registered | Register the plugin in the application's NativeServiceProvider and rebuild. |
| iOS build requests a category | Set `CARPLAY_CATEGORY` and refresh cached Laravel configuration. |
| App absent from CarPlay | Check approved capability, target entitlement, provisioning and scene configuration. |
| `accepted: true` but no screen | Read the matching `operationCompleted`; acceptance is not host success. |
| `NOT_CONNECTED` | Connect the car before stack/navigation operations. `setRoot` works offline. |
| Android tabs unavailable | Inspect negotiated `carAppApiLevel`; API 6 is required. |
| Empty/cropped Android list | Inspect host content limits and loading state. Use short pages. |
| No immediate Android events | Call `bindEvents()` from the handset UI; stored polling does not need it. |
| Release host rejected | Inspect host package/signature and actual release signing/debug flags. |
| Native source changes missing | Rebuild; use NativePHP's fresh-install option when the host scaffold is stale. |
