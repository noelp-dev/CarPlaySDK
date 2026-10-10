# Research and implementation basis

Research date: **2026-10-10**. The starting workspace was empty. The implementation targets NativePHP Mobile's version 4 plugin architecture and the public Apple/Android template frameworks.

## Primary platform sources

| Source | Design consequence |
| --- | --- |
| [NativePHP plugin architecture](https://nativephp.com/docs/mobile/4/plugins/introduction) | Ship a Composer package with native sources and a manifest rather than a forked mobile host. |
| [Creating/registering plugins](https://nativephp.com/docs/mobile/4/plugins/creating-plugins) | Use `nativephp-plugin`, a Laravel provider, explicit registration and vendor-scoped Kotlin classes. |
| [Bridge functions](https://nativephp.com/docs/mobile/4/plugins/bridge-functions) | PHP calls route to `BridgeFunction` implementations. |
| [Native events](https://nativephp.com/docs/mobile/4/plugins/events) | Implement optional host event forwarding, with the stored queue supplying recovery when the handset interface is absent. |
| [Advanced manifest configuration](https://nativephp.com/docs/mobile/4/plugins/advanced-configuration) | Register the Android service/resource/dependencies and iOS scene. Sources for declared assets are relative to `resources/`. |
| [Lifecycle hooks](https://nativephp.com/docs/mobile/4/plugins/lifecycle-hooks) | Use a post-compilation hook for app-specific category/entitlement selection. |
| [Apple CarPlay overview](https://developer.apple.com/documentation/carplay) | Use system-controlled templates rather than arbitrary custom HTML. |
| [CarPlay entitlements](https://developer.apple.com/documentation/carplay/requesting-carplay-entitlements) | Approval, App ID and provisioning are app-specific and cannot be granted by a library. |
| [CarPlay scenes](https://developer.apple.com/documentation/carplay/cptemplateapplicationscene) | Implement a separate scene delegate and preserve the phone scene. |
| [CarPlay information template](https://developer.apple.com/documentation/carplay/cpinformationtemplate) | Provide an information mapping with category gating; it is unavailable to audio apps. |
| [CarPlay POI template](https://developer.apple.com/documentation/carplay/cppointofinteresttemplate) | Use native map points, selection and region delegates. The portable contract chooses a smaller shared point limit. |
| [Android for Cars App Library](https://developer.android.com/training/cars/apps/library) | Implement Kotlin's CarAppService/Session/Screen model for Android Auto. |
| [AndroidX Car App release history](https://developer.android.com/jetpack/androidx/releases/car-app) | Pin stable 1.7.0 rather than a release candidate or alpha. |
| [Android tab templates](https://developer.android.com/reference/androidx/car/app/model/TabTemplate) | Require negotiated Car App API 6 and restrict portable tab children. |
| [Android POI map templates](https://developer.android.com/reference/androidx/car/app/model/PlaceListMapTemplate) | The existing POI map template is deprecated but implemented in 1.7.0; document a future surface-map migration. |
| [Android DHU](https://developer.android.com/training/cars/testing/dhu) | Record device/DHU validation as a separate gate from compiling Kotlin. |
| [Car app quality](https://developer.android.com/docs/quality-guidelines/car-app-quality) | Category suitability and host interaction constraints remain application release obligations. |

## Upstream code review

NativePHP source was inspected at commit [`ee03682ee7fd9939c229e8414123a795771c70e7`](https://github.com/NativePHP/mobile-air/tree/ee03682ee7fd9939c229e8414123a795771c70e7), dated 2026-10-02. Important findings were checked in executable code instead of assuming every documentation example matches the current host:

- [AndroidPluginCompiler](https://github.com/NativePHP/mobile-air/blob/ee03682ee7fd9939c229e8414123a795771c70e7/src/Plugins/Compilers/AndroidPluginCompiler.php): bridge constructors default to an Activity. This manifest explicitly opts into context-only constructors for all methods except handset event binding. Its service metadata and intent filters follow the compiler's supported keys.
- [IOSPluginCompiler](https://github.com/NativePHP/mobile-air/blob/ee03682ee7fd9939c229e8414123a795771c70e7/src/Plugins/Compilers/IOSPluginCompiler.php): nested Info.plist contributions merge into both phone/simulator plists. The configurator separately chooses the app-specific entitlement without replacing the application's scene tree.
- [Kotlin bridge responses](https://github.com/NativePHP/mobile-air/blob/ee03682ee7fd9939c229e8414123a795771c70e7/resources/androidstudio/app/src/main/java/com/nativephp/mobile/bridge/BridgeRouter.kt) and [Swift bridge responses](https://github.com/NativePHP/mobile-air/blob/ee03682ee7fd9939c229e8414123a795771c70e7/resources/xcode/NativePHP/Bridge/BridgeRouter.swift): success values are direct dictionaries; errors carry status/code/message. The PHP decoder does not blindly read `data` from every successful call.
- [NativeCallController](https://github.com/NativePHP/mobile-air/blob/ee03682ee7fd9939c229e8414123a795771c70e7/src/Http/Controllers/NativeCallController.php): the JS HTTP endpoint wraps successful native dictionaries in a success/data envelope. The JS decoder handles this separately.
- [Hook context](https://github.com/NativePHP/mobile-air/blob/ee03682ee7fd9939c229e8414123a795771c70e7/src/Plugins/Commands/NativePluginHookCommand.php): configuration uses the actual platform/build-path options provided by NativePHP.
- [PluginManifest](https://github.com/NativePHP/mobile-air/blob/ee03682ee7fd9939c229e8414123a795771c70e7/src/Plugins/PluginManifest.php): the package manifest was accepted by this upstream parser in the local verification run.

The [official 1.7.0 source archive](https://dl.google.com/android/maven2/androidx/car/app/app/1.7.0/app-1.7.0-sources.jar) and SDK headers were also inspected. In particular, ConstraintManager requires API 2, row enabled state and POI refresh callbacks require API 5, tabs require API 6, and a non-browsable place row needs a distance span. This renderer uses browsable place rows that open a detail screen and guards the newer APIs.

## Scope conclusions

The shared abstraction is an in-car **template and event bridge**. Kotlin is the Android Auto implementation, not an alternative implementation of Apple's CarPlay protocol. One generic API cannot safely promise media playback, navigation, communication and vehicle controls merely by naming those functions: each needs its native lifecycle and category support.

Accordingly this candidate implements complete native template paths and acknowledges unsupported operations. It supplies navigation handoff and Now Playing presentation without advertising a route engine or audio engine. A durable local root/event store makes native startup independent of PHP UI availability, but it does not grant background PHP execution.

## Submission route

NativePHP's public [plugin page](https://nativephp.com/plugins) links developers to [developer onboarding](https://nativephp.com/dashboard/developer/onboarding). That destination requires authentication. The public pages do not expose all current submission form fields or guarantee acceptance. The dossier therefore supplies portable listing/review material and distinguishes a marketplace listing from a core-framework contribution. No account interaction or submission was performed.
