# PHP API, wire contract and events

Use `Fatsoenlijk\CarPlay\Facades\CarPlay` in Laravel, or inject `Fatsoenlijk\CarPlay\CarPlay`. The facade delegates to the same instance. Tests can construct it with any implementation of `Contracts\Transport`.

## Bridge methods

| PHP / JS method | Native function | Parameters | Result |
| --- | --- | --- | --- |
| `capabilities()` | `CarPlay.Capabilities` | none | Platform, category, types, replacement support, flags, icons and limits. |
| `status()` | `CarPlay.Status` | none | Connection, stack depth, visible ID, cached-root flag and persistence error. |
| `setRoot(Template)` | `CarPlay.SetRoot` | `template` | Accepts a root operation; caches it even while disconnected. |
| `push(Template)` | `CarPlay.Push` | `template` | Accepts a push operation; requires a connected car. |
| `replace(Template)` | `CarPlay.Replace` | `template` | Accepts an in-place update; same visible ID/type required. |
| `pop()` | `CarPlay.Pop` | none | Accepts a pop; the root cannot be popped. |
| `popToRoot()` | `CarPlay.PopToRoot` | none | Accepts a return to the root. |
| `present(Template)` | `CarPlay.Present` | alert `template` | CarPlay modal alert; unsupported on Android. |
| `dismiss()` | `CarPlay.Dismiss` | none | CarPlay modal dismissal; unsupported on Android. |
| `clear()` | `CarPlay.Clear` | none | Clears cached root and shows a placeholder if connected. |
| `navigate(lat, lon, name = '')` | `CarPlay.Navigate` | numeric `latitude`, `longitude`; optional text `name` | Navigation handoff; requires connection. |
| `events(limit = 100)` | `CarPlay.Events` | integer `limit` 1–256 | `{events: [...], dropped: cumulativeCount}`; reading does not remove events. |
| `acknowledge(ids)` | `CarPlay.Acknowledge` | list of at most 256 event IDs | `{acknowledged: count, persisted: boolean}`. |
| `bindEvents()` | `CarPlay.BindEvents` | none | `{bound: true}`; binds optional Android handset forwarding. |

UI commands return an operation identifier:

```json
{"accepted": true, "operationId": "e72d…"}
```

This means the command was scheduled. Native UI operations run on the main thread and must not block PHP while awaiting the host. Find the event with that `operationId` to determine whether it succeeded. An unsupported or invalid request can fail immediately; a disconnect, depth limit or host rejection can fail asynchronously.

`setRoot` while disconnected saves the desired initial screen. Only the root is persisted: pushed screens, modal alerts, active tab and search query state are transient. Reconnecting starts from the cached root. A cold car launch displays it without starting a phone Activity or requiring a PHP request. An invalid cache yields a placeholder and an error event.

`clear` clears the cached root, not the event history. At logout, clear the screen, drain/acknowledge pending events and stop handlers that should no longer act for the old user. Cached content is not account-aware; applications must manage its freshness and ownership.

## Template builders

All templates have a unique `id`, a `type`, a nonempty `title`, and optionally an `icon`. `Template` is immutable and implements `JsonSerializable`.

```php
use Fatsoenlijk\CarPlay\Templates\Template;

$list = Template::list('parking', 'Parking', [
    ['title' => 'Nearby', 'items' => [
        ['id' => 'garage', 'title' => 'Centrum', 'detail' => 'Open until 23:00',
         'icon' => 'parking', 'action' => 'garage-details', 'enabled' => true],
    ]],
]);

$grid = Template::grid('menu', 'Menu', [
    ['id' => 'locations', 'title' => 'Locations', 'icon' => 'map'],
    ['id' => 'favorites', 'title' => 'Favorites', 'icon' => 'star'],
]);

$info = Template::information('garage-details', 'Centrum', [
    ['title' => 'Available', 'detail' => '24 spaces'],
    ['title' => 'Rate', 'detail' => '€ 2.50 per hour'],
], [
    ['id' => 'navigate-garage', 'title' => 'Navigate'],
    ['id' => 'reserve-garage', 'title' => 'Reserve'],
]);

$message = Template::message('confirmation', 'Reservation', 'Confirmed');
$search = Template::search('search', 'Search', [
    ['id' => 'garage', 'title' => 'Centrum'],
], 'Find a location');
$tabs = Template::tabs('home', 'Parking', [
    $list->withIcon('parking'), $grid->withIcon('grid'),
]);
$poi = Template::pointsOfInterest('nearby-map', 'Nearby', [
    ['id' => 'garage', 'title' => 'Centrum', 'latitude' => 52.37, 'longitude' => 4.89,
     'subtitle' => '24 spaces', 'summary' => 'EV charging available',
     'actions' => [['id' => 'navigate-garage', 'title' => 'Navigate']]],
]);
$alert = Template::alert('confirm', 'Reserve a space?', [
    ['id' => 'reserve', 'title' => 'Reserve'],
    ['id' => 'cancel', 'title' => 'Cancel', 'style' => 'cancel'],
]);
$nowPlaying = Template::nowPlaying(); // iOS audio category, presentation only.
```

Use `Template::fromArray($data)` for serialized templates. PHP validates before sending. Swift and Kotlin independently validate the same contract, including callers using JavaScript directly. No user-defined native classes, arbitrary URLs or executable callbacks appear in the payload: `action` and action `id` are application-defined event identifiers.

