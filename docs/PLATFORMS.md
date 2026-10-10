# Platform support

CarPlay and Android Auto have different template inventories, policies and lifecycles. Capability responses describe this implementation, not a store approval or permission to show arbitrary content.

## Template mapping

| Wire type | Apple CarPlay | Kotlin / Android Auto | Limits and behavior |
| --- | --- | --- | --- |
| `list` | `CPListTemplate` | `ListTemplate` | Up to 10 sections / 100 rows in the contract; Android queries the host's content limit. Empty/loading states supported. |
| `grid` | `CPGridTemplate` | `GridTemplate` | 1–8 icon-bearing items; Android applies its host's grid limit. |
| `information` | `CPInformationTemplate` | `PaneTemplate` | 1–4 rows, up to 2 actions. Noninteractive information rows. |
| `message` | Information template with a message row | `MessageTemplate` | Nonempty message, up to 2 actions. |
| `search` | `CPSearchTemplate` | `SearchTemplate` | Cached result filtering, search events and item selection; supply new results with `replace`. |
| `tabs` | `CPTabBarTemplate` | `TabTemplate` | Root only; 2–4 list/grid children. Android requires negotiated Car App API 6. |
| `poi` | `CPPointOfInterestTemplate` | `PlaceListMapTemplate` | 1–6 geographic points. Android selection opens an information screen with point actions; CarPlay uses its detail card. |
| `alert` | `CPAlertTemplate` | Unsupported | iOS modal only, up to 2 actions; action automatically dismisses it. |
| `nowPlaying` | `CPNowPlayingTemplate.shared` | Unsupported | iOS audio category, pushed presentation only. No audio player is included. |

Google deprecated `PlaceListMapTemplate` in the 1.7 generation. It remains implemented in the pinned stable library and supplies a host-rendered POI map without inventing a map engine. Migration to `MapWithContentTemplate` will require a map surface renderer and is tracked as a separate extension.

## Implemented iOS category gates

| Configured category | Allowed types |
| --- | --- |
| `parking`, `charging`, `food` | list, grid, information, message, tabs, poi, alert |
| `audio` | list, grid, tabs, search, alert, nowPlaying |
| missing / other | No application templates; configure a supported category first. |

The actual entitlement must match the category configuration. The framework and store review remain authoritative. Navigation and communication categories are intentionally absent from the build configurator: navigation needs a genuine map/navigation implementation, while communication needs the relevant system intent/calling integration.

The Android manifest declares **POI**. Search is therefore available on Android while parking-category CarPlay rejects it. Consult capabilities and choose a list/POI alternative for that iOS experience.

## Stack and replacement

CarPlay permits a maximum depth of two for food ordering; the other implemented categories are bounded to five. Android is bounded to five screens, including the root. Native hosts also enforce task and refresh rules. A payload within the wire limits can still be rejected by a particular host or category.

`replace` updates the visible screen with the **same ID and type**. CarPlay supports list, information, message, search and POI replacement. A CarPlay list title is immutable and must remain unchanged. Android supports its non-tab screen types. Tabs are root-only on both platforms and are rebuilt through `setRoot`. Grids can be replaced on Android but must be rebuilt/pushed on CarPlay.

Android content refreshes can consume host task depth when they do not qualify as a refresh under Google's rules. Do not drive an infinite sequence of `replace` calls or assume it bypasses task limits. Query changes and user actions should determine updates.

Disabled CarPlay rows/grid buttons use native enabled states. Android rows use enabled states on API 5+; older hosts and grid items omit the click handler. The host may still draw a noninteractive item normally. Android uses system drawable resources for the named icons; their appearance differs from Apple's SF Symbols.

`normal`, `cancel` and `destructive` action styles map fully for CarPlay **alerts**. Information actions use normal/cancel text styles on iOS. Android pane/message actions use normal host styling. No destructive appearance is promised for those actions.

## Navigation and media

`navigate(latitude, longitude, name)` hands off a coordinate to Apple Maps or `CarContext.ACTION_NAVIGATE`. Android uses a geographic destination and currently does not use the optional name in the host URI. There is no route calculation, map surface, maneuver guidance, dashboard/instrument-cluster display or trip session. Both capability responses therefore report `embeddedNavigation: false`.

Presenting Now Playing is separate from playing audio. No audio session, queue, transport controls, background playback, MediaLibraryService or media browsing service is installed. Both platforms report `audioPlayback: false`. Applications can integrate an existing player separately without representing this plugin as a media engine.

No arbitrary HTML, video, WebView mirroring, vehicle telemetry, automotive property access, climate control, parking-state detection or unrestricted custom UI is provided. Those capabilities have separate native APIs and requirements.
