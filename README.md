![version](https://img.shields.io/badge/version-19%2B-5682DF)
![platform](https://img.shields.io/static/v1?label=platform&message=mac-intel%20|%20mac-arm&color=blue)
[![license](https://img.shields.io/github/license/miyako/4d-plugin-ical-v4)](LICENSE)
![downloads](https://img.shields.io/github/downloads/miyako/4d-plugin-ical-v4/total)

# 4d-plugin-ical-v4

The plugin drives Apple's EventKit framework (`EKEventStore`, `EKCalendar`, `EKEvent`, `EKRecurrenceRule`) to read and write the macOS Calendar database (Local calendars, iCloud/CalDAV, Exchange, and other EventKit sources) directly from 4D code. Every command exchanges data as a 4D `Object`, and every result you get back from a command that can fail carries a `.success` boolean and, on failure, an `.errorMessage` (and sometimes a structured `.error`).

---

## Summary

| Command | Returns | Purpose |
|---|---|---|
| [iCal Request permission](#ical-request-permission) | Object | Ask the user for Calendar access; must succeed before any other command works |
| [iCal QUERY EVENT](#ical-query-event) | Object | Search events in a date range, optionally restricted to specific calendars |
| [iCal GET CALENDAR LIST](#ical-get-calendar-list) | Object | List every calendar available to the current EventKit source |
| [iCal Get default calendar](#ical-get-default-calendar) | Object | Get the calendar new events are created in by default, plus the list of available sources (accounts) |
| [iCal Create calendar](#ical-create-calendar) | Object | Create a new calendar under a given source (account) |
| [iCal Set calendar property](#ical-set-calendar-property) | Object | Rename/recolor an existing calendar |
| [iCal Get calendar property](#ical-get-calendar-property) | Object | Read a calendar's properties |
| [iCal Remove calendar](#ical-remove-calendar) | Object | Delete a calendar |
| [iCal Create event](#ical-create-event) | Object | Create an event (optionally recurring) on a calendar |
| [iCal Set event property](#ical-set-event-property) | Object | Modify an existing event |
| [iCal Get event property](#ical-get-event-property) | Object | Read an event's properties, including alarms, attendees, and recurrence |
| [iCal Remove event](#ical-remove-event) | Object | Delete an event (or a single occurrence of a recurring event) |
| [iCal SET NOTIFICATION METHOD](#ical-set-notification-method) | — | Register a 4D method to be called whenever the Calendar database changes |
| [iCal Get notification method](#ical-get-notification-method) | Text | Read back the currently registered notification method name |
| [iCal KILL WORKER](#ical-kill-worker) | — | Stop the background change-listener process |

**Platforms:** macOS only (Intel and Apple Silicon). The plugin is built directly on Cocoa/EventKit/Security; there is no Windows implementation.

---

## Requirements & platform notes

- **Calendar permission is required before anything else works.** Every command except `iCal Request permission` itself checks a plugin-wide permission flag first, and returns `{success: false, errorMessage: "permission ..."}` immediately if it isn't authorized. Call `iCal Request permission` once at the start of your session and check `.success` before calling anything else.
- **Your host app's `Info.plist` needs `NSCalendarsUsageDescription`, and its entitlements need `com.apple.security.personal-information.calendars` set to `true`.** `iCal Request permission` checks both explicitly and fails with a specific, distinct error message for each — see [Error handling](#error-handling--troubleshooting).
- **The very first permission request is asynchronous.** The underlying `requestAccessToEntityType:` call from Apple returns immediately, before the user has actually answered the system dialog. The plugin's own permission check runs right after firing that request, so the *first* call to `iCal Request permission` in a fresh, "not yet decided" state will typically come back with `{success: false, errorMessage: "permission not determined"}` even though the system dialog is still on screen. Call `iCal Request permission` again after the user dismisses the dialog to get the real, final result.
- **Avoid calling `iCal Request permission` more than once per session once you're already authorized.** Internally, each call that finds permission already `authorized` re-registers the Calendar-change listener from scratch, without checking whether one is already running. If you call it repeatedly while authorized (for example, before every single calendar operation), your notification method (see [`iCal SET NOTIFICATION METHOD`](#ical-set-notification-method)) will start firing once per extra registration for every real change — i.e. twice after a second call, three times after a third, and so on. Check `.success` from an earlier call and skip re-requesting if you already know you're authorized.
- **All object-returning commands share two object shapes** — see [Object reference](#object-reference) below — rather than each command inventing its own. Read that section once; the per-command sections below just point back to it.
- **A command that resolves a calendar or event from your input (`.uid` / `.title`) silently does nothing if nothing matches** — you get back a plain `{success: false, errorMessage: "invalid calendar"}` / `"invalid event"`, not a 4D error you can trap with `ON ERR CALL`.

---

## Object reference

### Calendar object

| Property | Type | Description |
|---|---|---|
| `title` | Text | Calendar display name |
| `uid` | Text | `calendarIdentifier` — stable identifier, use this (not `title`) to unambiguously target a calendar in later calls |
| `color` | Integer | `0xRRGGBB`, or `0` if the calendar has no color |
| `type` | Text | One of `"Local"`, `"CalDAV"`, `"Exchange"`, `"Subscription"`, `"Birthday"`. Omitted if EventKit reports a type the plugin doesn't map (there is no IMAP calendar type in EventKit) |
| `subscribed` | Boolean | Read-only subscription flag |
| `immutable` | Boolean | Whether the calendar can be modified at all |
| `allowsContentModifications` | Boolean | Whether events can be added/changed on this calendar |

There is no `notes` field — EventKit doesn't expose notes on calendars.

### Event object

| Property | Type | Description |
|---|---|---|
| `uid` | Text | `calendarItemExternalIdentifier` — pass this back in `.uid` to target the event in later calls |
| `url` | Text | From `event.URL` |
| `occurrence` | Date | `occurrenceDate` — which occurrence this is, for a recurring event |
| `dateStamp` | Date | `lastModifiedDate` |
| `creationDate` | Date | |
| `timeZone` | Object or Null | `{name, abbreviation, daylightSavingTime: Boolean, daylightSavingTimeOffset: Real, secondsFromGMT: Real, nextDaylightSavingTimeTransition: Date}`, or `Null` if the event has no explicit time zone |
| `location` | Text | |
| `notes` | Text | |
| `title` | Text | |
| `startDate` / `endDate` | Date | |
| `isAllDay` | Boolean | |
| `isDetached` | Boolean | Whether this is a modified single occurrence of a recurring series |
| `calendar` | Object | The event's [Calendar object](#calendar-object) |
| `alarms` | Collection | Read-only. Each element: `{action: Text, emailAddress: Text, sound: Text, relativeTrigger: Real or Null, absoluteTrigger: Date}`. `action` is one of `"Sound"`, `"Display"`, `"Email"`, `"Procedure"`. There is no command to set alarms — only to read them. |
| `attendees` | Collection | Read-only. Each element: `{isCurrentUser: Boolean, role: Text, type: Text, status: Text, commonName: Text, address: Text}`. `role` is one of `"NonParticipant"`, `"Chair"`, `"Optional"`, `"Required"`, `"Unknown"`; `type` is one of `"Resource"`, `"Room"`, `"Person"`, `"Group"`, `"Unknown"`; `status` is one of `"Pending"`, `"Accepted"`, `"Declined"`, `"Tentative"`, `"Delegated"`, `"Completed"`, `"InProcess"`, `"Unknown"`. There is no command to set attendees. |
| `recurrenceRule` | Object | Present only if the event has a recurrence rule — see below. **Only the event's first recurrence rule is exposed**, even if EventKit has more than one attached. |

**`recurrenceRule` sub-object** (read and write shape — the same shape you pass in to `iCal Create event`/`iCal Set event property`'s `.recurrenceRule`, and the shape you get back from `iCal Get event property`):

| Property | Type | Description |
|---|---|---|
| `recurrenceType` | Integer | `0` Daily, `1` Weekly, `2` Monthly, `3` Yearly — matches `EKRecurrenceFrequency` |
| `recurrenceInterval` | Integer | e.g. `1` = every occurrence, `2` = every other. **Required for the rule to actually take effect** — see [Error handling](#error-handling--troubleshooting) |
| `firstDayOfTheWeek` | Integer | Read-only when reading back an event |
| `recurrenceEnd` | Object | `{endDate: Date, occurrenceCount: Integer}`. On write, set one or the other — if you set both, `occurrenceCount` wins |
| `daysOfTheWeek` | Collection of Integer | |
| `daysOfTheMonth` | Collection of Integer | |
| `monthsOfTheYear` | Collection of Integer | |
| `weeksOfTheYear` | Collection of Integer | |
| `daysOfTheYear` | Collection of Integer | |
| `setPositions` | Collection of Integer | |

> The exact semantics of `daysOfTheWeek` (ordinal weekday numbering, "2nd Tuesday" style positional rules via `setPositions`, etc.) follow Apple's `EKRecurrenceRule`/`EKRecurrenceDayOfWeek` model — check Apple's EventKit documentation for the precise value ranges per field; the plugin passes these through largely as-is, and the exact plumbing for `daysOfTheWeek` specifically is called out in [Error handling](#error-handling--troubleshooting) below.

### Error object

Set on `.error` whenever an underlying EventKit save/remove call fails with an `NSError` (as opposed to the plugin's own validation errors, which only set `.errorMessage`):

| Property | Type | Description |
|---|---|---|
| `code` | Integer | Native `NSError` code |
| `localizedDescription` | Text | |
| `localizedRecoverySuggestion` | Text | |

---

## iCal Request permission

### Syntax

```4d
$status:=iCal Request permission
```

| Parameter | Type | Description |
|---|---|---|
| Result | Object | `{success: Boolean, errorMessage: Text}` |

### Description

Requests Calendar access for the host app and, on success, lazily creates the shared `EKEventStore` and starts the background change-listener process used by [`iCal SET NOTIFICATION METHOD`](#ical-set-notification-method). Must be called (and must succeed) before any other command in this plugin will do anything — every other command checks the same internal permission flag first and short-circuits with `{success: false, errorMessage: "permission ..."}` if it isn't `authorized`.

Every other command in the plugin implicitly depends on this one having already succeeded in the current session — there is no separate "silent" permission check you can opt out of.

### Example

From the plugin's own test method (`TEST_001_Get_default_calendar.4dm`):

```4d
//%attributes = {"invisible":true}
$status:=iCal Request permission

If ($status.success)
	
	$status:=iCal Get default calendar
	
	If ($status.success)
		
		$calendar:=$status.calendar
		$sources:=$status.sources
		
	End if 
End if 
```

A minimal guard you can reuse at the top of any method that touches the calendar:

```4d
$status:=iCal Request permission
If (Not($status.success))
	ALERT:C41($status.errorMessage)
End if 
```

---

## iCal QUERY EVENT

### Syntax

```4d
$status:=iCal QUERY EVENT($options)
```

| Parameter | Type | Description |
|---|---|---|
| `options.startDate` | Date | Mandatory |
| `options.endDate` | Date | Mandatory |
| `options.calendars` | Collection | Optional. See Description |
| Result | Object | `{success: Boolean, events: Collection, errorMessage: Text}` |

### Description

Returns every event whose predicate window overlaps `startDate`..`endDate`, as a collection of [Event objects](#event-object).

`options.calendars`, if present, must be a collection of **objects**, each either:
- `{uid: "<calendarIdentifier>"}` — matched by exact identifier, or
- `{title: "<name>"}` — matched with a `LIKE` (wildcard) comparison against calendar titles; the first match is used.

**If every element in `options.calendars` fails to resolve to a real calendar, the filter is dropped entirely and the query searches all calendars** — an unresolvable filter does not mean "search nothing," it means "search everything." Omit `.calendars` entirely (rather than passing a list you're not sure will resolve) if you specifically want the default, all-calendars search.

Missing `startDate` or `endDate` returns `{success: false, errorMessage: "invalid startDate"}` / `"invalid endDate"` without querying at all.

Apple internally limits how far apart `startDate` and `endDate` can be for this kind of predicate (in practice, a few years) — very wide ranges may be silently clamped by EventKit rather than rejected by the plugin.

### Example

From the plugin's own sample method (`EKEventStoreChangedNotification.4dm`):

```4d
$options:=New object:C1471


$options.startDate:=Add to date:C393(Current date:C33; 0; 0; -1)
$options.endDate:=Add to date:C393(Current date:C33; 0; 0; 1)

/*
	optinally pass in $options.calendars
	a. collection of calendar names
	b. collection of objects where .uid == calendar ID
*/

$status:=iCal QUERY EVENT($options)

If ($status.success)
	
	$uid:=$status.events.extract("uid")
	
End if 
```

Restricting the search to one named calendar:

```4d
$options:=New object:C1471
$options.startDate:=Current date:C33
$options.endDate:=Add to date:C393(Current date:C33; 0; 1; 0)
$options.calendars:=New collection:C1472(New object:C1471("title"; "Work"))

$status:=iCal QUERY EVENT($options)
```

---

## iCal GET CALENDAR LIST

### Syntax

```4d
$status:=iCal GET CALENDAR LIST
```

| Parameter | Type | Description |
|---|---|---|
| Result | Object | `{success: Boolean, calendars: Collection}` |

### Description

Returns every calendar for entity type "event" (i.e. calendars, not reminder lists) as a collection of [Calendar objects](#calendar-object).

### Example

From the plugin's own test method (`TEST_005_event.4dm`):

```4d
$status:=iCal GET CALENDAR LIST

If ($status.success)
	$calendars:=$status.calendars
	$calendars:=$calendars.query("title == :1"; "販売")
End if 
```

---

## iCal Get default calendar

### Syntax

```4d
$status:=iCal Get default calendar
```

| Parameter | Type | Description |
|---|---|---|
| Result | Object | `{success: Boolean, calendar: Object, sources: Collection}` |

### Description

`calendar` is `defaultCalendarForNewEvents` as a [Calendar object](#calendar-object) — the calendar `iCal Create event` will use if you don't specify one explicitly (though the current `iCal Create event` implementation always requires `.calendar` — see that command).

`sources` is a collection of the EventKit sources (accounts) available to the store: `{uid: Text, title: Text, type: Text, isDelegate: Boolean}`, where `type` is one of `"Local"`, `"CalDAV"`, `"Exchange"`, `"Subscription"`, `"Birthday"`, `"MobileMe"`. `isDelegate` is only populated on macOS 13+; on earlier systems the key is simply absent.

### Example

From the plugin's own test method (`TEST_001_Get_default_calendar.4dm`):

```4d
$status:=iCal Request permission

If ($status.success)
	
	$status:=iCal Get default calendar
	
	If ($status.success)
		
		$calendar:=$status.calendar
		
		$sources:=$status.sources
		
		//"Local" and "Subscription" are constant types of uid
		
		$iCloud:=$sources.query("type == :1"; "CalDAV").extract("uid")  //iCloud
		$exchange:=$sources.query("type == :1"; "Exchange").extract("uid")
		
	End if 
End if 
```

---

## iCal Create calendar

### Syntax

```4d
$status:=iCal Create calendar($options)
```

| Parameter | Type | Description |
|---|---|---|
| `options.title` | Text | Optional. Calendar display name |
| `options.source` | Text | Optional. See Description |
| `options.color` | Integer | Optional. `0xRRGGBB` |
| Result | Object | `{success: Boolean, calendar: Object, errorMessage: Text}` on failure, `error: Object` on an EventKit-level failure |

### Description

Creates a new `EKCalendar` for entity type "event". Source (account) resolution, in order:

1. Exact match on `options.source` as a source identifier.
2. A source whose type or title matches `options.source` (the plugin's own test methods pass values like `"Exchange"` and `"CalDAV"` here — treat `.source` as the account's display name or kind rather than a raw identifier, and verify against your own `iCal Get default calendar` → `.sources` list if a value doesn't seem to match).
3. If nothing above resolves, falls back to the source with identifier `"Local"`.
4. If that still doesn't resolve, falls back to the first source of type Local found on the device.

If none of the four steps resolve to a source, `calendar.source` stays unset and the subsequent save will most likely fail with an `error` object rather than a plugin `errorMessage`.

### Example

From the plugin's own test method (`TEST_004_calendar_Local.4dm`):

```4d
//%attributes = {"invisible":true}
$status:=iCal Request permission

If ($status.success)
	
	$options:=New object:C1471("color"; 0x00FF0000)
	
	$options.title:="TEST_Local"
	
	$status:=iCal Create calendar($options)
	
	If ($status.success)
		
		$options:=$status.calendar
		
		$options.title:="TEST_Local_2"
		$options.color:=0x00FF
		
		$status:=iCal Set calendar property($options)
		$status:=iCal Get calendar property($options)
		
		If ($status.success)
			$status:=iCal Remove calendar($status.calendar)
		End if 
		
	End if 
	
End if 
```

Creating one under a specific account, from `TEST_002_calendar_Exchange.4dm`:

```4d
$options:=New object:C1471("color"; 0x00FF0000)

$options.title:="TEST_Exchange"
$options.source:="Exchange"

$status:=iCal Create calendar($options)
```

---

## iCal Set calendar property

### Syntax

```4d
$status:=iCal Set calendar property($options)
```

| Parameter | Type | Description |
|---|---|---|
| `options.uid` | Text | Identifies the calendar. Takes priority over `.title` if both are present |
| `options.title` | Text | Used to look up the calendar (via `LIKE`, first match) if `.uid` isn't given; also the new title to apply, if you're setting one |
| `options.color` | Integer | Optional. `0xRRGGBB`. Only applied if the key is present at all (an explicit `Null` still counts as "present" in the source's `ob_is_defined` check — pass a real integer if you want to change the color) |
| Result | Object | `{success: Boolean, calendar: Object, errorMessage: Text}` on failure, `error: Object` on an EventKit-level failure |

### Description

Because the same `.uid`/`.title` pair is used both to *find* the calendar and (for `.title`) to *set* its new value, the common pattern (see Example) is to take the `.calendar` object returned from a previous call and mutate `.title` directly on it before passing it back in — that way `.uid` still resolves the original calendar even though `.title` has changed.

Resolving by `.title` alone (no `.uid`) matches on the *current* title, so if you don't have the `.uid` handy, do the lookup before you change the title, not after.

### Example

From the plugin's own test method (`TEST_002_calendar_Exchange.4dm`):

```4d
$options:=$status.calendar

$options.title:="TEST_Exchange_2"
$options.color:=0x00FF

$status:=iCal Set calendar property($options)
```

---

## iCal Get calendar property

### Syntax

```4d
$status:=iCal Get calendar property($options)
```

| Parameter | Type | Description |
|---|---|---|
| `options.uid` | Text | Identifies the calendar. Takes priority over `.title` |
| `options.title` | Text | Used if `.uid` isn't given, via `LIKE`, first match |
| Result | Object | `{success: Boolean, calendar: Object, errorMessage: Text}` |

### Description

Read-only lookup — returns the current [Calendar object](#calendar-object) for the resolved calendar. `{success: false, errorMessage: "invalid calendar"}` if nothing resolves.

### Example

From the plugin's own test method (`TEST_002_calendar_Exchange.4dm`):

```4d
$status:=iCal Get calendar property($options)
```

---

## iCal Remove calendar

### Syntax

```4d
$status:=iCal Remove calendar($options)
```

| Parameter | Type | Description |
|---|---|---|
| `options.uid` | Text | Identifies the calendar. Takes priority over `.title` |
| `options.title` | Text | Used if `.uid` isn't given, via `LIKE`, first match |
| Result | Object | `{success: Boolean, errorMessage: Text}` on failure, `error: Object` on an EventKit-level failure |

### Description

Permanently deletes the resolved calendar and every event on it. There is no confirmation step or undo — that's entirely on your calling code if you want one.

### Example

From the plugin's own test method (`TEST_calendar_mod.4dm`):

```4d
//%attributes = {}
$status:=iCal Request permission

If ($status.success)
	
	$options:=New object:C1471("title"; "TEST3")
	
	$status:=iCal Remove calendar($options)
	
End if 
```

---

## iCal Create event

### Syntax

```4d
$status:=iCal Create event($options)
```

| Parameter | Type | Description |
|---|---|---|
| `options.calendar` | Object | Mandatory — a [Calendar object](#calendar-object) or `{uid: ...}`/`{title: ...}` identifying one |
| `options.startDate` / `options.endDate` | Date | Should be treated as mandatory — see Description |
| `options.title` / `options.location` / `options.notes` | Text | Optional |
| `options.isAllDay` | Boolean | Optional |
| `options.url` | Text | Optional. Must parse as a valid URL |
| `options.recurrenceRule` | Object | Optional — see [recurrenceRule sub-object](#event-object) |
| `options.span` | Text | Optional, `"future"` (default) or `"this"`. Not meaningful for a brand-new event (there's no prior occurrence to span from) but accepted |
| Result | Object | `{success: Boolean, event: Object, errorMessage: Text}` on failure, `error: Object` on an EventKit-level failure |

### Description

`options.calendar` is genuinely mandatory: omitting it returns `{success: false, errorMessage: "calendar option is missing"}`, and if it's present but doesn't resolve to a real calendar, `{success: false, errorMessage: "invalid calendar"}`.

`startDate`/`endDate` are checked and will set `errorMessage: "invalid startDate"` / `"invalid endDate"` if missing — **but this check does not actually stop the save.** If you omit them, the plugin still calls EventKit's save with whatever default start/end `EKEvent` assigns a freshly created event, and if that save succeeds, `.success` is set back to `true` immediately afterward, silently overwriting the earlier failure state. In practice: always pass both, and don't rely on getting a hard failure back if you forget one — check the returned `.event.startDate`/`.endDate` against what you expected if you're ever unsure.

See [Error handling](#error-handling--troubleshooting) for a caveat on `recurrenceRule.recurrenceInterval` and `recurrenceRule.daysOfTheWeek`.

### Example

From the plugin's own test method (`TEST_005_event.4dm`):

```4d
$status:=iCal Get default calendar

If ($status.success)
	
	$calendar:=$status.calendar
	
	$options:=New object:C1471
	$options.calendar:=$calendar
	$options.title:="TEST EVENT"
	$options.startDate:=Current date:C33
	$options.endDate:=Current date:C33+1
	$options.isAllDay:=True:C214
	
	$options.recurrenceRule:=New object:C1471
	$options.recurrenceRule.recurrenceType:=0  //Daily
	$options.recurrenceRule.recurrenceInterval:=1  //every day
	$options.recurrenceRule.recurrenceEnd:=New object:C1471
	$options.recurrenceRule.recurrenceEnd.occurrenceCount:=3
	
	$status:=iCal Create event($options)
	
End if 
```

---

## iCal Set event property

### Syntax

```4d
$status:=iCal Set event property($options)
```

| Parameter | Type | Description |
|---|---|---|
| `options.uid` | Text | Mandatory — identifies the event to modify |
| `options.calendar` | Object | Optional — moves the event to a different calendar if it resolves |
| `options.startDate` / `options.endDate` | Date | See caveat under [iCal Create event](#ical-create-event) — same silent-fallback behavior applies here |
| `options.title` / `options.location` / `options.notes` / `options.isAllDay` / `options.url` / `options.recurrenceRule` | — | Same as [iCal Create event](#ical-create-event) |
| `options.span` | Text | Optional, `"future"` (default) or `"this"` — controls whether the change applies to this occurrence only or this-and-future occurrences of a recurring event |
| Result | Object | `{success: Boolean, event: Object, errorMessage: Text}` on failure, `error: Object` on an EventKit-level failure |

### Description

Only fields you actually include are changed; omitted fields keep their existing value. There's no way to *clear* `title`/`location`/`notes` back to empty through this command — the code only assigns them when the incoming value is non-empty.

Setting `options.recurrenceRule` **replaces** the event's existing recurrence rule (removing the previous one first) if you provide one. Omitting `.recurrenceRule` entirely leaves an existing rule untouched.

### Example

From the plugin's own test method (`TEST_event_mod.4dm`):

```4d
//%attributes = {}
$options:=New object:C1471("uid"; "6FE5DB91-4D0F-496C-8E02-CC4D108FD838")
$status:=iCal Get event property($options)

$options.recurrenceRule:=New object:C1471("recurrenceInterval"; 1; "recurrenceType"; 1)
//0:Daily, 1:Weekly, 2:Monthly, 3:Yearly
$status:=iCal Set event property($options)
```

---

## iCal Get event property

### Syntax

```4d
$status:=iCal Get event property($options)
```

| Parameter | Type | Description |
|---|---|---|
| `options.uid` | Text | Mandatory |
| `options.occurrence` | — | Accepted as an input key but read as part of the general options lookup; pass `Null:C1517` if you don't need a specific occurrence, per the plugin's own test code |
| Result | Object | `{success: Boolean, event: Object, errorMessage: Text}` |

### Description

Read-only. Returns the full [Event object](#event-object), including `alarms`, `attendees`, and `recurrenceRule` if present. `{success: false, errorMessage: "invalid event"}` if `.uid` doesn't resolve to a real event.

### Example

From the plugin's own test method (`TEST_get_prop.4dm`):

```4d
//%attributes = {}
$status:=iCal Request permission

If ($status.success)
	
	$event:=New object:C1471
	
	$event.uid:="21B79F41-309B-4A7E-9BBF-291C950A8ED0"
	$event.occurrence:=Null:C1517
	
	$status:=iCal Get event property($event)
	//property added in v4: URIRepresentation (CoreData ObjectID)
	
End if 
```

Chaining straight off a create, from `TEST_event.4dm`:

```4d
$status:=iCal Create event($options)

If ($status.success)
	$status:=iCal Get event property($status.event)
End if 
```

---

## iCal Remove event

### Syntax

```4d
$status:=iCal Remove event($options)
```

| Parameter | Type | Description |
|---|---|---|
| `options.uid` | Text | Mandatory |
| `options.span` | Text | Optional, `"future"` (default) or `"this"` |
| Result | Object | `{success: Boolean, errorMessage: Text}` on failure, `error: Object` on an EventKit-level failure |

### Description

`{success: false, errorMessage: "invalid event"}` if `.uid` doesn't resolve. For a recurring event, `.span` controls whether the whole future series is removed or only the targeted occurrence.

### Example

```4d
$options:=New object:C1471("uid"; $eventUid; "span"; "this")
$status:=iCal Remove event($options)
```

---

## iCal SET NOTIFICATION METHOD

### Syntax

```4d
iCal SET NOTIFICATION METHOD($methodName)
```

| Parameter | Type | Description |
|---|---|---|
| `$methodName` | Text | Name of a 4D method to call whenever the Calendar database changes. Pass an empty string to stop calling any method |
| Result | — | No return value |

### Description

Registers which 4D method gets invoked for every `EKEventStoreChangedNotification` the OS posts. **The method is called with no parameters and receives no information about what changed** — not which event, not which calendar, not what kind of change. If you need to know what's new, re-run [`iCal QUERY EVENT`](#ical-query-event) (or your own tracking) from inside the callback and diff against what you already have.

The registration itself is not thread-safe (it's the one command in the manifest marked `threadSafe: false`) — set it once, typically right after a successful `iCal Request permission`, rather than from multiple concurrent processes.

Setting this only changes which method gets called; it does not itself start or stop the underlying OS-level listener (see [`iCal KILL WORKER`](#ical-kill-worker)).

### Example

From the plugin's own test method (`TEST_006_notification.4dm`):

```4d
//%attributes = {}
$status:=iCal Request permission

If ($status.success)
	
	iCal SET NOTIFICATION METHOD("EKEventStoreChangedNotification")
	$method:=iCal Get notification method
	
End if 
```

The registered method itself, from the plugin's own sample (`EKEventStoreChangedNotification.4dm`):

```4d
//%attributes = {}
/*

callback receives no parameters

*/

$options:=New object:C1471


$options.startDate:=Add to date:C393(Current date:C33; 0; 0; -1)
$options.endDate:=Add to date:C393(Current date:C33; 0; 0; 1)

/*
optinally pass in $options.calendars
a. collection of calendar names
b. collection of objects where .uid == calendar ID
*/

$status:=iCal QUERY EVENT($options)

If ($status.success)
	
	$uid:=$status.events.extract("uid")
	
End if 
```

---

## iCal Get notification method

### Syntax

```4d
$method:=iCal Get notification method
```

| Parameter | Type | Description |
|---|---|---|
| Result | Text | The method name currently registered via `iCal SET NOTIFICATION METHOD`, or an empty string if none is set |

### Description

Simple readback of the current registration; doesn't tell you whether the underlying listener process is actually running (see [`iCal KILL WORKER`](#ical-kill-worker)).

### Example

From the plugin's own test method (`TEST_006_notification.4dm`):

```4d
iCal SET NOTIFICATION METHOD("EKEventStoreChangedNotification")
$method:=iCal Get notification method
```

---

## iCal KILL WORKER

### Syntax

```4d
iCal KILL WORKER
```

| Parameter | Type | Description |
|---|---|---|
| Result | — | No return value |

### Description

Stops the background monitor process that listens for `EKEventStoreChangedNotification` and releases the plugin's shared `EKEventStore`. After this call, your registered notification method (if any) stops firing entirely — this is a hard stop, not a pause.

The listener is only ever (re-)started from inside `iCal Request permission` (when permission is already/newly `authorized`) or automatically once when the plugin/host app starts up. Calling `iCal KILL WORKER` and later wanting notifications again means calling `iCal Request permission` again — keeping in mind the re-registration caveat under [Requirements & platform notes](#requirements--platform-notes).

Other calendar/event commands still work after `iCal KILL WORKER` — they lazily recreate the underlying `EKEventStore` on demand. It's specifically the change-notification path that stays off.

### Example

From the plugin's own test method (`TEST_007_kill_notification.4dm`):

```4d
//%attributes = {}
iCal KILL WORKER
```

---

## Error handling & troubleshooting

- **"permission not determined" on the very first call isn't a real failure.** It means the system permission dialog is still up (or was just dismissed) — see [Requirements & platform notes](#requirements--platform-notes). Retry `iCal Request permission` rather than treating this as terminal.
- **`NSCalendarsUsageDescription` and the calendars entitlement are checked before EventKit is even asked.** You'll see one of these specific messages if either is missing: `"NScalendarUsageDescription is missing in app info.plist"` (note: despite the message text, the actual `Info.plist` key to add is `NSCalendarsUsageDescription`), `"com.apple.security.personal-information.calendars is missing in app entitlement"`, or `"com.apple.security.personal-information.calendars is set to false in app entitlement"`.
- **Calling `iCal Request permission` repeatedly while already authorized duplicates your notification callback.** See [Requirements & platform notes](#requirements--platform-notes) — each extra call re-registers the change observer without removing the previous one.
- **An unresolvable `.calendars` filter in `iCal QUERY EVENT` searches everything, not nothing.** If every element you pass fails to resolve to a real calendar, the plugin falls back to searching all calendars rather than returning an empty result.
- **Missing `startDate`/`endDate` on `iCal Create event` / `iCal Set event property` doesn't reliably block the save.** The plugin flags `errorMessage: "invalid startDate"`/`"invalid endDate"` internally, but if the underlying EventKit save still succeeds (using whatever default dates a freshly created `EKEvent` gets), `.success` is set back to `true` right afterward and the earlier error is lost. Always pass both dates explicitly.
- **`recurrenceRule.recurrenceInterval` should always be set explicitly.** If you omit it, it defaults to `0`; `EKRecurrenceRule` generally expects an interval of `1` or more, and a `0` interval may cause rule creation to fail silently (no recurrence gets attached, with no error surfaced back to you).
- **Recurrence by specific weekday (`recurrenceRule.daysOfTheWeek`) may not behave as expected.** The plugin builds this field from plain integers, while EventKit's `EKRecurrenceRule` API for this parameter expects `EKRecurrenceDayOfWeek` objects rather than raw numbers. Test this specific field carefully before relying on it in production — `recurrenceType`/`recurrenceInterval`/`recurrenceEnd` alone (daily/weekly/monthly/yearly with a plain interval) are the parts of the recurrence API exercised by the plugin's own test suite.
- **`iCal Set calendar property` / `iCal Get calendar property` / `iCal Remove calendar` resolve by `.uid` first, `.title` second.** If you pass both, `.uid` wins; if you only have `.title`, the match is a `LIKE` comparison against the calendar's *current* title and only the first match is used — prefer resolving and storing `.uid` once you have it.
- **`iCal Create calendar`'s `.source` matching is best-effort.** Pass the account's display name (e.g. `"iCloud"`, `"Exchange"`) as seen in `iCal Get default calendar`'s `.sources` list; if nothing matches, the calendar quietly falls back to a Local source rather than failing outright.
- **A failed save/remove against EventKit itself (as opposed to a plugin-side validation failure) sets `.error`, not just `.errorMessage`.** Check `.error.localizedDescription` for the underlying reason (e.g. a CalDAV/Exchange server rejecting the write).
- **All calendar/event commands are macOS-only** and depend on the Calendar app's underlying accounts (System Settings → Internet Accounts / Calendar) being configured — there's nothing the plugin can do if no calendar source is configured at all beyond the built-in Local source.

---

## Quick reference

```4d
// One-time setup
$status:=iCal Request permission
If (Not($status.success))
	 //handle $status.errorMessage
End if 

// Query
$options:=New object:C1471
$options.startDate:=Current date:C33
$options.endDate:=Add to date:C393(Current date:C33; 0; 1; 0)
$status:=iCal QUERY EVENT($options)
$events:=$status.events

// Create calendar → create event → read back
$status:=iCal Create calendar(New object:C1471("title"; "My Calendar"))
$calendar:=$status.calendar

$options:=New object:C1471
$options.calendar:=$calendar
$options.title:="Meeting"
$options.startDate:=Current date:C33
$options.endDate:=Current date:C33+1
$status:=iCal Create event($options)
$event:=$status.event

$status:=iCal Get event property(New object:C1471("uid"; $event.uid))

// Notifications
iCal SET NOTIFICATION METHOD("My_Calendar_Changed_Method")
	 //...
iCal KILL WORKER  //hard stop; call iCal Request permission again to resume
```