| Type | Specific fields |
| --- | --- |
| list | `sections`: 1–10 objects with optional `title`, required `items`; at most 100 rows total. Optional boolean `loading`. |
| grid | `items`: 1–8 rows; each requires `icon`. |
| information | `items`: 1–4 objects containing `title`, optional `detail`. Optional `actions`. |
| message | nonempty `message`; optional `actions`. |
| search | `items`: 0–100 rows; optional nonempty `hint`. |
| tabs | `tabs`: 2–4 child templates; only list/grid children. Root only. |
| poi | `points`: 1–6 point objects. |
| alert | `actions`: 1–2 actions; title is the prompt. Modal only. |
| nowPlaying | no additional fields. Cannot be the root. |

A selectable row has required `id` and `title`; optional `detail`, `icon`, boolean `enabled`, and `action`. The emitted action defaults to its row ID. Row IDs must be unique across sections within a list.

A point requires `id`, `title`, numeric `latitude` and `longitude`; optional `subtitle`, `summary` and up to two `actions`. Coordinates must be finite and fall within latitude ±90 / longitude ±180. Point and action IDs must be unique within their respective collections.

An action requires `id` and `title`; `style` is optional and is one of `normal`, `cancel`, `destructive`. Styling differences are documented in [platform support](PLATFORMS.md).

IDs are 1–128 ASCII characters: an alphanumeric first character followed by alphanumerics, `_`, `.`, `:`, `-`. Text is valid UTF-8, at most 512 **bytes**. Optional text may be empty where applicable. Omit optional fields instead of assigning null. Unknown fields are rejected. A complete template may not exceed 256 KiB of JSON. `docs/template.schema.json` describes structural constraints; native/PHP validation also checks byte sizes and IDs unique by property.

Available icons: `list`, `grid`, `search`, `map`, `pin`, `parking`, `charging`, `food`, `music`, `play`, `pause`, `info`, `star`, `home`. Their artwork is platform-specific.

## Event envelope

```json
{
  "id": "8d35…",
  "type": "itemSelected",
  "platform": "carplay",
  "timestamp": 1791660000.123,
  "payload": {
    "templateId": "parking",
    "itemId": "garage",
    "actionId": "garage-details"
  }
}
```

`id` is a UUID; `timestamp` is Unix time in seconds. Platforms are `carplay` and `androidAuto`. Optional immediate forwarding uses the registered `Fatsoenlijk\CarPlay\Events\CarEvent` class with these same five fields. Android requires `bindEvents()` while the handset Activity exists; otherwise the native queue still captures events.

| Event | Payload |
| --- | --- |
| connected | iOS `category`; Android negotiated `carAppApiLevel`. |
| disconnected | empty object. |
| templateAppeared | `templateId`. Can repeat after returning to a screen. |
| itemSelected | `templateId`, `itemId`, `actionId`. |
| actionPressed | `templateId`, `actionId`; point actions also include `pointId`. |
| searchChanged | `templateId`, `query`, limited to 128 characters. |
| searchSubmitted | Android: `templateId`, `query`. |
| tabSelected | `templateId`, `tabId`. |
| pointSelected | `templateId`, `pointId`. |
| mapRegionChanged | iOS: template ID, center latitude/longitude and span deltas. |
| contentRefreshRequested | Android API 5+: `templateId`. |
| contentStyleChanged | iOS: `style` (`light`/`dark`). |
| operationCompleted | `operationId`, `command`, boolean `success`, `code`, `message`. |
| error | `code`, `message`, for cache/rendering failures. |

## Delivery and persistence

The queue retains up to **256** events in order. New events evict the oldest when full and increment the persisted `dropped` count. Reading returns a prefix without removing it. Acknowledging an unknown or already acknowledged ID is harmless. Individual state-file replacements are atomic.

Delivery is at least once while storage is healthy and before capacity overflow. It is not exactly once or unbounded. An event may arrive immediately and later through polling, or be replayed after a crash between business processing and acknowledgement. Use the event UUID as an idempotency key in the application's durable business transaction. For network-side actions, pass that key to the backend too. Do not issue a second reservation/payment because the same event reappeared.

For UI operations, wait for completion and inspect the current template before retrying. A host completion timeout can leave its actual state uncertain; do not automatically retry that command. An operation result itself is an event and needs acknowledgement like the others.

`status().persistenceError` reports file-storage failures. `acknowledge().persisted` reports whether the acknowledgement reached storage. Commands can change in-memory/UI state even when persistence fails. Avoid claiming durable completion while that error is present. The event queue and cache cannot execute PHP business logic while the runtime is suspended; they preserve data until the application can process it again.

The iOS file is in application support, excluded from backup, with file protection until first unlock. Android uses `noBackupFilesDir` and `AtomicFile`. No network analytics or telemetry is sent by the plugin. Search queries and displayed content can enter local storage, so applications should avoid unnecessary secrets and provide their own retention/logout behavior.

## Errors

PHP throws `Exceptions\BridgeException` for native errors, preserving `errorCode`; invalid PHP templates throw `InvalidArgumentException`. JavaScript throws `CarPlayError` with `.code`.

| Code | Meaning |
| --- | --- |
| RUNTIME_UNAVAILABLE | PHP is outside a native runtime. |
| INVALID_RESPONSE | Response is not a valid bridge object. |
| INVALID_PARAMETERS | Contract, same-ID replacement or depth requirement failed. |
| UNSUPPORTED | Type/category/platform or negotiated API does not support the request. |
| NOT_CONNECTED | Car session is absent or disconnected during the operation. |
| QUEUE_FULL | More than 64 pending native operations. |
| HOST_REJECTED | Platform/OEM API rejected the operation. |
| HOST_TIMEOUT | CarPlay completion was not received within 15 seconds; inspect actual state before retrying. |
| INVALID_CACHE | Cached root failed validation or category/API checks. |
| TEMPLATE_REJECTED | Android rendering fallback after a model/host constraint error. |

The NativePHP HTTP controller can also report its own transport errors, such as missing runtime or registration. Do not convert those into successful empty results.
