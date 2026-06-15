# Complete Function Reference

This expanded reference documents every function in `MiraQueue.ps1`. Each entry explains where the function sits in the backup workflow, what state it depends on, what it may change, how it fails safely, and why it exists as a separate unit.

Total functions documented: 156.

### Expand-TextPath

- **Lines:** 34-39
- **Area:** Path, pair, drive map, and exclusion handling
- **Primary role:** Expands environment variables in user-facing paths before the rest of the script treats them as concrete filesystem locations.

`Expand-TextPath` belongs to the **Path, pair, drive map, and exclusion handling** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on configured pairs, drive maps, exclusion maps, and path text supplied by the user or file system events.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Path`. The output is either updated state, a small helper value, or no direct return value depending on caller context.

Side effects are intentionally bounded. It is expected to be side-effect-light and primarily returns data or decisions to the caller. The important failure mode is pointing at the wrong folder. Path helpers centralize normalization and destination resolution so previews and applies use the same interpretation.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Expand-TextPath` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** adding pairs, resolving destinations, drive maps, and exclusions.
- **Dependency notes:** No notable internal function calls were detected in this function body.

### New-DefaultConfig

- **Lines:** 40-82
- **Area:** Configuration and settings
- **Primary role:** Defines the canonical V1.0.0 configuration shape, including runtime names, safety defaults, robocopy tuning, exclusions, drive maps, and backup pairs.

`New-DefaultConfig` belongs to the **Configuration and settings** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It mainly depends on `$script:Config`, `$script:ConfigPath`, and the default config shape. When it writes data, the write is intentional configuration persistence.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. No explicit function parameters; it reads from script-scoped state or acts as an internal workflow step. The caller expects a derived object, string, number, or collection and should not need to know how it was produced.

Side effects are intentionally bounded. It is expected to be side-effect-light and primarily returns data or decisions to the caller. The important failure mode is invalid or incomplete configuration. The surrounding workflow either repairs missing shape or reports malformed JSON instead of guessing.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `New-DefaultConfig` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** first run, config repair, settings edits, and watcher refresh.
- **Dependency notes:** No notable internal function calls were detected in this function body.

### Save-Config

- **Lines:** 83-94
- **Area:** Configuration and settings
- **Primary role:** Persists the in-memory configuration and then asks any installed watcher to reload the new state.

`Save-Config` belongs to the **Configuration and settings** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It mainly depends on `$script:Config`, `$script:ConfigPath`, and the default config shape. When it writes data, the write is intentional configuration persistence.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. No explicit function parameters; it reads from script-scoped state or acts as an internal workflow step. The output is either updated state, a small helper value, or no direct return value depending on caller context.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is invalid or incomplete configuration. The surrounding workflow either repairs missing shape or reports malformed JSON instead of guessing.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Save-Config` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** first run, config repair, settings edits, and watcher refresh.
- **Dependency notes:** Notable internal calls: `Refresh-WatcherAfterConfigChange`, `Ensure-AllPairExclusionKeys`, `Write-Color`, `Write-Log`.

### Refresh-WatcherAfterConfigChange

- **Lines:** 95-122
- **Area:** Configuration and settings
- **Primary role:** Coordinates watcher restart after config edits so changed paths or settings are picked up without asking the user to find the process manually.

`Refresh-WatcherAfterConfigChange` belongs to the **Configuration and settings** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It mainly depends on `$script:Config`, `$script:ConfigPath`, and the default config shape. When it writes data, the write is intentional configuration persistence.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. No explicit function parameters; it reads from script-scoped state or acts as an internal workflow step. The output is either updated state, a small helper value, or no direct return value depending on caller context.

Side effects are intentionally bounded. It is expected to be side-effect-light and primarily returns data or decisions to the caller. The important failure mode is invalid or incomplete configuration. The surrounding workflow either repairs missing shape or reports malformed JSON instead of guessing.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Refresh-WatcherAfterConfigChange` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** first run, config repair, settings edits, and watcher refresh.
- **Dependency notes:** Notable internal calls: `Wait-ScheduledTaskNotRunning`, `Wait-ScheduledWatcherStarted`, `Write-Color`, `Write-Log`, `Stop-KnownWatcherProcesses`, `Get-WatcherProcesses`.

### Wait-ScheduledTaskNotRunning

- **Lines:** 123-137
- **Area:** Installation, scheduled task, and process lifecycle
- **Primary role:** Provides the w ai t s ch ed ul ed ta sk no tr un ni ng helper behavior used by nearby workflows.

`Wait-ScheduledTaskNotRunning` belongs to the **Installation, scheduled task, and process lifecycle** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on administrator rights, Task Scheduler cmdlets, watcher process discovery, runtime helper paths, and the configured task name.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `TaskName`, `Attempts`, `DelayMs`. The output is either updated state, a small helper value, or no direct return value depending on caller context.

Side effects are intentionally bounded. It is expected to be side-effect-light and primarily returns data or decisions to the caller. The important failure mode is leaving background tasks or processes behind. Lifecycle helpers isolate task registration, restart, removal, and runtime cleanup.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Wait-ScheduledTaskNotRunning` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** install, restart, remove watcher, uninstall, elevation, and background process checks.
- **Dependency notes:** No notable internal function calls were detected in this function body.

### Wait-ScheduledWatcherStarted

- **Lines:** 138-153
- **Area:** Watcher lifecycle and file system events
- **Primary role:** Provides the w ai t s ch ed ul ed wa tc he rs ta rt ed helper behavior used by nearby workflows.

`Wait-ScheduledWatcherStarted` belongs to the **Watcher lifecycle and file system events** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on configured pairs, FileSystemWatcher events, debounce timing, exclusions, and the watcher mutex.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `TaskName`, `Attempts`, `DelayMs`. The output is either updated state, a small helper value, or no direct return value depending on caller context.

Side effects are intentionally bounded. It may participate in long-running watcher state, but the watcher contract remains queue-only: it records work and does not apply file changes. The important failure mode is event bursts or missed nested directory events. Debounce buffering and directory snapshots reduce that risk.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Wait-ScheduledWatcherStarted` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** manual or scheduled watch mode, created/changed/deleted/renamed events, and directory snapshots.
- **Dependency notes:** Notable internal calls: `Get-WatcherProcesses`.

### Initialize-App

- **Lines:** 154-193
- **Area:** Shared core helper
- **Primary role:** Bootstraps the application by loading or creating config, repairing shape, resolving runtime files, and preparing queue/log storage.

`Initialize-App` belongs to the **Shared core helper** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on explicit parameters and script-scoped state supplied indirectly by the caller.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. No explicit function parameters; it reads from script-scoped state or acts as an internal workflow step. The output is either updated state, a small helper value, or no direct return value depending on caller context.

Side effects are intentionally bounded. It is expected to be side-effect-light and primarily returns data or decisions to the caller. The important failure mode is inconsistent behavior across callers, so this helper keeps one rule in one place.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Initialize-App` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** shared workflow support across the script.
- **Dependency notes:** Notable internal calls: `Expand-TextPath`, `New-DefaultConfig`, `Ensure-ConfigShape`, `Rotate-LogIfNeeded`.

### Ensure-ConfigShape

- **Lines:** 194-207
- **Area:** Configuration and settings
- **Primary role:** Provides the e ns ur e c on fi gs ha pe helper behavior used by nearby workflows.

`Ensure-ConfigShape` belongs to the **Configuration and settings** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It mainly depends on `$script:Config`, `$script:ConfigPath`, and the default config shape. When it writes data, the write is intentional configuration persistence.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. No explicit function parameters; it reads from script-scoped state or acts as an internal workflow step. The output is either updated state, a small helper value, or no direct return value depending on caller context.

Side effects are intentionally bounded. It is expected to be side-effect-light and primarily returns data or decisions to the caller. The important failure mode is invalid or incomplete configuration. The surrounding workflow either repairs missing shape or reports malformed JSON instead of guessing.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Ensure-ConfigShape` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** first run, config repair, settings edits, and watcher refresh.
- **Dependency notes:** Notable internal calls: `New-DefaultConfig`, `Ensure-AllPairExclusionKeys`.

### Get-Array

- **Lines:** 208-216
- **Area:** Configuration and settings
- **Primary role:** Calculates or formats g et a rr ay data for callers that need a stable value instead of duplicating the logic.

`Get-Array` belongs to the **Configuration and settings** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It mainly depends on `$script:Config`, `$script:ConfigPath`, and the default config shape. When it writes data, the write is intentional configuration persistence.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Value`. The caller expects a derived object, string, number, or collection and should not need to know how it was produced.

Side effects are intentionally bounded. It is expected to be side-effect-light and primarily returns data or decisions to the caller. The important failure mode is invalid or incomplete configuration. The surrounding workflow either repairs missing shape or reports malformed JSON instead of guessing.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Get-Array` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** first run, config repair, settings edits, and watcher refresh.
- **Dependency notes:** No notable internal function calls were detected in this function body.

### Get-Pairs

- **Lines:** 217-220
- **Area:** Path, pair, drive map, and exclusion handling
- **Primary role:** Calculates or formats g et p ai rs data for callers that need a stable value instead of duplicating the logic.

`Get-Pairs` belongs to the **Path, pair, drive map, and exclusion handling** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on configured pairs, drive maps, exclusion maps, and path text supplied by the user or file system events.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. No explicit function parameters; it reads from script-scoped state or acts as an internal workflow step. The caller expects a derived object, string, number, or collection and should not need to know how it was produced.

Side effects are intentionally bounded. It is expected to be side-effect-light and primarily returns data or decisions to the caller. The important failure mode is pointing at the wrong folder. Path helpers centralize normalization and destination resolution so previews and applies use the same interpretation.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Get-Pairs` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** adding pairs, resolving destinations, drive maps, and exclusions.
- **Dependency notes:** Notable internal calls: `Get-Array`.

### Set-Pairs

- **Lines:** 221-226
- **Area:** Path, pair, drive map, and exclusion handling
- **Primary role:** Mutates the s et p ai rs state in one named place so the rest of the script does not duplicate update rules.

`Set-Pairs` belongs to the **Path, pair, drive map, and exclusion handling** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on configured pairs, drive maps, exclusion maps, and path text supplied by the user or file system events.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Pairs`. The output is either updated state, a small helper value, or no direct return value depending on caller context.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is pointing at the wrong folder. Path helpers centralize normalization and destination resolution so previews and applies use the same interpretation.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Set-Pairs` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** adding pairs, resolving destinations, drive maps, and exclusions.
- **Dependency notes:** Notable internal calls: `Ensure-AllPairExclusionKeys`.

### Get-MapArray

- **Lines:** 227-235
- **Area:** Configuration and settings
- **Primary role:** Calculates or formats g et m ap ar ra y data for callers that need a stable value instead of duplicating the logic.

`Get-MapArray` belongs to the **Configuration and settings** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It mainly depends on `$script:Config`, `$script:ConfigPath`, and the default config shape. When it writes data, the write is intentional configuration persistence.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `MapName`, `Key`. The caller expects a derived object, string, number, or collection and should not need to know how it was produced.

Side effects are intentionally bounded. It is expected to be side-effect-light and primarily returns data or decisions to the caller. The important failure mode is invalid or incomplete configuration. The surrounding workflow either repairs missing shape or reports malformed JSON instead of guessing.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Get-MapArray` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** first run, config repair, settings edits, and watcher refresh.
- **Dependency notes:** Notable internal calls: `Get-Array`.

### Set-MapArray

- **Lines:** 236-245
- **Area:** Configuration and settings
- **Primary role:** Mutates the s et m ap ar ra y state in one named place so the rest of the script does not duplicate update rules.

`Set-MapArray` belongs to the **Configuration and settings** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It mainly depends on `$script:Config`, `$script:ConfigPath`, and the default config shape. When it writes data, the write is intentional configuration persistence.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `MapName`, `Key`, `Values`. The output is either updated state, a small helper value, or no direct return value depending on caller context.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is invalid or incomplete configuration. The surrounding workflow either repairs missing shape or reports malformed JSON instead of guessing.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Set-MapArray` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** first run, config repair, settings edits, and watcher refresh.
- **Dependency notes:** No notable internal function calls were detected in this function body.

### Ensure-AllPairExclusionKeys

- **Lines:** 246-257
- **Area:** Path, pair, drive map, and exclusion handling
- **Primary role:** Provides the e ns ur e a ll pa ir ex cl us io nk ey s helper behavior used by nearby workflows.

`Ensure-AllPairExclusionKeys` belongs to the **Path, pair, drive map, and exclusion handling** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on configured pairs, drive maps, exclusion maps, and path text supplied by the user or file system events.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. No explicit function parameters; it reads from script-scoped state or acts as an internal workflow step. The output is either updated state, a small helper value, or no direct return value depending on caller context.

Side effects are intentionally bounded. It is expected to be side-effect-light and primarily returns data or decisions to the caller. The important failure mode is pointing at the wrong folder. Path helpers centralize normalization and destination resolution so previews and applies use the same interpretation.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Ensure-AllPairExclusionKeys` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** adding pairs, resolving destinations, drive maps, and exclusions.
- **Dependency notes:** Notable internal calls: `Get-Pairs`, `Set-MapArray`.

### Write-Color

- **Lines:** 258-263
- **Area:** Console interface and progress display
- **Primary role:** Provides the w ri te c ol or helper behavior used by nearby workflows.

`Write-Color` belongs to the **Console interface and progress display** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on console dimensions, color output, and transient display state. It should not change backup data unless it delegates after user input.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Text`, `Color`, `NoNewLine`. The main output is console presentation. Any return value is secondary to navigation or display.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is poor readability or accidental selection. The UI helpers keep fixed prompts, Escape handling, and compact tables to reduce that risk.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Write-Color` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** interactive menus, previews, progress display, and user cancellation.
- **Dependency notes:** No notable internal function calls were detected in this function body.

### Write-Log

- **Lines:** 264-273
- **Area:** Shared core helper
- **Primary role:** Provides the w ri te l og helper behavior used by nearby workflows.

`Write-Log` belongs to the **Shared core helper** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on explicit parameters and script-scoped state supplied indirectly by the caller.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Level`, `Message`. The main output is console presentation. Any return value is secondary to navigation or display.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is inconsistent behavior across callers, so this helper keeps one rule in one place.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Write-Log` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** shared workflow support across the script.
- **Dependency notes:** Notable internal calls: `Rotate-LogIfNeeded`.

### Rotate-LogIfNeeded

- **Lines:** 274-292
- **Area:** Shared core helper
- **Primary role:** Provides the r ot at e l og if ne ed ed helper behavior used by nearby workflows.

`Rotate-LogIfNeeded` belongs to the **Shared core helper** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on explicit parameters and script-scoped state supplied indirectly by the caller.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. No explicit function parameters; it reads from script-scoped state or acts as an internal workflow step. The output is either updated state, a small helper value, or no direct return value depending on caller context.

Side effects are intentionally bounded. It is expected to be side-effect-light and primarily returns data or decisions to the caller. The important failure mode is inconsistent behavior across callers, so this helper keeps one rule in one place.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Rotate-LogIfNeeded` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** shared workflow support across the script.
- **Dependency notes:** No notable internal function calls were detected in this function body.

### Clear-Screen

- **Lines:** 293-296
- **Area:** Console interface and progress display
- **Primary role:** Mutates the c le ar s cr ee n state in one named place so the rest of the script does not duplicate update rules.

`Clear-Screen` belongs to the **Console interface and progress display** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on console dimensions, color output, and transient display state. It should not change backup data unless it delegates after user input.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. No explicit function parameters; it reads from script-scoped state or acts as an internal workflow step. The output is either updated state, a small helper value, or no direct return value depending on caller context.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is poor readability or accidental selection. The UI helpers keep fixed prompts, Escape handling, and compact tables to reduce that risk.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Clear-Screen` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** interactive menus, previews, progress display, and user cancellation.
- **Dependency notes:** No notable internal function calls were detected in this function body.

### Center-Text

- **Lines:** 297-304
- **Area:** Console interface and progress display
- **Primary role:** Provides the c en te r t ex t helper behavior used by nearby workflows.

`Center-Text` belongs to the **Console interface and progress display** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on console dimensions, color output, and transient display state. It should not change backup data unless it delegates after user input.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Text`, `Width`. The output is either updated state, a small helper value, or no direct return value depending on caller context.

Side effects are intentionally bounded. It is expected to be side-effect-light and primarily returns data or decisions to the caller. The important failure mode is poor readability or accidental selection. The UI helpers keep fixed prompts, Escape handling, and compact tables to reduce that risk.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Center-Text` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** interactive menus, previews, progress display, and user cancellation.
- **Dependency notes:** No notable internal function calls were detected in this function body.

### Fit-Cell

- **Lines:** 305-312
- **Area:** Console interface and progress display
- **Primary role:** Provides the f it c el l helper behavior used by nearby workflows.

`Fit-Cell` belongs to the **Console interface and progress display** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on console dimensions, color output, and transient display state. It should not change backup data unless it delegates after user input.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Text`, `Width`. The output is either updated state, a small helper value, or no direct return value depending on caller context.

Side effects are intentionally bounded. It is expected to be side-effect-light and primarily returns data or decisions to the caller. The important failure mode is poor readability or accidental selection. The UI helpers keep fixed prompts, Escape handling, and compact tables to reduce that risk.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Fit-Cell` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** interactive menus, previews, progress display, and user cancellation.
- **Dependency notes:** No notable internal function calls were detected in this function body.

### Write-BoxHeader

- **Lines:** 313-327
- **Area:** Console interface and progress display
- **Primary role:** Provides the w ri te b ox he ad er helper behavior used by nearby workflows.

`Write-BoxHeader` belongs to the **Console interface and progress display** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on console dimensions, color output, and transient display state. It should not change backup data unless it delegates after user input.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Title`, `Subtitle`. The main output is console presentation. Any return value is secondary to navigation or display.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is poor readability or accidental selection. The UI helpers keep fixed prompts, Escape handling, and compact tables to reduce that risk.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Write-BoxHeader` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** interactive menus, previews, progress display, and user cancellation.
- **Dependency notes:** Notable internal calls: `Write-Color`, `Center-Text`.

### Show-Header

- **Lines:** 328-334
- **Area:** Console interface and progress display
- **Primary role:** Presents the s ho w h ea de r screen or menu and keeps display concerns separate from lower-level operations.

`Show-Header` belongs to the **Console interface and progress display** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on console dimensions, color output, and transient display state. It should not change backup data unless it delegates after user input.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Title`, `Subtitle`. The main output is console presentation. Any return value is secondary to navigation or display.

Side effects are intentionally bounded. Its side effect is user interaction: console output, cursor movement, or waiting for input. It should not silently perform backup changes by itself. The important failure mode is poor readability or accidental selection. The UI helpers keep fixed prompts, Escape handling, and compact tables to reduce that risk.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Show-Header` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** interactive menus, previews, progress display, and user cancellation.
- **Dependency notes:** Notable internal calls: `Clear-Screen`, `Write-BoxHeader`.

### Show-SpinnerLine

- **Lines:** 335-344
- **Area:** Console interface and progress display
- **Primary role:** Presents the s ho w s pi nn er li ne screen or menu and keeps display concerns separate from lower-level operations.

`Show-SpinnerLine` belongs to the **Console interface and progress display** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on console dimensions, color output, and transient display state. It should not change backup data unless it delegates after user input.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Text`, `Cycles`. The main output is console presentation. Any return value is secondary to navigation or display.

Side effects are intentionally bounded. Its side effect is user interaction: console output, cursor movement, or waiting for input. It should not silently perform backup changes by itself. The important failure mode is poor readability or accidental selection. The UI helpers keep fixed prompts, Escape handling, and compact tables to reduce that risk.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Show-SpinnerLine` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** interactive menus, previews, progress display, and user cancellation.
- **Dependency notes:** No notable internal function calls were detected in this function body.

### Get-ConsoleWidthSafe

- **Lines:** 345-356
- **Area:** Console interface and progress display
- **Primary role:** Calculates or formats g et c on so le wi dt hs af e data for callers that need a stable value instead of duplicating the logic.

`Get-ConsoleWidthSafe` belongs to the **Console interface and progress display** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on console dimensions, color output, and transient display state. It should not change backup data unless it delegates after user input.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. No explicit function parameters; it reads from script-scoped state or acts as an internal workflow step. The caller expects a derived object, string, number, or collection and should not need to know how it was produced.

Side effects are intentionally bounded. It is expected to be side-effect-light and primarily returns data or decisions to the caller. The important failure mode is poor readability or accidental selection. The UI helpers keep fixed prompts, Escape handling, and compact tables to reduce that risk.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Get-ConsoleWidthSafe` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** interactive menus, previews, progress display, and user cancellation.
- **Dependency notes:** No notable internal function calls were detected in this function body.

### Format-ByteSize

- **Lines:** 357-372
- **Area:** Shared core helper
- **Primary role:** Calculates or formats f or ma t b yt es iz e data for callers that need a stable value instead of duplicating the logic.

`Format-ByteSize` belongs to the **Shared core helper** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on explicit parameters and script-scoped state supplied indirectly by the caller.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Bytes`. The caller expects a derived object, string, number, or collection and should not need to know how it was produced.

Side effects are intentionally bounded. It is expected to be side-effect-light and primarily returns data or decisions to the caller. The important failure mode is inconsistent behavior across callers, so this helper keeps one rule in one place.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Format-ByteSize` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** shared workflow support across the script.
- **Dependency notes:** No notable internal function calls were detected in this function body.

### Format-ByteSpeed

- **Lines:** 373-378
- **Area:** Shared core helper
- **Primary role:** Calculates or formats f or ma t b yt es pe ed data for callers that need a stable value instead of duplicating the logic.

`Format-ByteSpeed` belongs to the **Shared core helper** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on explicit parameters and script-scoped state supplied indirectly by the caller.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `BytesPerSecond`. The caller expects a derived object, string, number, or collection and should not need to know how it was produced.

Side effects are intentionally bounded. It is expected to be side-effect-light and primarily returns data or decisions to the caller. The important failure mode is inconsistent behavior across callers, so this helper keeps one rule in one place.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Format-ByteSpeed` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** shared workflow support across the script.
- **Dependency notes:** Notable internal calls: `Format-ByteSize`.

### Format-CompactDuration

- **Lines:** 379-387
- **Area:** Shared core helper
- **Primary role:** Calculates or formats f or ma t c om pa ct du ra ti on data for callers that need a stable value instead of duplicating the logic.

`Format-CompactDuration` belongs to the **Shared core helper** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on explicit parameters and script-scoped state supplied indirectly by the caller.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Seconds`. The caller expects a derived object, string, number, or collection and should not need to know how it was produced.

Side effects are intentionally bounded. It is expected to be side-effect-light and primarily returns data or decisions to the caller. The important failure mode is inconsistent behavior across callers, so this helper keeps one rule in one place.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Format-CompactDuration` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** shared workflow support across the script.
- **Dependency notes:** No notable internal function calls were detected in this function body.

### Format-ApplyProgressBar

- **Lines:** 388-398
- **Area:** Console interface and progress display
- **Primary role:** Calculates or formats f or ma t a pp ly pr og re ss ba r data for callers that need a stable value instead of duplicating the logic.

`Format-ApplyProgressBar` belongs to the **Console interface and progress display** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on console dimensions, color output, and transient display state. It should not change backup data unless it delegates after user input.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Percent`, `Width`. The caller expects a derived object, string, number, or collection and should not need to know how it was produced.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is poor readability or accidental selection. The UI helpers keep fixed prompts, Escape handling, and compact tables to reduce that risk.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Format-ApplyProgressBar` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** interactive menus, previews, progress display, and user cancellation.
- **Dependency notes:** No notable internal function calls were detected in this function body.

### Get-ApplyProgressLayout

- **Lines:** 399-456
- **Area:** Console interface and progress display
- **Primary role:** Calculates or formats g et a pp ly pr og re ss la yo ut data for callers that need a stable value instead of duplicating the logic.

`Get-ApplyProgressLayout` belongs to the **Console interface and progress display** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on console dimensions, color output, and transient display state. It should not change backup data unless it delegates after user input.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. No explicit function parameters; it reads from script-scoped state or acts as an internal workflow step. The caller expects a derived object, string, number, or collection and should not need to know how it was produced.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is poor readability or accidental selection. The UI helpers keep fixed prompts, Escape handling, and compact tables to reduce that risk.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Get-ApplyProgressLayout` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** interactive menus, previews, progress display, and user cancellation.
- **Dependency notes:** Notable internal calls: `Get-ConsoleWidthSafe`.

### Get-ApplyEntryTotalBytes

- **Lines:** 457-465
- **Area:** Apply Pending copy and delete workflow
- **Primary role:** Calculates or formats g et a pp ly en tr yt ot al by te s data for callers that need a stable value instead of duplicating the logic.

`Get-ApplyEntryTotalBytes` belongs to the **Apply Pending copy and delete workflow** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on queue entries, destination availability, copy settings, delete settings, and progress callbacks.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Entry`. The caller expects a derived object, string, number, or collection and should not need to know how it was produced.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is destructive or partial file changes. Apply helpers check destination availability, copy through temp files when configured, and preserve failed entries.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Get-ApplyEntryTotalBytes` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** copy, mkdir, delete, skip, already-current, missing-source, and offline-destination outcomes.
- **Dependency notes:** No notable internal function calls were detected in this function body.

### Get-ApplyProgressPercent

- **Lines:** 466-474
- **Area:** Console interface and progress display
- **Primary role:** Calculates or formats g et a pp ly pr og re ss pe rc en t data for callers that need a stable value instead of duplicating the logic.

`Get-ApplyProgressPercent` belongs to the **Console interface and progress display** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on console dimensions, color output, and transient display state. It should not change backup data unless it delegates after user input.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Row`. The caller expects a derived object, string, number, or collection and should not need to know how it was produced.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is poor readability or accidental selection. The UI helpers keep fixed prompts, Escape handling, and compact tables to reduce that risk.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Get-ApplyProgressPercent` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** interactive menus, previews, progress display, and user cancellation.
- **Dependency notes:** No notable internal function calls were detected in this function body.

### Get-ApplyProgressSizeText

- **Lines:** 475-480
- **Area:** Console interface and progress display
- **Primary role:** Calculates or formats g et a pp ly pr og re ss si ze te xt data for callers that need a stable value instead of duplicating the logic.

`Get-ApplyProgressSizeText` belongs to the **Console interface and progress display** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on console dimensions, color output, and transient display state. It should not change backup data unless it delegates after user input.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Row`. The caller expects a derived object, string, number, or collection and should not need to know how it was produced.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is poor readability or accidental selection. The UI helpers keep fixed prompts, Escape handling, and compact tables to reduce that risk.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Get-ApplyProgressSizeText` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** interactive menus, previews, progress display, and user cancellation.
- **Dependency notes:** Notable internal calls: `Format-ByteSize`.

### Get-ApplyProgressTiming

- **Lines:** 481-499
- **Area:** Console interface and progress display
- **Primary role:** Calculates or formats g et a pp ly pr og re ss ti mi ng data for callers that need a stable value instead of duplicating the logic.

`Get-ApplyProgressTiming` belongs to the **Console interface and progress display** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on console dimensions, color output, and transient display state. It should not change backup data unless it delegates after user input.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Row`. The caller expects a derived object, string, number, or collection and should not need to know how it was produced.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is poor readability or accidental selection. The UI helpers keep fixed prompts, Escape handling, and compact tables to reduce that risk.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Get-ApplyProgressTiming` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** interactive menus, previews, progress display, and user cancellation.
- **Dependency notes:** Notable internal calls: `Format-ByteSpeed`, `Format-CompactDuration`.

### Get-ApplyStatusColor

- **Lines:** 500-522
- **Area:** Console interface and progress display
- **Primary role:** Calculates or formats g et a pp ly st at us co lo r data for callers that need a stable value instead of duplicating the logic.

`Get-ApplyStatusColor` belongs to the **Console interface and progress display** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on console dimensions, color output, and transient display state. It should not change backup data unless it delegates after user input.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `StatusOrRow`. The caller expects a derived object, string, number, or collection and should not need to know how it was produced.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is poor readability or accidental selection. The UI helpers keep fixed prompts, Escape handling, and compact tables to reduce that risk.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Get-ApplyStatusColor` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** interactive menus, previews, progress display, and user cancellation.
- **Dependency notes:** No notable internal function calls were detected in this function body.

### Format-ApplyProgressRow

- **Lines:** 523-539
- **Area:** Console interface and progress display
- **Primary role:** Calculates or formats f or ma t a pp ly pr og re ss ro w data for callers that need a stable value instead of duplicating the logic.

`Format-ApplyProgressRow` belongs to the **Console interface and progress display** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on console dimensions, color output, and transient display state. It should not change backup data unless it delegates after user input.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Table`, `Row`. The caller expects a derived object, string, number, or collection and should not need to know how it was produced.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is poor readability or accidental selection. The UI helpers keep fixed prompts, Escape handling, and compact tables to reduce that risk.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Format-ApplyProgressRow` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** interactive menus, previews, progress display, and user cancellation.
- **Dependency notes:** Notable internal calls: `Fit-Cell`, `Format-ApplyProgressBar`, `Get-ApplyProgressPercent`, `Get-ApplyProgressSizeText`, `Get-ApplyProgressTiming`.

### Write-ApplyProgressLine

- **Lines:** 540-545
- **Area:** Console interface and progress display
- **Primary role:** Provides the w ri te a pp ly pr og re ss li ne helper behavior used by nearby workflows.

`Write-ApplyProgressLine` belongs to the **Console interface and progress display** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on console dimensions, color output, and transient display state. It should not change backup data unless it delegates after user input.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Text`, `Color`, `Width`. The main output is console presentation. Any return value is secondary to navigation or display.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is poor readability or accidental selection. The UI helpers keep fixed prompts, Escape handling, and compact tables to reduce that risk.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Write-ApplyProgressLine` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** interactive menus, previews, progress display, and user cancellation.
- **Dependency notes:** Notable internal calls: `Write-Color`.

### Get-ApplyProgressBorder

- **Lines:** 546-552
- **Area:** Console interface and progress display
- **Primary role:** Calculates or formats g et a pp ly pr og re ss bo rd er data for callers that need a stable value instead of duplicating the logic.

`Get-ApplyProgressBorder` belongs to the **Console interface and progress display** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on console dimensions, color output, and transient display state. It should not change backup data unless it delegates after user input.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Layout`. The caller expects a derived object, string, number, or collection and should not need to know how it was produced.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is poor readability or accidental selection. The UI helpers keep fixed prompts, Escape handling, and compact tables to reduce that risk.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Get-ApplyProgressBorder` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** interactive menus, previews, progress display, and user cancellation.
- **Dependency notes:** No notable internal function calls were detected in this function body.

### Get-ApplyProgressHeaderRow

- **Lines:** 553-566
- **Area:** Console interface and progress display
- **Primary role:** Calculates or formats g et a pp ly pr og re ss he ad er ro w data for callers that need a stable value instead of duplicating the logic.

`Get-ApplyProgressHeaderRow` belongs to the **Console interface and progress display** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on console dimensions, color output, and transient display state. It should not change backup data unless it delegates after user input.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Layout`. The caller expects a derived object, string, number, or collection and should not need to know how it was produced.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is poor readability or accidental selection. The UI helpers keep fixed prompts, Escape handling, and compact tables to reduce that risk.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Get-ApplyProgressHeaderRow` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** interactive menus, previews, progress display, and user cancellation.
- **Dependency notes:** Notable internal calls: `Center-Text`.

### Get-ApplyProgressSummary

- **Lines:** 567-578
- **Area:** Console interface and progress display
- **Primary role:** Calculates or formats g et a pp ly pr og re ss su mm ar y data for callers that need a stable value instead of duplicating the logic.

`Get-ApplyProgressSummary` belongs to the **Console interface and progress display** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on console dimensions, color output, and transient display state. It should not change backup data unless it delegates after user input.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Table`. The caller expects a derived object, string, number, or collection and should not need to know how it was produced.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is poor readability or accidental selection. The UI helpers keep fixed prompts, Escape handling, and compact tables to reduce that risk.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Get-ApplyProgressSummary` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** interactive menus, previews, progress display, and user cancellation.
- **Dependency notes:** No notable internal function calls were detected in this function body.

### Get-ApplyProgressQueuedStatus

- **Lines:** 579-585
- **Area:** Console interface and progress display
- **Primary role:** Calculates or formats g et a pp ly pr og re ss qu eu ed st at us data for callers that need a stable value instead of duplicating the logic.

`Get-ApplyProgressQueuedStatus` belongs to the **Console interface and progress display** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on console dimensions, color output, and transient display state. It should not change backup data unless it delegates after user input.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Entry`. The caller expects a derived object, string, number, or collection and should not need to know how it was produced.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is poor readability or accidental selection. The UI helpers keep fixed prompts, Escape handling, and compact tables to reduce that risk.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Get-ApplyProgressQueuedStatus` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** interactive menus, previews, progress display, and user cancellation.
- **Dependency notes:** No notable internal function calls were detected in this function body.

### Test-ApplyProgressEntryVisible

- **Lines:** 586-592
- **Area:** Console interface and progress display
- **Primary role:** Evaluates the t es t a pp ly pr og re ss en tr yv is ib le condition and lets the caller choose a safe branch based on a clear result.

`Test-ApplyProgressEntryVisible` belongs to the **Console interface and progress display** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on console dimensions, color output, and transient display state. It should not change backup data unless it delegates after user input.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Entry`, `VisibleEntryKeys`. The caller expects a boolean or compact status object that can be used immediately in a branch.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is poor readability or accidental selection. The UI helpers keep fixed prompts, Escape handling, and compact tables to reduce that risk.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Test-ApplyProgressEntryVisible` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** interactive menus, previews, progress display, and user cancellation.
- **Dependency notes:** Notable internal calls: `Get-QueueEntryKey`.

### New-ApplyProgressRow

- **Lines:** 593-609
- **Area:** Console interface and progress display
- **Primary role:** Provides the n ew a pp ly pr og re ss ro w helper behavior used by nearby workflows.

`New-ApplyProgressRow` belongs to the **Console interface and progress display** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on console dimensions, color output, and transient display state. It should not change backup data unless it delegates after user input.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Entry`, `No`. The caller expects a derived object, string, number, or collection and should not need to know how it was produced.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is poor readability or accidental selection. The UI helpers keep fixed prompts, Escape handling, and compact tables to reduce that risk.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `New-ApplyProgressRow` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** interactive menus, previews, progress display, and user cancellation.
- **Dependency notes:** Notable internal calls: `Get-ApplyEntryTotalBytes`, `Get-ApplyProgressQueuedStatus`.

### Get-ApplyProgressVisibleCount

- **Lines:** 610-625
- **Area:** Console interface and progress display
- **Primary role:** Calculates or formats g et a pp ly pr og re ss vi si bl ec ou nt data for callers that need a stable value instead of duplicating the logic.

`Get-ApplyProgressVisibleCount` belongs to the **Console interface and progress display** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on console dimensions, color output, and transient display state. It should not change backup data unless it delegates after user input.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `TotalRows`. The caller expects a derived object, string, number, or collection and should not need to know how it was produced.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is poor readability or accidental selection. The UI helpers keep fixed prompts, Escape handling, and compact tables to reduce that risk.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Get-ApplyProgressVisibleCount` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** interactive menus, previews, progress display, and user cancellation.
- **Dependency notes:** No notable internal function calls were detected in this function body.

### Get-ApplyProgressVisibleStart

- **Lines:** 626-638
- **Area:** Console interface and progress display
- **Primary role:** Calculates or formats g et a pp ly pr og re ss vi si bl es ta rt data for callers that need a stable value instead of duplicating the logic.

`Get-ApplyProgressVisibleStart` belongs to the **Console interface and progress display** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on console dimensions, color output, and transient display state. It should not change backup data unless it delegates after user input.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Table`, `CurrentIndex`. The caller expects a derived object, string, number, or collection and should not need to know how it was produced.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is poor readability or accidental selection. The UI helpers keep fixed prompts, Escape handling, and compact tables to reduce that risk.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Get-ApplyProgressVisibleStart` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** interactive menus, previews, progress display, and user cancellation.
- **Dependency notes:** No notable internal function calls were detected in this function body.

### Write-ApplyProgressAtLine

- **Lines:** 639-647
- **Area:** Console interface and progress display
- **Primary role:** Provides the w ri te a pp ly pr og re ss at li ne helper behavior used by nearby workflows.

`Write-ApplyProgressAtLine` belongs to the **Console interface and progress display** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on console dimensions, color output, and transient display state. It should not change backup data unless it delegates after user input.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Line`, `Text`, `Color`, `Width`. The main output is console presentation. Any return value is secondary to navigation or display.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is poor readability or accidental selection. The UI helpers keep fixed prompts, Escape handling, and compact tables to reduce that risk.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Write-ApplyProgressAtLine` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** interactive menus, previews, progress display, and user cancellation.
- **Dependency notes:** No notable internal function calls were detected in this function body.

### Redraw-ApplyProgressViewport

- **Lines:** 648-683
- **Area:** Console interface and progress display
- **Primary role:** Provides the r ed ra w a pp ly pr og re ss vi ew po rt helper behavior used by nearby workflows.

`Redraw-ApplyProgressViewport` belongs to the **Console interface and progress display** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on console dimensions, color output, and transient display state. It should not change backup data unless it delegates after user input.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Table`, `Initial`. The output is either updated state, a small helper value, or no direct return value depending on caller context.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is poor readability or accidental selection. The UI helpers keep fixed prompts, Escape handling, and compact tables to reduce that risk.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Redraw-ApplyProgressViewport` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** interactive menus, previews, progress display, and user cancellation.
- **Dependency notes:** Notable internal calls: `Get-ApplyStatusColor`, `Format-ApplyProgressRow`, `Write-ApplyProgressLine`, `Get-ApplyProgressBorder`, `Get-ApplyProgressHeaderRow`, `Get-ApplyProgressSummary`, `Write-ApplyProgressAtLine`.

### New-ApplyProgressTable

- **Lines:** 684-718
- **Area:** Console interface and progress display
- **Primary role:** Provides the n ew a pp ly pr og re ss ta bl e helper behavior used by nearby workflows.

`New-ApplyProgressTable` belongs to the **Console interface and progress display** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on console dimensions, color output, and transient display state. It should not change backup data unless it delegates after user input.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Entries`, `VisibleEntryKeys`. The caller expects a derived object, string, number, or collection and should not need to know how it was produced.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is poor readability or accidental selection. The UI helpers keep fixed prompts, Escape handling, and compact tables to reduce that risk.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `New-ApplyProgressTable` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** interactive menus, previews, progress display, and user cancellation.
- **Dependency notes:** Notable internal calls: `Get-ApplyProgressLayout`, `Test-ApplyProgressEntryVisible`, `New-ApplyProgressRow`, `Get-ApplyProgressVisibleCount`, `Redraw-ApplyProgressViewport`.

### Add-ApplyProgressVisibleRow

- **Lines:** 719-736
- **Area:** Console interface and progress display
- **Primary role:** Mutates the a dd a pp ly pr og re ss vi si bl er ow state in one named place so the rest of the script does not duplicate update rules.

`Add-ApplyProgressVisibleRow` belongs to the **Console interface and progress display** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on console dimensions, color output, and transient display state. It should not change backup data unless it delegates after user input.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Table`, `EntryIndex`. The output is either updated state, a small helper value, or no direct return value depending on caller context.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is poor readability or accidental selection. The UI helpers keep fixed prompts, Escape handling, and compact tables to reduce that risk.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Add-ApplyProgressVisibleRow` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** interactive menus, previews, progress display, and user cancellation.
- **Dependency notes:** Notable internal calls: `New-ApplyProgressRow`, `Get-ApplyProgressVisibleCount`, `Redraw-ApplyProgressViewport`.

### Resolve-ApplyProgressRowIndex

- **Lines:** 737-753
- **Area:** Console interface and progress display
- **Primary role:** Provides the r es ol ve a pp ly pr og re ss ro wi nd ex helper behavior used by nearby workflows.

`Resolve-ApplyProgressRowIndex` belongs to the **Console interface and progress display** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on console dimensions, color output, and transient display state. It should not change backup data unless it delegates after user input.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Table`, `Index`, `ShowIfHidden`. The output is either updated state, a small helper value, or no direct return value depending on caller context.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is poor readability or accidental selection. The UI helpers keep fixed prompts, Escape handling, and compact tables to reduce that risk.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Resolve-ApplyProgressRowIndex` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** interactive menus, previews, progress display, and user cancellation.
- **Dependency notes:** Notable internal calls: `Add-ApplyProgressVisibleRow`.

### Update-ApplyProgressRow

- **Lines:** 754-812
- **Area:** Console interface and progress display
- **Primary role:** Provides the u pd at e a pp ly pr og re ss ro w helper behavior used by nearby workflows.

`Update-ApplyProgressRow` belongs to the **Console interface and progress display** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on console dimensions, color output, and transient display state. It should not change backup data unless it delegates after user input.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Table`, `Index`, `Status`, `CopiedBytes`, `TotalBytes`, `StartedAt`, `Complete`, `ForceRender`, `ShowIfHidden`. The output is either updated state, a small helper value, or no direct return value depending on caller context.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is poor readability or accidental selection. The UI helpers keep fixed prompts, Escape handling, and compact tables to reduce that risk.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Update-ApplyProgressRow` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** interactive menus, previews, progress display, and user cancellation.
- **Dependency notes:** Notable internal calls: `Get-ApplyStatusColor`, `Format-ApplyProgressRow`, `Get-ApplyProgressSummary`, `Get-ApplyProgressVisibleStart`, `Redraw-ApplyProgressViewport`, `Resolve-ApplyProgressRowIndex`.

### Wait-Back

- **Lines:** 813-820
- **Area:** Console interface and progress display
- **Primary role:** Provides the w ai t b ac k helper behavior used by nearby workflows.

`Wait-Back` belongs to the **Console interface and progress display** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on console dimensions, color output, and transient display state. It should not change backup data unless it delegates after user input.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Prompt`. The output is either updated state, a small helper value, or no direct return value depending on caller context.

Side effects are intentionally bounded. It is expected to be side-effect-light and primarily returns data or decisions to the caller. The important failure mode is poor readability or accidental selection. The UI helpers keep fixed prompts, Escape handling, and compact tables to reduce that risk.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Wait-Back` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** interactive menus, previews, progress display, and user cancellation.
- **Dependency notes:** Notable internal calls: `Write-Color`.

### Read-KeyChoice

- **Lines:** 821-832
- **Area:** Console interface and progress display
- **Primary role:** Collects r ea d k ey ch oi ce input from the console while preserving Escape/cancel behavior.

`Read-KeyChoice` belongs to the **Console interface and progress display** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on console dimensions, color output, and transient display state. It should not change backup data unless it delegates after user input.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Prompt`. The output is either updated state, a small helper value, or no direct return value depending on caller context.

Side effects are intentionally bounded. Its side effect is user interaction: console output, cursor movement, or waiting for input. It should not silently perform backup changes by itself. The important failure mode is poor readability or accidental selection. The UI helpers keep fixed prompts, Escape handling, and compact tables to reduce that risk.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Read-KeyChoice` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** interactive menus, previews, progress display, and user cancellation.
- **Dependency notes:** Notable internal calls: `Write-Color`.

### Read-LineOrEsc

- **Lines:** 833-854
- **Area:** Console interface and progress display
- **Primary role:** Collects r ea d l in eo re sc input from the console while preserving Escape/cancel behavior.

`Read-LineOrEsc` belongs to the **Console interface and progress display** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on console dimensions, color output, and transient display state. It should not change backup data unless it delegates after user input.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Prompt`. The output is either updated state, a small helper value, or no direct return value depending on caller context.

Side effects are intentionally bounded. Its side effect is user interaction: console output, cursor movement, or waiting for input. It should not silently perform backup changes by itself. The important failure mode is poor readability or accidental selection. The UI helpers keep fixed prompts, Escape handling, and compact tables to reduce that risk.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Read-LineOrEsc` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** interactive menus, previews, progress display, and user cancellation.
- **Dependency notes:** Notable internal calls: `Write-Color`.

### Read-NumberOrEsc

- **Lines:** 855-865
- **Area:** Console interface and progress display
- **Primary role:** Collects r ea d n um be ro re sc input from the console while preserving Escape/cancel behavior.

`Read-NumberOrEsc` belongs to the **Console interface and progress display** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on console dimensions, color output, and transient display state. It should not change backup data unless it delegates after user input.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Prompt`. The output is either updated state, a small helper value, or no direct return value depending on caller context.

Side effects are intentionally bounded. Its side effect is user interaction: console output, cursor movement, or waiting for input. It should not silently perform backup changes by itself. The important failure mode is poor readability or accidental selection. The UI helpers keep fixed prompts, Escape handling, and compact tables to reduce that risk.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Read-NumberOrEsc` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** interactive menus, previews, progress display, and user cancellation.
- **Dependency notes:** Notable internal calls: `Write-Color`, `Read-LineOrEsc`.

### Read-EnterOrEsc

- **Lines:** 866-876
- **Area:** Console interface and progress display
- **Primary role:** Collects r ea d e nt er or es c input from the console while preserving Escape/cancel behavior.

`Read-EnterOrEsc` belongs to the **Console interface and progress display** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on console dimensions, color output, and transient display state. It should not change backup data unless it delegates after user input.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Prompt`. The output is either updated state, a small helper value, or no direct return value depending on caller context.

Side effects are intentionally bounded. Its side effect is user interaction: console output, cursor movement, or waiting for input. It should not silently perform backup changes by itself. The important failure mode is poor readability or accidental selection. The UI helpers keep fixed prompts, Escape handling, and compact tables to reduce that risk.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Read-EnterOrEsc` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** interactive menus, previews, progress display, and user cancellation.
- **Dependency notes:** Notable internal calls: `Write-Color`.

### Normalize-PathText

- **Lines:** 877-884
- **Area:** Path, pair, drive map, and exclusion handling
- **Primary role:** Provides the n or ma li ze p at ht ex t helper behavior used by nearby workflows.

`Normalize-PathText` belongs to the **Path, pair, drive map, and exclusion handling** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on configured pairs, drive maps, exclusion maps, and path text supplied by the user or file system events.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Path`. The output is either updated state, a small helper value, or no direct return value depending on caller context.

Side effects are intentionally bounded. It is expected to be side-effect-light and primarily returns data or decisions to the caller. The important failure mode is pointing at the wrong folder. Path helpers centralize normalization and destination resolution so previews and applies use the same interpretation.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Normalize-PathText` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** adding pairs, resolving destinations, drive maps, and exclusions.
- **Dependency notes:** No notable internal function calls were detected in this function body.

### Format-ErrorSummary

- **Lines:** 885-899
- **Area:** Shared core helper
- **Primary role:** Calculates or formats f or ma t e rr or su mm ar y data for callers that need a stable value instead of duplicating the logic.

`Format-ErrorSummary` belongs to the **Shared core helper** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on explicit parameters and script-scoped state supplied indirectly by the caller.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Message`. The caller expects a derived object, string, number, or collection and should not need to know how it was produced.

Side effects are intentionally bounded. It is expected to be side-effect-light and primarily returns data or decisions to the caller. The important failure mode is inconsistent behavior across callers, so this helper keeps one rule in one place.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Format-ErrorSummary` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** shared workflow support across the script.
- **Dependency notes:** No notable internal function calls were detected in this function body.

### Get-AutoPairName

- **Lines:** 900-919
- **Area:** Path, pair, drive map, and exclusion handling
- **Primary role:** Calculates or formats g et a ut op ai rn am e data for callers that need a stable value instead of duplicating the logic.

`Get-AutoPairName` belongs to the **Path, pair, drive map, and exclusion handling** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on configured pairs, drive maps, exclusion maps, and path text supplied by the user or file system events.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Source`, `Dest`. The caller expects a derived object, string, number, or collection and should not need to know how it was produced.

Side effects are intentionally bounded. It is expected to be side-effect-light and primarily returns data or decisions to the caller. The important failure mode is pointing at the wrong folder. Path helpers centralize normalization and destination resolution so previews and applies use the same interpretation.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Get-AutoPairName` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** adding pairs, resolving destinations, drive maps, and exclusions.
- **Dependency notes:** Notable internal calls: `Normalize-PathText`.

### Resolve-DestinationPath

- **Lines:** 920-938
- **Area:** Path, pair, drive map, and exclusion handling
- **Primary role:** Provides the r es ol ve d es ti na ti on pa th helper behavior used by nearby workflows.

`Resolve-DestinationPath` belongs to the **Path, pair, drive map, and exclusion handling** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on configured pairs, drive maps, exclusion maps, and path text supplied by the user or file system events.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Path`. The output is either updated state, a small helper value, or no direct return value depending on caller context.

Side effects are intentionally bounded. It is expected to be side-effect-light and primarily returns data or decisions to the caller. The important failure mode is pointing at the wrong folder. Path helpers centralize normalization and destination resolution so previews and applies use the same interpretation.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Resolve-DestinationPath` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** adding pairs, resolving destinations, drive maps, and exclusions.
- **Dependency notes:** No notable internal function calls were detected in this function body.

### Get-RelativePath

- **Lines:** 939-951
- **Area:** Path, pair, drive map, and exclusion handling
- **Primary role:** Calculates or formats g et r el at iv ep at h data for callers that need a stable value instead of duplicating the logic.

`Get-RelativePath` belongs to the **Path, pair, drive map, and exclusion handling** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on configured pairs, drive maps, exclusion maps, and path text supplied by the user or file system events.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Root`, `Path`. The caller expects a derived object, string, number, or collection and should not need to know how it was produced.

Side effects are intentionally bounded. It is expected to be side-effect-light and primarily returns data or decisions to the caller. The important failure mode is pointing at the wrong folder. Path helpers centralize normalization and destination resolution so previews and applies use the same interpretation.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Get-RelativePath` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** adding pairs, resolving destinations, drive maps, and exclusions.
- **Dependency notes:** No notable internal function calls were detected in this function body.

### Join-PathSafe

- **Lines:** 952-957
- **Area:** Path, pair, drive map, and exclusion handling
- **Primary role:** Provides the j oi n p at hs af e helper behavior used by nearby workflows.

`Join-PathSafe` belongs to the **Path, pair, drive map, and exclusion handling** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on configured pairs, drive maps, exclusion maps, and path text supplied by the user or file system events.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Base`, `Rel`. The output is either updated state, a small helper value, or no direct return value depending on caller context.

Side effects are intentionally bounded. It is expected to be side-effect-light and primarily returns data or decisions to the caller. The important failure mode is pointing at the wrong folder. Path helpers centralize normalization and destination resolution so previews and applies use the same interpretation.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Join-PathSafe` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** adding pairs, resolving destinations, drive maps, and exclusions.
- **Dependency notes:** No notable internal function calls were detected in this function body.

### Test-NameMatchesAny

- **Lines:** 958-966
- **Area:** Path, pair, drive map, and exclusion handling
- **Primary role:** Evaluates the t es t n am em at ch es an y condition and lets the caller choose a safe branch based on a clear result.

`Test-NameMatchesAny` belongs to the **Path, pair, drive map, and exclusion handling** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on configured pairs, drive maps, exclusion maps, and path text supplied by the user or file system events.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Text`, `Patterns`. The caller expects a boolean or compact status object that can be used immediately in a branch.

Side effects are intentionally bounded. It is expected to be side-effect-light and primarily returns data or decisions to the caller. The important failure mode is pointing at the wrong folder. Path helpers centralize normalization and destination resolution so previews and applies use the same interpretation.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Test-NameMatchesAny` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** adding pairs, resolving destinations, drive maps, and exclusions.
- **Dependency notes:** No notable internal function calls were detected in this function body.

### Test-Excluded

- **Lines:** 967-990
- **Area:** Path, pair, drive map, and exclusion handling
- **Primary role:** Evaluates the t es t e xc lu de d condition and lets the caller choose a safe branch based on a clear result.

`Test-Excluded` belongs to the **Path, pair, drive map, and exclusion handling** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on configured pairs, drive maps, exclusion maps, and path text supplied by the user or file system events.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Pair`, `FullPath`, `IsDirectory`. The caller expects a boolean or compact status object that can be used immediately in a branch.

Side effects are intentionally bounded. It is expected to be side-effect-light and primarily returns data or decisions to the caller. The important failure mode is pointing at the wrong folder. Path helpers centralize normalization and destination resolution so previews and applies use the same interpretation.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Test-Excluded` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** adding pairs, resolving destinations, drive maps, and exclusions.
- **Dependency notes:** Notable internal calls: `Get-Array`, `Get-MapArray`, `Get-RelativePath`, `Test-NameMatchesAny`.

### Test-DestRootAvailable

- **Lines:** 991-1002
- **Area:** Path, pair, drive map, and exclusion handling
- **Primary role:** Evaluates the t es t d es tr oo ta va il ab le condition and lets the caller choose a safe branch based on a clear result.

`Test-DestRootAvailable` belongs to the **Path, pair, drive map, and exclusion handling** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on configured pairs, drive maps, exclusion maps, and path text supplied by the user or file system events.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `DestPath`. The caller expects a boolean or compact status object that can be used immediately in a branch.

Side effects are intentionally bounded. It is expected to be side-effect-light and primarily returns data or decisions to the caller. The important failure mode is pointing at the wrong folder. Path helpers centralize normalization and destination resolution so previews and applies use the same interpretation.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Test-DestRootAvailable` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** adding pairs, resolving destinations, drive maps, and exclusions.
- **Dependency notes:** Notable internal calls: `Resolve-DestinationPath`.

### Find-PairByName

- **Lines:** 1003-1010
- **Area:** Path, pair, drive map, and exclusion handling
- **Primary role:** Provides the f in d p ai rb yn am e helper behavior used by nearby workflows.

`Find-PairByName` belongs to the **Path, pair, drive map, and exclusion handling** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on configured pairs, drive maps, exclusion maps, and path text supplied by the user or file system events.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Name`. The output is either updated state, a small helper value, or no direct return value depending on caller context.

Side effects are intentionally bounded. It is expected to be side-effect-light and primarily returns data or decisions to the caller. The important failure mode is pointing at the wrong folder. Path helpers centralize normalization and destination resolution so previews and applies use the same interpretation.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Find-PairByName` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** adding pairs, resolving destinations, drive maps, and exclusions.
- **Dependency notes:** Notable internal calls: `Get-Pairs`.

### New-QueueEntry

- **Lines:** 1011-1041
- **Area:** Pending queue model
- **Primary role:** Provides the n ew q ue ue en tr y helper behavior used by nearby workflows.

`New-QueueEntry` belongs to the **Pending queue model** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on `$script:QueuePath`, queue entry shape, pair names, and the latest-entry collapse rules.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Pair`, `FullPath`, `Action`, `KnownIsDirectory`. The caller expects a derived object, string, number, or collection and should not need to know how it was produced.

Side effects are intentionally bounded. It is expected to be side-effect-light and primarily returns data or decisions to the caller. The important failure mode is stale or contradictory queue data. Queue helpers collapse repeated actions and keep unresolved work visible.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `New-QueueEntry` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** watcher queuing, preview pending, apply pending, and queue clearing.
- **Dependency notes:** Notable internal calls: `Resolve-DestinationPath`, `Get-RelativePath`, `Join-PathSafe`.

### Append-QueueEntry

- **Lines:** 1042-1053
- **Area:** Pending queue model
- **Primary role:** Provides the a pp en d q ue ue en tr y helper behavior used by nearby workflows.

`Append-QueueEntry` belongs to the **Pending queue model** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on `$script:QueuePath`, queue entry shape, pair names, and the latest-entry collapse rules.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Entry`. The output is either updated state, a small helper value, or no direct return value depending on caller context.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is stale or contradictory queue data. Queue helpers collapse repeated actions and keep unresolved work visible.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Append-QueueEntry` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** watcher queuing, preview pending, apply pending, and queue clearing.
- **Dependency notes:** Notable internal calls: `Write-Log`.

### Read-QueueEntries

- **Lines:** 1054-1065
- **Area:** Pending queue model
- **Primary role:** Collects r ea d q ue ue en tr ie s input from the console while preserving Escape/cancel behavior.

`Read-QueueEntries` belongs to the **Pending queue model** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on `$script:QueuePath`, queue entry shape, pair names, and the latest-entry collapse rules.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. No explicit function parameters; it reads from script-scoped state or acts as an internal workflow step. The output is either updated state, a small helper value, or no direct return value depending on caller context.

Side effects are intentionally bounded. Its side effect is user interaction: console output, cursor movement, or waiting for input. It should not silently perform backup changes by itself. The important failure mode is stale or contradictory queue data. Queue helpers collapse repeated actions and keep unresolved work visible.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Read-QueueEntries` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** watcher queuing, preview pending, apply pending, and queue clearing.
- **Dependency notes:** Notable internal calls: `Write-Log`.

### Get-LatestQueueEntries

- **Lines:** 1066-1076
- **Area:** Pending queue model
- **Primary role:** Calculates or formats g et l at es tq ue ue en tr ie s data for callers that need a stable value instead of duplicating the logic.

`Get-LatestQueueEntries` belongs to the **Pending queue model** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on `$script:QueuePath`, queue entry shape, pair names, and the latest-entry collapse rules.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Entries`. The caller expects a derived object, string, number, or collection and should not need to know how it was produced.

Side effects are intentionally bounded. It is expected to be side-effect-light and primarily returns data or decisions to the caller. The important failure mode is stale or contradictory queue data. Queue helpers collapse repeated actions and keep unresolved work visible.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Get-LatestQueueEntries` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** watcher queuing, preview pending, apply pending, and queue clearing.
- **Dependency notes:** No notable internal function calls were detected in this function body.

### Remove-OrphanedUpserts

- **Lines:** 1077-1098
- **Area:** Shared core helper
- **Primary role:** Mutates the r em ov e o rp ha ne du ps er ts state in one named place so the rest of the script does not duplicate update rules.

`Remove-OrphanedUpserts` belongs to the **Shared core helper** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on explicit parameters and script-scoped state supplied indirectly by the caller.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Entries`. The output is either updated state, a small helper value, or no direct return value depending on caller context.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is inconsistent behavior across callers, so this helper keeps one rule in one place.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Remove-OrphanedUpserts` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** shared workflow support across the script.
- **Dependency notes:** No notable internal function calls were detected in this function body.

### Write-QueueEntries

- **Lines:** 1099-1113
- **Area:** Pending queue model
- **Primary role:** Provides the w ri te q ue ue en tr ie s helper behavior used by nearby workflows.

`Write-QueueEntries` belongs to the **Pending queue model** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on `$script:QueuePath`, queue entry shape, pair names, and the latest-entry collapse rules.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Entries`. The main output is console presentation. Any return value is secondary to navigation or display.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is stale or contradictory queue data. Queue helpers collapse repeated actions and keep unresolved work visible.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Write-QueueEntries` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** watcher queuing, preview pending, apply pending, and queue clearing.
- **Dependency notes:** Notable internal calls: `Write-Log`.

### Clear-PendingQueue

- **Lines:** 1114-1128
- **Area:** Pending queue model
- **Primary role:** Mutates the c le ar p en di ng qu eu e state in one named place so the rest of the script does not duplicate update rules.

`Clear-PendingQueue` belongs to the **Pending queue model** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on `$script:QueuePath`, queue entry shape, pair names, and the latest-entry collapse rules.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. No explicit function parameters; it reads from script-scoped state or acts as an internal workflow step. The output is either updated state, a small helper value, or no direct return value depending on caller context.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is stale or contradictory queue data. Queue helpers collapse repeated actions and keep unresolved work visible.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Clear-PendingQueue` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** watcher queuing, preview pending, apply pending, and queue clearing.
- **Dependency notes:** Notable internal calls: `Write-Color`, `Show-Header`, `Wait-Back`, `Read-EnterOrEsc`, `Read-QueueEntries`, `Get-LatestQueueEntries`, `Request-ClearPendingQueue`.

### Request-ClearPendingQueue

- **Lines:** 1129-1146
- **Area:** Pending queue model
- **Primary role:** Provides the r eq ue st c le ar pe nd in gq ue ue helper behavior used by nearby workflows.

`Request-ClearPendingQueue` belongs to the **Pending queue model** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on `$script:QueuePath`, queue entry shape, pair names, and the latest-entry collapse rules.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. No explicit function parameters; it reads from script-scoped state or acts as an internal workflow step. The output is either updated state, a small helper value, or no direct return value depending on caller context.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is stale or contradictory queue data. Queue helpers collapse repeated actions and keep unresolved work visible.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Request-ClearPendingQueue` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** watcher queuing, preview pending, apply pending, and queue clearing.
- **Dependency notes:** Notable internal calls: `Read-QueueEntries`, `Write-QueueEntries`.

### Add-PendingEvent

- **Lines:** 1147-1153
- **Area:** Pending queue model
- **Primary role:** Mutates the a dd p en di ng ev en t state in one named place so the rest of the script does not duplicate update rules.

`Add-PendingEvent` belongs to the **Pending queue model** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on `$script:QueuePath`, queue entry shape, pair names, and the latest-entry collapse rules.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Entry`. The output is either updated state, a small helper value, or no direct return value depending on caller context.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is stale or contradictory queue data. Queue helpers collapse repeated actions and keep unresolved work visible.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Add-PendingEvent` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** watcher queuing, preview pending, apply pending, and queue clearing.
- **Dependency notes:** Notable internal calls: `Get-QueueEntryKey`.

### Normalize-QueueRelPath

- **Lines:** 1154-1158
- **Area:** Path, pair, drive map, and exclusion handling
- **Primary role:** Provides the n or ma li ze q ue ue re lp at h helper behavior used by nearby workflows.

`Normalize-QueueRelPath` belongs to the **Path, pair, drive map, and exclusion handling** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on configured pairs, drive maps, exclusion maps, and path text supplied by the user or file system events.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `RelPath`. The output is either updated state, a small helper value, or no direct return value depending on caller context.

Side effects are intentionally bounded. It is expected to be side-effect-light and primarily returns data or decisions to the caller. The important failure mode is pointing at the wrong folder. Path helpers centralize normalization and destination resolution so previews and applies use the same interpretation.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Normalize-QueueRelPath` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** adding pairs, resolving destinations, drive maps, and exclusions.
- **Dependency notes:** No notable internal function calls were detected in this function body.

### Get-QueueEntryKey

- **Lines:** 1159-1163
- **Area:** Pending queue model
- **Primary role:** Calculates or formats g et q ue ue en tr yk ey data for callers that need a stable value instead of duplicating the logic.

`Get-QueueEntryKey` belongs to the **Pending queue model** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on `$script:QueuePath`, queue entry shape, pair names, and the latest-entry collapse rules.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Entry`. The caller expects a derived object, string, number, or collection and should not need to know how it was produced.

Side effects are intentionally bounded. It is expected to be side-effect-light and primarily returns data or decisions to the caller. The important failure mode is stale or contradictory queue data. Queue helpers collapse repeated actions and keep unresolved work visible.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Get-QueueEntryKey` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** watcher queuing, preview pending, apply pending, and queue clearing.
- **Dependency notes:** Notable internal calls: `Normalize-QueueRelPath`.

### Test-QueueEntryChildOf

- **Lines:** 1164-1174
- **Area:** Pending queue model
- **Primary role:** Evaluates the t es t q ue ue en tr yc hi ld of condition and lets the caller choose a safe branch based on a clear result.

`Test-QueueEntryChildOf` belongs to the **Pending queue model** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on `$script:QueuePath`, queue entry shape, pair names, and the latest-entry collapse rules.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Entry`, `Parent`. The caller expects a boolean or compact status object that can be used immediately in a branch.

Side effects are intentionally bounded. It is expected to be side-effect-light and primarily returns data or decisions to the caller. The important failure mode is stale or contradictory queue data. Queue helpers collapse repeated actions and keep unresolved work visible.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Test-QueueEntryChildOf` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** watcher queuing, preview pending, apply pending, and queue clearing.
- **Dependency notes:** Notable internal calls: `Normalize-QueueRelPath`.

### Test-QueueEntryCoveredByAppliedDelete

- **Lines:** 1175-1182
- **Area:** Pending queue model
- **Primary role:** Evaluates the t es t q ue ue en tr yc ov er ed by ap pl ie dd el et e condition and lets the caller choose a safe branch based on a clear result.

`Test-QueueEntryCoveredByAppliedDelete` belongs to the **Pending queue model** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on `$script:QueuePath`, queue entry shape, pair names, and the latest-entry collapse rules.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Entry`, `AppliedDeletes`. The caller expects a boolean or compact status object that can be used immediately in a branch.

Side effects are intentionally bounded. It is expected to be side-effect-light and primarily returns data or decisions to the caller. The important failure mode is stale or contradictory queue data. Queue helpers collapse repeated actions and keep unresolved work visible.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Test-QueueEntryCoveredByAppliedDelete` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** watcher queuing, preview pending, apply pending, and queue clearing.
- **Dependency notes:** Notable internal calls: `Test-QueueEntryChildOf`.

### Flush-PendingEvents

- **Lines:** 1183-1193
- **Area:** Pending queue model
- **Primary role:** Provides the f lu sh p en di ng ev en ts helper behavior used by nearby workflows.

`Flush-PendingEvents` belongs to the **Pending queue model** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on `$script:QueuePath`, queue entry shape, pair names, and the latest-entry collapse rules.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. No explicit function parameters; it reads from script-scoped state or acts as an internal workflow step. The output is either updated state, a small helper value, or no direct return value depending on caller context.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is stale or contradictory queue data. Queue helpers collapse repeated actions and keep unresolved work visible.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Flush-PendingEvents` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** watcher queuing, preview pending, apply pending, and queue clearing.
- **Dependency notes:** Notable internal calls: `Append-QueueEntry`.

### Process-ClearQueueRequest

- **Lines:** 1194-1205
- **Area:** Pending queue model
- **Primary role:** Provides the p ro ce ss c le ar qu eu er eq ue st helper behavior used by nearby workflows.

`Process-ClearQueueRequest` belongs to the **Pending queue model** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on `$script:QueuePath`, queue entry shape, pair names, and the latest-entry collapse rules.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. No explicit function parameters; it reads from script-scoped state or acts as an internal workflow step. The output is either updated state, a small helper value, or no direct return value depending on caller context.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is stale or contradictory queue data. Queue helpers collapse repeated actions and keep unresolved work visible.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Process-ClearQueueRequest` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** watcher queuing, preview pending, apply pending, and queue clearing.
- **Dependency notes:** Notable internal calls: `Write-Log`, `Write-QueueEntries`.

### Queue-DirectorySnapshot

- **Lines:** 1206-1227
- **Area:** Pending queue model
- **Primary role:** Provides the q ue ue d ir ec to ry sn ap sh ot helper behavior used by nearby workflows.

`Queue-DirectorySnapshot` belongs to the **Pending queue model** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on `$script:QueuePath`, queue entry shape, pair names, and the latest-entry collapse rules.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Entry`. The output is either updated state, a small helper value, or no direct return value depending on caller context.

Side effects are intentionally bounded. It is expected to be side-effect-light and primarily returns data or decisions to the caller. The important failure mode is stale or contradictory queue data. Queue helpers collapse repeated actions and keep unresolved work visible.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Queue-DirectorySnapshot` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** watcher queuing, preview pending, apply pending, and queue clearing.
- **Dependency notes:** Notable internal calls: `Write-Log`, `Test-Excluded`, `Find-PairByName`, `New-QueueEntry`, `Append-QueueEntry`.

### Start-Watcher

- **Lines:** 1228-1292
- **Area:** Watcher lifecycle and file system events
- **Primary role:** Starts live filesystem monitoring for configured source folders and records events into the pending queue without copying files automatically.

`Start-Watcher` belongs to the **Watcher lifecycle and file system events** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on configured pairs, FileSystemWatcher events, debounce timing, exclusions, and the watcher mutex.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. No explicit function parameters; it reads from script-scoped state or acts as an internal workflow step. The output is either updated state, a small helper value, or no direct return value depending on caller context.

Side effects are intentionally bounded. It may participate in long-running watcher state, but the watcher contract remains queue-only: it records work and does not apply file changes. The important failure mode is event bursts or missed nested directory events. Debounce buffering and directory snapshots reduce that risk.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Start-Watcher` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** manual or scheduled watch mode, created/changed/deleted/renamed events, and directory snapshots.
- **Dependency notes:** Notable internal calls: `Get-Pairs`, `Write-Color`, `Write-Log`, `Show-Header`, `Wait-Back`, `Resolve-DestinationPath`, `Flush-PendingEvents`, `Process-ClearQueueRequest`, `Process-WatcherEvent`.

### Process-WatcherEvent

- **Lines:** 1293-1381
- **Area:** Watcher lifecycle and file system events
- **Primary role:** Converts raw FileSystemWatcher events into MiraQueue queue entries while respecting exclusions and special directory handling.

`Process-WatcherEvent` belongs to the **Watcher lifecycle and file system events** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on configured pairs, FileSystemWatcher events, debounce timing, exclusions, and the watcher mutex.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Evt`. The output is either updated state, a small helper value, or no direct return value depending on caller context.

Side effects are intentionally bounded. It may participate in long-running watcher state, but the watcher contract remains queue-only: it records work and does not apply file changes. The important failure mode is event bursts or missed nested directory events. Debounce buffering and directory snapshots reduce that risk.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Process-WatcherEvent` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** manual or scheduled watch mode, created/changed/deleted/renamed events, and directory snapshots.
- **Dependency notes:** Notable internal calls: `Get-Pairs`, `Write-Log`, `Test-Excluded`, `New-QueueEntry`, `Add-PendingEvent`, `Queue-DirectorySnapshot`.

### Test-FileNeedsCopy

- **Lines:** 1382-1395
- **Area:** Apply Pending copy and delete workflow
- **Primary role:** Evaluates the t es t f il en ee ds co py condition and lets the caller choose a safe branch based on a clear result.

`Test-FileNeedsCopy` belongs to the **Apply Pending copy and delete workflow** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on queue entries, destination availability, copy settings, delete settings, and progress callbacks.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Source`, `Dest`. The caller expects a boolean or compact status object that can be used immediately in a branch.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is destructive or partial file changes. Apply helpers check destination availability, copy through temp files when configured, and preserve failed entries.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Test-FileNeedsCopy` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** copy, mkdir, delete, skip, already-current, missing-source, and offline-destination outcomes.
- **Dependency notes:** No notable internal function calls were detected in this function body.

### Copy-FileStreamWithProgress

- **Lines:** 1396-1428
- **Area:** Console interface and progress display
- **Primary role:** Provides the c op y f il es tr ea mw it hp ro gr es s helper behavior used by nearby workflows.

`Copy-FileStreamWithProgress` belongs to the **Console interface and progress display** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on console dimensions, color output, and transient display state. It should not change backup data unless it delegates after user input.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Source`, `Destination`, `ProgressCallback`. The output is either updated state, a small helper value, or no direct return value depending on caller context.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is poor readability or accidental selection. The UI helpers keep fixed prompts, Escape handling, and compact tables to reduce that risk.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Copy-FileStreamWithProgress` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** interactive menus, previews, progress display, and user cancellation.
- **Dependency notes:** No notable internal function calls were detected in this function body.

### Copy-FileSafe

- **Lines:** 1429-1460
- **Area:** Apply Pending copy and delete workflow
- **Primary role:** Provides the c op y f il es af e helper behavior used by nearby workflows.

`Copy-FileSafe` belongs to the **Apply Pending copy and delete workflow** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on queue entries, destination availability, copy settings, delete settings, and progress callbacks.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Source`, `Dest`, `ProgressCallback`. The output is either updated state, a small helper value, or no direct return value depending on caller context.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is destructive or partial file changes. Apply helpers check destination availability, copy through temp files when configured, and preserve failed entries.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Copy-FileSafe` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** copy, mkdir, delete, skip, already-current, missing-source, and offline-destination outcomes.
- **Dependency notes:** Notable internal calls: `Copy-FileStreamWithProgress`.

### Apply-OneEntry

- **Lines:** 1461-1503
- **Area:** Apply Pending copy and delete workflow
- **Primary role:** Executes one pending queue entry, choosing between mkdir, copy, delete, skip, or failed result states.

`Apply-OneEntry` belongs to the **Apply Pending copy and delete workflow** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on queue entries, destination availability, copy settings, delete settings, and progress callbacks.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Entry`, `ProgressCallback`. The output is either updated state, a small helper value, or no direct return value depending on caller context.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is destructive or partial file changes. Apply helpers check destination availability, copy through temp files when configured, and preserve failed entries.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Apply-OneEntry` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** copy, mkdir, delete, skip, already-current, missing-source, and offline-destination outcomes.
- **Dependency notes:** Notable internal calls: `Format-ErrorSummary`, `Resolve-DestinationPath`, `Join-PathSafe`, `Test-DestRootAvailable`, `Find-PairByName`, `Test-FileNeedsCopy`, `Copy-FileSafe`.

### Get-ApplyProgressStartingStatus

- **Lines:** 1504-1510
- **Area:** Console interface and progress display
- **Primary role:** Calculates or formats g et a pp ly pr og re ss st ar ti ng st at us data for callers that need a stable value instead of duplicating the logic.

`Get-ApplyProgressStartingStatus` belongs to the **Console interface and progress display** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on console dimensions, color output, and transient display state. It should not change backup data unless it delegates after user input.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Entry`. The caller expects a derived object, string, number, or collection and should not need to know how it was produced.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is poor readability or accidental selection. The UI helpers keep fixed prompts, Escape handling, and compact tables to reduce that risk.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Get-ApplyProgressStartingStatus` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** interactive menus, previews, progress display, and user cancellation.
- **Dependency notes:** No notable internal function calls were detected in this function body.

### Get-ApplyProgressFinalStatus

- **Lines:** 1511-1520
- **Area:** Console interface and progress display
- **Primary role:** Calculates or formats g et a pp ly pr og re ss fi na ls ta tu s data for callers that need a stable value instead of duplicating the logic.

`Get-ApplyProgressFinalStatus` belongs to the **Console interface and progress display** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on console dimensions, color output, and transient display state. It should not change backup data unless it delegates after user input.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Result`. The caller expects a derived object, string, number, or collection and should not need to know how it was produced.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is poor readability or accidental selection. The UI helpers keep fixed prompts, Escape handling, and compact tables to reduce that risk.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Get-ApplyProgressFinalStatus` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** interactive menus, previews, progress display, and user cancellation.
- **Dependency notes:** No notable internal function calls were detected in this function body.

### Test-ApplyResultSelectedForDisplay

- **Lines:** 1521-1529
- **Area:** Apply Pending copy and delete workflow
- **Primary role:** Evaluates the t es t a pp ly re su lt se le ct ed fo rd is pl ay condition and lets the caller choose a safe branch based on a clear result.

`Test-ApplyResultSelectedForDisplay` belongs to the **Apply Pending copy and delete workflow** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on queue entries, destination availability, copy settings, delete settings, and progress callbacks.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Entry`, `Result`, `VisibleEntryKeys`. The caller expects a boolean or compact status object that can be used immediately in a branch.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is destructive or partial file changes. Apply helpers check destination availability, copy through temp files when configured, and preserve failed entries.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Test-ApplyResultSelectedForDisplay` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** copy, mkdir, delete, skip, already-current, missing-source, and offline-destination outcomes.
- **Dependency notes:** Notable internal calls: `Get-QueueEntryKey`.

### Invoke-ApplyPending

- **Lines:** 1530-1619
- **Area:** Pending queue model
- **Primary role:** Reads the effective pending queue, applies selected file operations, updates progress, and rewrites the queue to preserve unresolved work.

`Invoke-ApplyPending` belongs to the **Pending queue model** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on `$script:QueuePath`, queue entry shape, pair names, and the latest-entry collapse rules.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Quiet`. The output is workflow-level: visible progress, result objects, changed files, or system state depending on mode.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is stale or contradictory queue data. Queue helpers collapse repeated actions and keep unresolved work visible.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Invoke-ApplyPending` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** watcher queuing, preview pending, apply pending, and queue clearing.
- **Dependency notes:** Notable internal calls: `Write-Color`, `Show-Header`, `Get-ApplyEntryTotalBytes`, `New-ApplyProgressTable`, `Update-ApplyProgressRow`, `Wait-Back`, `Resolve-DestinationPath`, `Join-PathSafe`, `Find-PairByName`, `Read-QueueEntries`.

### Show-PendingPreview

- **Lines:** 1620-1650
- **Area:** Pending queue model
- **Primary role:** Presents the s ho w p en di ng pr ev ie w screen or menu and keeps display concerns separate from lower-level operations.

`Show-PendingPreview` belongs to the **Pending queue model** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on `$script:QueuePath`, queue entry shape, pair names, and the latest-entry collapse rules.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. No explicit function parameters; it reads from script-scoped state or acts as an internal workflow step. The main output is console presentation. Any return value is secondary to navigation or display.

Side effects are intentionally bounded. Its side effect is user interaction: console output, cursor movement, or waiting for input. It should not silently perform backup changes by itself. The important failure mode is stale or contradictory queue data. Queue helpers collapse repeated actions and keep unresolved work visible.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Show-PendingPreview` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** watcher queuing, preview pending, apply pending, and queue clearing.
- **Dependency notes:** Notable internal calls: `Write-Color`, `Show-Header`, `Wait-Back`, `Read-EnterOrEsc`, `Read-QueueEntries`, `Get-LatestQueueEntries`, `Remove-OrphanedUpserts`, `Invoke-ApplyPending`, `Get-DisplayAction`, `Get-VisiblePendingEntries`.

### Get-DisplayAction

- **Lines:** 1651-1662
- **Area:** Shared core helper
- **Primary role:** Calculates or formats g et d is pl ay ac ti on data for callers that need a stable value instead of duplicating the logic.

`Get-DisplayAction` belongs to the **Shared core helper** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on explicit parameters and script-scoped state supplied indirectly by the caller.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Entry`. The caller expects a derived object, string, number, or collection and should not need to know how it was produced.

Side effects are intentionally bounded. It is expected to be side-effect-light and primarily returns data or decisions to the caller. The important failure mode is inconsistent behavior across callers, so this helper keeps one rule in one place.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Get-DisplayAction` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** shared workflow support across the script.
- **Dependency notes:** Notable internal calls: `Resolve-DestinationPath`, `Join-PathSafe`, `Test-DestRootAvailable`, `Find-PairByName`.

### Test-PendingPreviewEntryVisible

- **Lines:** 1663-1675
- **Area:** Pending queue model
- **Primary role:** Evaluates the t es t p en di ng pr ev ie we nt ry vi si bl e condition and lets the caller choose a safe branch based on a clear result.

`Test-PendingPreviewEntryVisible` belongs to the **Pending queue model** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on `$script:QueuePath`, queue entry shape, pair names, and the latest-entry collapse rules.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Entry`. The caller expects a boolean or compact status object that can be used immediately in a branch.

Side effects are intentionally bounded. It is expected to be side-effect-light and primarily returns data or decisions to the caller. The important failure mode is stale or contradictory queue data. Queue helpers collapse repeated actions and keep unresolved work visible.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Test-PendingPreviewEntryVisible` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** watcher queuing, preview pending, apply pending, and queue clearing.
- **Dependency notes:** Notable internal calls: `Get-DisplayAction`, `Get-QueueEntryDestinationPath`.

### Get-QueueEntryDestinationPath

- **Lines:** 1676-1687
- **Area:** Path, pair, drive map, and exclusion handling
- **Primary role:** Calculates or formats g et q ue ue en tr yd es ti na ti on pa th data for callers that need a stable value instead of duplicating the logic.

`Get-QueueEntryDestinationPath` belongs to the **Path, pair, drive map, and exclusion handling** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on configured pairs, drive maps, exclusion maps, and path text supplied by the user or file system events.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Entry`. The caller expects a derived object, string, number, or collection and should not need to know how it was produced.

Side effects are intentionally bounded. It is expected to be side-effect-light and primarily returns data or decisions to the caller. The important failure mode is pointing at the wrong folder. Path helpers centralize normalization and destination resolution so previews and applies use the same interpretation.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Get-QueueEntryDestinationPath` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** adding pairs, resolving destinations, drive maps, and exclusions.
- **Dependency notes:** Notable internal calls: `Resolve-DestinationPath`, `Join-PathSafe`, `Find-PairByName`.

### Get-VisiblePendingEntries

- **Lines:** 1688-1692
- **Area:** Pending queue model
- **Primary role:** Calculates or formats g et v is ib le pe nd in ge nt ri es data for callers that need a stable value instead of duplicating the logic.

`Get-VisiblePendingEntries` belongs to the **Pending queue model** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on `$script:QueuePath`, queue entry shape, pair names, and the latest-entry collapse rules.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Entries`. The caller expects a derived object, string, number, or collection and should not need to know how it was produced.

Side effects are intentionally bounded. It is expected to be side-effect-light and primarily returns data or decisions to the caller. The important failure mode is stale or contradictory queue data. Queue helpers collapse repeated actions and keep unresolved work visible.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Get-VisiblePendingEntries` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** watcher queuing, preview pending, apply pending, and queue clearing.
- **Dependency notes:** Notable internal calls: `Test-PendingPreviewEntryVisible`.

### Test-ApplyResultVisible

- **Lines:** 1693-1701
- **Area:** Apply Pending copy and delete workflow
- **Primary role:** Evaluates the t es t a pp ly re su lt vi si bl e condition and lets the caller choose a safe branch based on a clear result.

`Test-ApplyResultVisible` belongs to the **Apply Pending copy and delete workflow** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on queue entries, destination availability, copy settings, delete settings, and progress callbacks.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Result`. The caller expects a boolean or compact status object that can be used immediately in a branch.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is destructive or partial file changes. Apply helpers check destination availability, copy through temp files when configured, and preserve failed entries.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Test-ApplyResultVisible` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** copy, mkdir, delete, skip, already-current, missing-source, and offline-destination outcomes.
- **Dependency notes:** No notable internal function calls were detected in this function body.

### Write-PendingTable

- **Lines:** 1702-1728
- **Area:** Console interface and progress display
- **Primary role:** Provides the w ri te p en di ng ta bl e helper behavior used by nearby workflows.

`Write-PendingTable` belongs to the **Console interface and progress display** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on console dimensions, color output, and transient display state. It should not change backup data unless it delegates after user input.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Items`. The main output is console presentation. Any return value is secondary to navigation or display.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is poor readability or accidental selection. The UI helpers keep fixed prompts, Escape handling, and compact tables to reduce that risk.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Write-PendingTable` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** interactive menus, previews, progress display, and user cancellation.
- **Dependency notes:** Notable internal calls: `Write-Color`, `Center-Text`, `Fit-Cell`, `Get-DisplayAction`.

### Show-ApplyResults

- **Lines:** 1729-1812
- **Area:** Apply Pending copy and delete workflow
- **Primary role:** Presents the s ho w a pp ly re su lt s screen or menu and keeps display concerns separate from lower-level operations.

`Show-ApplyResults` belongs to the **Apply Pending copy and delete workflow** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on queue entries, destination availability, copy settings, delete settings, and progress callbacks.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Results`, `Title`, `Compact`. The main output is console presentation. Any return value is secondary to navigation or display.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is destructive or partial file changes. Apply helpers check destination availability, copy through temp files when configured, and preserve failed entries.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Show-ApplyResults` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** copy, mkdir, delete, skip, already-current, missing-source, and offline-destination outcomes.
- **Dependency notes:** Notable internal calls: `Write-Color`, `Center-Text`, `Fit-Cell`, `Show-Header`, `Wait-Back`, `Test-ApplyResultVisible`.

### Build-RobocopyArgs

- **Lines:** 1813-1861
- **Area:** Apply Pending copy and delete workflow
- **Primary role:** Translates MiraQueue policy and exclusion settings into the exact robocopy argument list.

`Build-RobocopyArgs` belongs to the **Apply Pending copy and delete workflow** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on queue entries, destination availability, copy settings, delete settings, and progress callbacks.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Pair`, `Preview`, `Policy`. The output is either updated state, a small helper value, or no direct return value depending on caller context.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is destructive or partial file changes. Apply helpers check destination availability, copy through temp files when configured, and preserve failed entries.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Build-RobocopyArgs` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** copy, mkdir, delete, skip, already-current, missing-source, and offline-destination outcomes.
- **Dependency notes:** Notable internal calls: `Get-Array`, `Get-MapArray`, `Resolve-DestinationPath`.

### Decode-RobocopyExit

- **Lines:** 1862-1869
- **Area:** Apply Pending copy and delete workflow
- **Primary role:** Calculates or formats d ec od e r ob oc op ye xi t data for callers that need a stable value instead of duplicating the logic.

`Decode-RobocopyExit` belongs to the **Apply Pending copy and delete workflow** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on queue entries, destination availability, copy settings, delete settings, and progress callbacks.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Code`. The caller expects a derived object, string, number, or collection and should not need to know how it was produced.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is destructive or partial file changes. Apply helpers check destination availability, copy through temp files when configured, and preserve failed entries.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Decode-RobocopyExit` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** copy, mkdir, delete, skip, already-current, missing-source, and offline-destination outcomes.
- **Dependency notes:** No notable internal function calls were detected in this function body.

### Get-RobocopySummary

- **Lines:** 1870-1898
- **Area:** Apply Pending copy and delete workflow
- **Primary role:** Calculates or formats g et r ob oc op ys um ma ry data for callers that need a stable value instead of duplicating the logic.

`Get-RobocopySummary` belongs to the **Apply Pending copy and delete workflow** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on queue entries, destination availability, copy settings, delete settings, and progress callbacks.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Output`. The caller expects a derived object, string, number, or collection and should not need to know how it was produced.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is destructive or partial file changes. Apply helpers check destination availability, copy through temp files when configured, and preserve failed entries.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Get-RobocopySummary` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** copy, mkdir, delete, skip, already-current, missing-source, and offline-destination outcomes.
- **Dependency notes:** No notable internal function calls were detected in this function body.

### Get-RobocopyChangeSummary

- **Lines:** 1899-1924
- **Area:** Apply Pending copy and delete workflow
- **Primary role:** Calculates or formats g et r ob oc op yc ha ng es um ma ry data for callers that need a stable value instead of duplicating the logic.

`Get-RobocopyChangeSummary` belongs to the **Apply Pending copy and delete workflow** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on queue entries, destination availability, copy settings, delete settings, and progress callbacks.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Output`. The caller expects a derived object, string, number, or collection and should not need to know how it was produced.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is destructive or partial file changes. Apply helpers check destination availability, copy through temp files when configured, and preserve failed entries.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Get-RobocopyChangeSummary` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** copy, mkdir, delete, skip, already-current, missing-source, and offline-destination outcomes.
- **Dependency notes:** No notable internal function calls were detected in this function body.

### Test-RobocopyChangeLine

- **Lines:** 1925-1930
- **Area:** Apply Pending copy and delete workflow
- **Primary role:** Evaluates the t es t r ob oc op yc ha ng el in e condition and lets the caller choose a safe branch based on a clear result.

`Test-RobocopyChangeLine` belongs to the **Apply Pending copy and delete workflow** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on queue entries, destination availability, copy settings, delete settings, and progress callbacks.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Line`. The caller expects a boolean or compact status object that can be used immediately in a branch.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is destructive or partial file changes. Apply helpers check destination availability, copy through temp files when configured, and preserve failed entries.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Test-RobocopyChangeLine` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** copy, mkdir, delete, skip, already-current, missing-source, and offline-destination outcomes.
- **Dependency notes:** No notable internal function calls were detected in this function body.

### Get-RobocopyChangeText

- **Lines:** 1931-1955
- **Area:** Apply Pending copy and delete workflow
- **Primary role:** Calculates or formats g et r ob oc op yc ha ng et ex t data for callers that need a stable value instead of duplicating the logic.

`Get-RobocopyChangeText` belongs to the **Apply Pending copy and delete workflow** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on queue entries, destination availability, copy settings, delete settings, and progress callbacks.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Line`. The caller expects a derived object, string, number, or collection and should not need to know how it was produced.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is destructive or partial file changes. Apply helpers check destination availability, copy through temp files when configured, and preserve failed entries.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Get-RobocopyChangeText` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** copy, mkdir, delete, skip, already-current, missing-source, and offline-destination outcomes.
- **Dependency notes:** No notable internal function calls were detected in this function body.

### Convert-RobocopyLineToChange

- **Lines:** 1956-1989
- **Area:** Apply Pending copy and delete workflow
- **Primary role:** Calculates or formats c on ve rt r ob oc op yl in et oc ha ng e data for callers that need a stable value instead of duplicating the logic.

`Convert-RobocopyLineToChange` belongs to the **Apply Pending copy and delete workflow** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on queue entries, destination availability, copy settings, delete settings, and progress callbacks.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Line`, `SourceRoot`, `DestRoot`. The caller expects a derived object, string, number, or collection and should not need to know how it was produced.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is destructive or partial file changes. Apply helpers check destination availability, copy through temp files when configured, and preserve failed entries.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Convert-RobocopyLineToChange` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** copy, mkdir, delete, skip, already-current, missing-source, and offline-destination outcomes.
- **Dependency notes:** Notable internal calls: `Get-RelativePath`, `Join-PathSafe`, `Test-InternalTempCleanupFileName`, `Test-TempCleanupFileEligible`.

### Write-ScanProgress

- **Lines:** 1990-2010
- **Area:** Console interface and progress display
- **Primary role:** Provides the w ri te s ca np ro gr es s helper behavior used by nearby workflows.

`Write-ScanProgress` belongs to the **Console interface and progress display** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on console dimensions, color output, and transient display state. It should not change backup data unless it delegates after user input.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `FrameIndex`, `PairName`, `Text`, `Color`. The main output is console presentation. Any return value is secondary to navigation or display.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is poor readability or accidental selection. The UI helpers keep fixed prompts, Escape handling, and compact tables to reduce that risk.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Write-ScanProgress` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** interactive menus, previews, progress display, and user cancellation.
- **Dependency notes:** No notable internal function calls were detected in this function body.

### ConvertTo-ProcessArgumentString

- **Lines:** 2011-2023
- **Area:** Installation, scheduled task, and process lifecycle
- **Primary role:** Calculates or formats c on ve rt to p ro ce ss ar gu me nt st ri ng data for callers that need a stable value instead of duplicating the logic.

`ConvertTo-ProcessArgumentString` belongs to the **Installation, scheduled task, and process lifecycle** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on administrator rights, Task Scheduler cmdlets, watcher process discovery, runtime helper paths, and the configured task name.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Arguments`. The caller expects a derived object, string, number, or collection and should not need to know how it was produced.

Side effects are intentionally bounded. It is expected to be side-effect-light and primarily returns data or decisions to the caller. The important failure mode is leaving background tasks or processes behind. Lifecycle helpers isolate task registration, restart, removal, and runtime cleanup.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `ConvertTo-ProcessArgumentString` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** install, restart, remove watcher, uninstall, elevation, and background process checks.
- **Dependency notes:** No notable internal function calls were detected in this function body.

### Clear-ScanProgress

- **Lines:** 2024-2033
- **Area:** Console interface and progress display
- **Primary role:** Mutates the c le ar s ca np ro gr es s state in one named place so the rest of the script does not duplicate update rules.

`Clear-ScanProgress` belongs to the **Console interface and progress display** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on console dimensions, color output, and transient display state. It should not change backup data unless it delegates after user input.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. No explicit function parameters; it reads from script-scoped state or acts as an internal workflow step. The output is either updated state, a small helper value, or no direct return value depending on caller context.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is poor readability or accidental selection. The UI helpers keep fixed prompts, Escape handling, and compact tables to reduce that risk.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Clear-ScanProgress` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** interactive menus, previews, progress display, and user cancellation.
- **Dependency notes:** No notable internal function calls were detected in this function body.

### Invoke-RobocopyStreaming

- **Lines:** 2034-2120
- **Area:** Apply Pending copy and delete workflow
- **Primary role:** Runs the i nv ok e r ob oc op ys tr ea mi ng workflow and coordinates helper calls around a user-visible operation.

`Invoke-RobocopyStreaming` belongs to the **Apply Pending copy and delete workflow** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on queue entries, destination availability, copy settings, delete settings, and progress callbacks.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `RobocopyArgs`, `PairName`. The output is workflow-level: visible progress, result objects, changed files, or system state depending on mode.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is destructive or partial file changes. Apply helpers check destination availability, copy through temp files when configured, and preserve failed entries.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Invoke-RobocopyStreaming` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** copy, mkdir, delete, skip, already-current, missing-source, and offline-destination outcomes.
- **Dependency notes:** Notable internal calls: `Write-Color`, `Test-RobocopyChangeLine`, `Get-RobocopyChangeText`, `Write-ScanProgress`, `ConvertTo-ProcessArgumentString`, `Clear-ScanProgress`.

### Invoke-ApplyFileChanges

- **Lines:** 2121-2199
- **Area:** Apply Pending copy and delete workflow
- **Primary role:** Runs the i nv ok e a pp ly fi le ch an ge s workflow and coordinates helper calls around a user-visible operation.

`Invoke-ApplyFileChanges` belongs to the **Apply Pending copy and delete workflow** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on queue entries, destination availability, copy settings, delete settings, and progress callbacks.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Pair`, `FileChanges`, `Policy`. The output is workflow-level: visible progress, result objects, changed files, or system state depending on mode.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is destructive or partial file changes. Apply helpers check destination availability, copy through temp files when configured, and preserve failed entries.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Invoke-ApplyFileChanges` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** copy, mkdir, delete, skip, already-current, missing-source, and offline-destination outcomes.
- **Dependency notes:** Notable internal calls: `Format-ErrorSummary`, `Resolve-DestinationPath`, `Join-PathSafe`, `Test-FileNeedsCopy`, `Copy-FileSafe`, `ConvertTo-ProcessArgumentString`.

### Get-TempCleanupMinAgeMinutes

- **Lines:** 2200-2209
- **Area:** Full Mirror and robocopy workflow
- **Primary role:** Calculates or formats g et t em pc le an up mi na ge mi nu te s data for callers that need a stable value instead of duplicating the logic.

`Get-TempCleanupMinAgeMinutes` belongs to the **Full Mirror and robocopy workflow** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on pair configuration, selected mirror policy, robocopy availability, exclusion settings, and parsed robocopy output.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. No explicit function parameters; it reads from script-scoped state or acts as an internal workflow step. The caller expects a derived object, string, number, or collection and should not need to know how it was produced.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is applying the wrong mirror policy. Full Mirror keeps policy selection explicit and supports preview before apply.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Get-TempCleanupMinAgeMinutes` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** strict mirror, update-keep-extras, missing-only, preview, apply, and robocopy parsing.
- **Dependency notes:** No notable internal function calls were detected in this function body.

### Test-InternalTempCleanupFileName

- **Lines:** 2210-2215
- **Area:** Full Mirror and robocopy workflow
- **Primary role:** Evaluates the t es t i nt er na lt em pc le an up fi le na me condition and lets the caller choose a safe branch based on a clear result.

`Test-InternalTempCleanupFileName` belongs to the **Full Mirror and robocopy workflow** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on pair configuration, selected mirror policy, robocopy availability, exclusion settings, and parsed robocopy output.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Name`. The caller expects a boolean or compact status object that can be used immediately in a branch.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is applying the wrong mirror policy. Full Mirror keeps policy selection explicit and supports preview before apply.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Test-InternalTempCleanupFileName` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** strict mirror, update-keep-extras, missing-only, preview, apply, and robocopy parsing.
- **Dependency notes:** No notable internal function calls were detected in this function body.

### Test-PathInsideRoot

- **Lines:** 2216-2228
- **Area:** Path, pair, drive map, and exclusion handling
- **Primary role:** Evaluates the t es t p at hi ns id er oo t condition and lets the caller choose a safe branch based on a clear result.

`Test-PathInsideRoot` belongs to the **Path, pair, drive map, and exclusion handling** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on configured pairs, drive maps, exclusion maps, and path text supplied by the user or file system events.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Root`, `Path`. The caller expects a boolean or compact status object that can be used immediately in a branch.

Side effects are intentionally bounded. It is expected to be side-effect-light and primarily returns data or decisions to the caller. The important failure mode is pointing at the wrong folder. Path helpers centralize normalization and destination resolution so previews and applies use the same interpretation.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Test-PathInsideRoot` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** adding pairs, resolving destinations, drive maps, and exclusions.
- **Dependency notes:** No notable internal function calls were detected in this function body.

### Test-TempCleanupFileEligible

- **Lines:** 2229-2247
- **Area:** Full Mirror and robocopy workflow
- **Primary role:** Evaluates the t es t t em pc le an up fi le el ig ib le condition and lets the caller choose a safe branch based on a clear result.

`Test-TempCleanupFileEligible` belongs to the **Full Mirror and robocopy workflow** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on pair configuration, selected mirror policy, robocopy availability, exclusion settings, and parsed robocopy output.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `FullPath`, `DestRoot`, `NowUtc`. The caller expects a boolean or compact status object that can be used immediately in a branch.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is applying the wrong mirror policy. Full Mirror keeps policy selection explicit and supports preview before apply.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Test-TempCleanupFileEligible` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** strict mirror, update-keep-extras, missing-only, preview, apply, and robocopy parsing.
- **Dependency notes:** Notable internal calls: `Get-TempCleanupMinAgeMinutes`, `Test-InternalTempCleanupFileName`, `Test-PathInsideRoot`.

### Invoke-TempCleanupChanges

- **Lines:** 2248-2271
- **Area:** Full Mirror and robocopy workflow
- **Primary role:** Runs the i nv ok e t em pc le an up ch an ge s workflow and coordinates helper calls around a user-visible operation.

`Invoke-TempCleanupChanges` belongs to the **Full Mirror and robocopy workflow** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on pair configuration, selected mirror policy, robocopy availability, exclusion settings, and parsed robocopy output.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Pair`, `FileChanges`. The output is workflow-level: visible progress, result objects, changed files, or system state depending on mode.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is applying the wrong mirror policy. Full Mirror keeps policy selection explicit and supports preview before apply.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Invoke-TempCleanupChanges` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** strict mirror, update-keep-extras, missing-only, preview, apply, and robocopy parsing.
- **Dependency notes:** Notable internal calls: `Format-ErrorSummary`, `Resolve-DestinationPath`, `Join-PathSafe`, `Test-TempCleanupFileEligible`.

### Invoke-FullMirror

- **Lines:** 2272-2370
- **Area:** Full Mirror and robocopy workflow
- **Primary role:** Runs the whole-tree mirror workflow by collecting policy and preview/apply choice, then delegating pair processing.

`Invoke-FullMirror` belongs to the **Full Mirror and robocopy workflow** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on pair configuration, selected mirror policy, robocopy availability, exclusion settings, and parsed robocopy output.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. No explicit function parameters; it reads from script-scoped state or acts as an internal workflow step. The output is workflow-level: visible progress, result objects, changed files, or system state depending on mode.

Side effects are intentionally bounded. It is expected to be side-effect-light and primarily returns data or decisions to the caller. The important failure mode is applying the wrong mirror policy. Full Mirror keeps policy selection explicit and supports preview before apply.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Invoke-FullMirror` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** strict mirror, update-keep-extras, missing-only, preview, apply, and robocopy parsing.
- **Dependency notes:** Notable internal calls: `Get-Pairs`, `Write-Color`, `Show-Header`, `Wait-Back`, `Read-KeyChoice`, `Read-EnterOrEsc`, `Request-ClearPendingQueue`, `Show-ApplyResults`, `Invoke-ApplyFileChanges`, `Invoke-TempCleanupChanges`.

### Get-PolicyLabel

- **Lines:** 2371-2377
- **Area:** Full Mirror and robocopy workflow
- **Primary role:** Calculates or formats g et p ol ic yl ab el data for callers that need a stable value instead of duplicating the logic.

`Get-PolicyLabel` belongs to the **Full Mirror and robocopy workflow** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on pair configuration, selected mirror policy, robocopy availability, exclusion settings, and parsed robocopy output.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Policy`. The caller expects a derived object, string, number, or collection and should not need to know how it was produced.

Side effects are intentionally bounded. It is expected to be side-effect-light and primarily returns data or decisions to the caller. The important failure mode is applying the wrong mirror policy. Full Mirror keeps policy selection explicit and supports preview before apply.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Get-PolicyLabel` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** strict mirror, update-keep-extras, missing-only, preview, apply, and robocopy parsing.
- **Dependency notes:** No notable internal function calls were detected in this function body.

### Get-PolicyShort

- **Lines:** 2378-2384
- **Area:** Full Mirror and robocopy workflow
- **Primary role:** Calculates or formats g et p ol ic ys ho rt data for callers that need a stable value instead of duplicating the logic.

`Get-PolicyShort` belongs to the **Full Mirror and robocopy workflow** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on pair configuration, selected mirror policy, robocopy availability, exclusion settings, and parsed robocopy output.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Policy`. The caller expects a derived object, string, number, or collection and should not need to know how it was produced.

Side effects are intentionally bounded. It is expected to be side-effect-light and primarily returns data or decisions to the caller. The important failure mode is applying the wrong mirror policy. Full Mirror keeps policy selection explicit and supports preview before apply.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Get-PolicyShort` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** strict mirror, update-keep-extras, missing-only, preview, apply, and robocopy parsing.
- **Dependency notes:** No notable internal function calls were detected in this function body.

### Invoke-RobocopyForPairs

- **Lines:** 2385-2682
- **Area:** Path, pair, drive map, and exclusion handling
- **Primary role:** Runs robocopy across valid pairs, manages parallel batches, parses output, and returns structured result summaries.

`Invoke-RobocopyForPairs` belongs to the **Path, pair, drive map, and exclusion handling** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on configured pairs, drive maps, exclusion maps, and path text supplied by the user or file system events.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Pairs`, `Preview`, `Policy`. The output is workflow-level: visible progress, result objects, changed files, or system state depending on mode.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is pointing at the wrong folder. Path helpers centralize normalization and destination resolution so previews and applies use the same interpretation.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Invoke-RobocopyForPairs` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** adding pairs, resolving destinations, drive maps, and exclusions.
- **Dependency notes:** Notable internal calls: `Write-Color`, `Resolve-DestinationPath`, `Get-RelativePath`, `Join-PathSafe`, `Test-DestRootAvailable`, `Build-RobocopyArgs`, `Decode-RobocopyExit`, `Get-RobocopySummary`, `Get-RobocopyChangeSummary`, `Test-RobocopyChangeLine`.

### Show-RobocopyResults

- **Lines:** 2683-2774
- **Area:** Apply Pending copy and delete workflow
- **Primary role:** Presents the s ho w r ob oc op yr es ul ts screen or menu and keeps display concerns separate from lower-level operations.

`Show-RobocopyResults` belongs to the **Apply Pending copy and delete workflow** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on queue entries, destination availability, copy settings, delete settings, and progress callbacks.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Results`, `Title`, `Pause`. The main output is console presentation. Any return value is secondary to navigation or display.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is destructive or partial file changes. Apply helpers check destination availability, copy through temp files when configured, and preserve failed entries.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Show-RobocopyResults` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** copy, mkdir, delete, skip, already-current, missing-source, and offline-destination outcomes.
- **Dependency notes:** Notable internal calls: `Write-Color`, `Center-Text`, `Fit-Cell`, `Show-Header`, `Wait-Back`.

### Show-Status

- **Lines:** 2775-2803
- **Area:** Menus, reports, and status screens
- **Primary role:** Presents the s ho w s ta tu s screen or menu and keeps display concerns separate from lower-level operations.

`Show-Status` belongs to the **Menus, reports, and status screens** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on current config, queue summaries, drive availability, and user key choices.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. No explicit function parameters; it reads from script-scoped state or acts as an internal workflow step. The main output is console presentation. Any return value is secondary to navigation or display.

Side effects are intentionally bounded. Its side effect is user interaction: console output, cursor movement, or waiting for input. It should not silently perform backup changes by itself. The important failure mode is inconsistent behavior across callers, so this helper keeps one rule in one place.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Show-Status` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** main menu routing, status reports, submenus, and user navigation.
- **Dependency notes:** Notable internal calls: `Get-Pairs`, `Write-Color`, `Show-Header`, `Wait-Back`, `Resolve-DestinationPath`, `Test-DestRootAvailable`, `Read-QueueEntries`, `Get-LatestQueueEntries`, `Get-WatcherProcesses`.

### Show-Pairs

- **Lines:** 2804-2817
- **Area:** Path, pair, drive map, and exclusion handling
- **Primary role:** Presents the s ho w p ai rs screen or menu and keeps display concerns separate from lower-level operations.

`Show-Pairs` belongs to the **Path, pair, drive map, and exclusion handling** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on configured pairs, drive maps, exclusion maps, and path text supplied by the user or file system events.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. No explicit function parameters; it reads from script-scoped state or acts as an internal workflow step. The main output is console presentation. Any return value is secondary to navigation or display.

Side effects are intentionally bounded. Its side effect is user interaction: console output, cursor movement, or waiting for input. It should not silently perform backup changes by itself. The important failure mode is pointing at the wrong folder. Path helpers centralize normalization and destination resolution so previews and applies use the same interpretation.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Show-Pairs` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** adding pairs, resolving destinations, drive maps, and exclusions.
- **Dependency notes:** Notable internal calls: `Get-Pairs`, `Write-Color`.

### Manage-PathsMenu

- **Lines:** 2818-2837
- **Area:** Path, pair, drive map, and exclusion handling
- **Primary role:** Presents the m an ag e p at hs me nu screen or menu and keeps display concerns separate from lower-level operations.

`Manage-PathsMenu` belongs to the **Path, pair, drive map, and exclusion handling** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on configured pairs, drive maps, exclusion maps, and path text supplied by the user or file system events.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. No explicit function parameters; it reads from script-scoped state or acts as an internal workflow step. The main output is console presentation. Any return value is secondary to navigation or display.

Side effects are intentionally bounded. It is expected to be side-effect-light and primarily returns data or decisions to the caller. The important failure mode is pointing at the wrong folder. Path helpers centralize normalization and destination resolution so previews and applies use the same interpretation.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Manage-PathsMenu` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** adding pairs, resolving destinations, drive maps, and exclusions.
- **Dependency notes:** Notable internal calls: `Write-Color`, `Show-Header`, `Read-KeyChoice`, `Show-Pairs`, `Add-Pair`, `Edit-Pair`, `Remove-Pair`.

### Add-Pair

- **Lines:** 2838-2864
- **Area:** Path, pair, drive map, and exclusion handling
- **Primary role:** Mutates the a dd p ai r state in one named place so the rest of the script does not duplicate update rules.

`Add-Pair` belongs to the **Path, pair, drive map, and exclusion handling** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on configured pairs, drive maps, exclusion maps, and path text supplied by the user or file system events.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. No explicit function parameters; it reads from script-scoped state or acts as an internal workflow step. The output is either updated state, a small helper value, or no direct return value depending on caller context.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is pointing at the wrong folder. Path helpers centralize normalization and destination resolution so previews and applies use the same interpretation.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Add-Pair` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** adding pairs, resolving destinations, drive maps, and exclusions.
- **Dependency notes:** Notable internal calls: `Save-Config`, `Get-Pairs`, `Set-Pairs`, `Set-MapArray`, `Write-Color`, `Show-Header`, `Show-SpinnerLine`, `Read-LineOrEsc`, `Read-EnterOrEsc`, `Normalize-PathText`.

### Select-PairIndex

- **Lines:** 2865-2875
- **Area:** Path, pair, drive map, and exclusion handling
- **Primary role:** Provides the s el ec t p ai ri nd ex helper behavior used by nearby workflows.

`Select-PairIndex` belongs to the **Path, pair, drive map, and exclusion handling** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on configured pairs, drive maps, exclusion maps, and path text supplied by the user or file system events.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. No explicit function parameters; it reads from script-scoped state or acts as an internal workflow step. The output is either updated state, a small helper value, or no direct return value depending on caller context.

Side effects are intentionally bounded. It is expected to be side-effect-light and primarily returns data or decisions to the caller. The important failure mode is pointing at the wrong folder. Path helpers centralize normalization and destination resolution so previews and applies use the same interpretation.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Select-PairIndex` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** adding pairs, resolving destinations, drive maps, and exclusions.
- **Dependency notes:** Notable internal calls: `Get-Pairs`, `Read-NumberOrEsc`, `Show-Pairs`.

### Edit-Pair

- **Lines:** 2876-2901
- **Area:** Path, pair, drive map, and exclusion handling
- **Primary role:** Provides the e di t p ai r helper behavior used by nearby workflows.

`Edit-Pair` belongs to the **Path, pair, drive map, and exclusion handling** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on configured pairs, drive maps, exclusion maps, and path text supplied by the user or file system events.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. No explicit function parameters; it reads from script-scoped state or acts as an internal workflow step. The output is either updated state, a small helper value, or no direct return value depending on caller context.

Side effects are intentionally bounded. It is expected to be side-effect-light and primarily returns data or decisions to the caller. The important failure mode is pointing at the wrong folder. Path helpers centralize normalization and destination resolution so previews and applies use the same interpretation.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Edit-Pair` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** adding pairs, resolving destinations, drive maps, and exclusions.
- **Dependency notes:** Notable internal calls: `Save-Config`, `Get-Pairs`, `Set-Pairs`, `Get-MapArray`, `Set-MapArray`, `Write-Color`, `Show-Header`, `Read-LineOrEsc`, `Normalize-PathText`, `Get-AutoPairName`.

### Remove-Pair

- **Lines:** 2902-2916
- **Area:** Path, pair, drive map, and exclusion handling
- **Primary role:** Mutates the r em ov e p ai r state in one named place so the rest of the script does not duplicate update rules.

`Remove-Pair` belongs to the **Path, pair, drive map, and exclusion handling** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on configured pairs, drive maps, exclusion maps, and path text supplied by the user or file system events.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. No explicit function parameters; it reads from script-scoped state or acts as an internal workflow step. The output is either updated state, a small helper value, or no direct return value depending on caller context.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is pointing at the wrong folder. Path helpers centralize normalization and destination resolution so previews and applies use the same interpretation.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Remove-Pair` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** adding pairs, resolving destinations, drive maps, and exclusions.
- **Dependency notes:** Notable internal calls: `Save-Config`, `Get-Pairs`, `Set-Pairs`, `Write-Color`, `Show-Header`, `Read-EnterOrEsc`, `Select-PairIndex`.

### Add-SmartExclusion

- **Lines:** 2917-2975
- **Area:** Path, pair, drive map, and exclusion handling
- **Primary role:** Mutates the a dd s ma rt ex cl us io n state in one named place so the rest of the script does not duplicate update rules.

`Add-SmartExclusion` belongs to the **Path, pair, drive map, and exclusion handling** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on configured pairs, drive maps, exclusion maps, and path text supplied by the user or file system events.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. No explicit function parameters; it reads from script-scoped state or acts as an internal workflow step. The output is either updated state, a small helper value, or no direct return value depending on caller context.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is pointing at the wrong folder. Path helpers centralize normalization and destination resolution so previews and applies use the same interpretation.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Add-SmartExclusion` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** adding pairs, resolving destinations, drive maps, and exclusions.
- **Dependency notes:** Notable internal calls: `Save-Config`, `Get-Array`, `Get-Pairs`, `Get-MapArray`, `Set-MapArray`, `Write-Color`, `Show-Header`, `Wait-Back`, `Read-LineOrEsc`, `Normalize-PathText`.

### Manage-ExclusionsMenu

- **Lines:** 2976-3008
- **Area:** Path, pair, drive map, and exclusion handling
- **Primary role:** Presents the m an ag e e xc lu si on sm en u screen or menu and keeps display concerns separate from lower-level operations.

`Manage-ExclusionsMenu` belongs to the **Path, pair, drive map, and exclusion handling** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on configured pairs, drive maps, exclusion maps, and path text supplied by the user or file system events.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. No explicit function parameters; it reads from script-scoped state or acts as an internal workflow step. The main output is console presentation. Any return value is secondary to navigation or display.

Side effects are intentionally bounded. It is expected to be side-effect-light and primarily returns data or decisions to the caller. The important failure mode is pointing at the wrong folder. Path helpers centralize normalization and destination resolution so previews and applies use the same interpretation.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Manage-ExclusionsMenu` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** adding pairs, resolving destinations, drive maps, and exclusions.
- **Dependency notes:** Notable internal calls: `Write-Color`, `Show-Header`, `Wait-Back`, `Read-KeyChoice`, `Add-Pair`, `Add-SmartExclusion`, `Add-GlobalExclusion`, `Add-PairExclusion`, `Show-Exclusions`, `Remove-Exclusion`.

### Add-GlobalExclusion

- **Lines:** 3009-3019
- **Area:** Path, pair, drive map, and exclusion handling
- **Primary role:** Mutates the a dd g lo ba le xc lu si on state in one named place so the rest of the script does not duplicate update rules.

`Add-GlobalExclusion` belongs to the **Path, pair, drive map, and exclusion handling** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on configured pairs, drive maps, exclusion maps, and path text supplied by the user or file system events.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `PropName`. The output is either updated state, a small helper value, or no direct return value depending on caller context.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is pointing at the wrong folder. Path helpers centralize normalization and destination resolution so previews and applies use the same interpretation.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Add-GlobalExclusion` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** adding pairs, resolving destinations, drive maps, and exclusions.
- **Dependency notes:** Notable internal calls: `Save-Config`, `Get-Array`, `Show-Header`, `Read-LineOrEsc`.

### Add-PairExclusion

- **Lines:** 3020-3034
- **Area:** Path, pair, drive map, and exclusion handling
- **Primary role:** Mutates the a dd p ai re xc lu si on state in one named place so the rest of the script does not duplicate update rules.

`Add-PairExclusion` belongs to the **Path, pair, drive map, and exclusion handling** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on configured pairs, drive maps, exclusion maps, and path text supplied by the user or file system events.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `MapName`. The output is either updated state, a small helper value, or no direct return value depending on caller context.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is pointing at the wrong folder. Path helpers centralize normalization and destination resolution so previews and applies use the same interpretation.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Add-PairExclusion` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** adding pairs, resolving destinations, drive maps, and exclusions.
- **Dependency notes:** Notable internal calls: `Save-Config`, `Get-Pairs`, `Get-MapArray`, `Set-MapArray`, `Show-Header`, `Read-LineOrEsc`, `Add-Pair`, `Select-PairIndex`.

### Get-ExclusionEntries

- **Lines:** 3035-3056
- **Area:** Path, pair, drive map, and exclusion handling
- **Primary role:** Calculates or formats g et e xc lu si on en tr ie s data for callers that need a stable value instead of duplicating the logic.

`Get-ExclusionEntries` belongs to the **Path, pair, drive map, and exclusion handling** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on configured pairs, drive maps, exclusion maps, and path text supplied by the user or file system events.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. No explicit function parameters; it reads from script-scoped state or acts as an internal workflow step. The caller expects a derived object, string, number, or collection and should not need to know how it was produced.

Side effects are intentionally bounded. It is expected to be side-effect-light and primarily returns data or decisions to the caller. The important failure mode is pointing at the wrong folder. Path helpers centralize normalization and destination resolution so previews and applies use the same interpretation.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Get-ExclusionEntries` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** adding pairs, resolving destinations, drive maps, and exclusions.
- **Dependency notes:** Notable internal calls: `Get-Array`.

### Show-Exclusions

- **Lines:** 3057-3070
- **Area:** Path, pair, drive map, and exclusion handling
- **Primary role:** Presents the s ho w e xc lu si on s screen or menu and keeps display concerns separate from lower-level operations.

`Show-Exclusions` belongs to the **Path, pair, drive map, and exclusion handling** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on configured pairs, drive maps, exclusion maps, and path text supplied by the user or file system events.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. No explicit function parameters; it reads from script-scoped state or acts as an internal workflow step. The main output is console presentation. Any return value is secondary to navigation or display.

Side effects are intentionally bounded. Its side effect is user interaction: console output, cursor movement, or waiting for input. It should not silently perform backup changes by itself. The important failure mode is pointing at the wrong folder. Path helpers centralize normalization and destination resolution so previews and applies use the same interpretation.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Show-Exclusions` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** adding pairs, resolving destinations, drive maps, and exclusions.
- **Dependency notes:** Notable internal calls: `Write-Color`, `Show-Header`, `Get-ExclusionEntries`.

### Remove-Exclusion

- **Lines:** 3071-3094
- **Area:** Path, pair, drive map, and exclusion handling
- **Primary role:** Mutates the r em ov e e xc lu si on state in one named place so the rest of the script does not duplicate update rules.

`Remove-Exclusion` belongs to the **Path, pair, drive map, and exclusion handling** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on configured pairs, drive maps, exclusion maps, and path text supplied by the user or file system events.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. No explicit function parameters; it reads from script-scoped state or acts as an internal workflow step. The output is either updated state, a small helper value, or no direct return value depending on caller context.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is pointing at the wrong folder. Path helpers centralize normalization and destination resolution so previews and applies use the same interpretation.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Remove-Exclusion` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** adding pairs, resolving destinations, drive maps, and exclusions.
- **Dependency notes:** Notable internal calls: `Save-Config`, `Get-Array`, `Get-MapArray`, `Set-MapArray`, `Wait-Back`, `Read-NumberOrEsc`, `Get-ExclusionEntries`, `Show-Exclusions`.

### SettingsMenu

- **Lines:** 3095-3124
- **Area:** Configuration and settings
- **Primary role:** Presents the s et ti ng sm en u screen or menu and keeps display concerns separate from lower-level operations.

`SettingsMenu` belongs to the **Configuration and settings** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It mainly depends on `$script:Config`, `$script:ConfigPath`, and the default config shape. When it writes data, the write is intentional configuration persistence.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. No explicit function parameters; it reads from script-scoped state or acts as an internal workflow step. The main output is console presentation. Any return value is secondary to navigation or display.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is invalid or incomplete configuration. The surrounding workflow either repairs missing shape or reports malformed JSON instead of guessing.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `SettingsMenu` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** first run, config repair, settings edits, and watcher refresh.
- **Dependency notes:** Notable internal calls: `Write-Color`, `Show-Header`, `Read-KeyChoice`, `Manage-DriveMapsMenu`, `Set-IntSetting`, `Set-StringSetting`, `Toggle-BoolSetting`.

### Manage-DriveMapsMenu

- **Lines:** 3125-3150
- **Area:** Path, pair, drive map, and exclusion handling
- **Primary role:** Presents the m an ag e d ri ve ma ps me nu screen or menu and keeps display concerns separate from lower-level operations.

`Manage-DriveMapsMenu` belongs to the **Path, pair, drive map, and exclusion handling** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on configured pairs, drive maps, exclusion maps, and path text supplied by the user or file system events.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. No explicit function parameters; it reads from script-scoped state or acts as an internal workflow step. The main output is console presentation. Any return value is secondary to navigation or display.

Side effects are intentionally bounded. It is expected to be side-effect-light and primarily returns data or decisions to the caller. The important failure mode is pointing at the wrong folder. Path helpers centralize normalization and destination resolution so previews and applies use the same interpretation.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Manage-DriveMapsMenu` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** adding pairs, resolving destinations, drive maps, and exclusions.
- **Dependency notes:** Notable internal calls: `Write-Color`, `Show-Header`, `Read-KeyChoice`, `Add-OrUpdateDriveMap`, `Remove-DriveMap`.

### Add-OrUpdateDriveMap

- **Lines:** 3151-3160
- **Area:** Path, pair, drive map, and exclusion handling
- **Primary role:** Mutates the a dd o ru pd at ed ri ve ma p state in one named place so the rest of the script does not duplicate update rules.

`Add-OrUpdateDriveMap` belongs to the **Path, pair, drive map, and exclusion handling** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on configured pairs, drive maps, exclusion maps, and path text supplied by the user or file system events.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. No explicit function parameters; it reads from script-scoped state or acts as an internal workflow step. The output is either updated state, a small helper value, or no direct return value depending on caller context.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is pointing at the wrong folder. Path helpers centralize normalization and destination resolution so previews and applies use the same interpretation.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Add-OrUpdateDriveMap` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** adding pairs, resolving destinations, drive maps, and exclusions.
- **Dependency notes:** Notable internal calls: `Save-Config`, `Show-Header`, `Read-LineOrEsc`.

### Remove-DriveMap

- **Lines:** 3161-3180
- **Area:** Path, pair, drive map, and exclusion handling
- **Primary role:** Mutates the r em ov e d ri ve ma p state in one named place so the rest of the script does not duplicate update rules.

`Remove-DriveMap` belongs to the **Path, pair, drive map, and exclusion handling** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on configured pairs, drive maps, exclusion maps, and path text supplied by the user or file system events.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. No explicit function parameters; it reads from script-scoped state or acts as an internal workflow step. The output is either updated state, a small helper value, or no direct return value depending on caller context.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is pointing at the wrong folder. Path helpers centralize normalization and destination resolution so previews and applies use the same interpretation.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Remove-DriveMap` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** adding pairs, resolving destinations, drive maps, and exclusions.
- **Dependency notes:** Notable internal calls: `Save-Config`, `Write-Color`, `Show-Header`, `Wait-Back`, `Read-NumberOrEsc`.

### Set-IntSetting

- **Lines:** 3181-3195
- **Area:** Configuration and settings
- **Primary role:** Mutates the s et i nt se tt in g state in one named place so the rest of the script does not duplicate update rules.

`Set-IntSetting` belongs to the **Configuration and settings** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It mainly depends on `$script:Config`, `$script:ConfigPath`, and the default config shape. When it writes data, the write is intentional configuration persistence.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Name`, `Min`. The output is either updated state, a small helper value, or no direct return value depending on caller context.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is invalid or incomplete configuration. The surrounding workflow either repairs missing shape or reports malformed JSON instead of guessing.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Set-IntSetting` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** first run, config repair, settings edits, and watcher refresh.
- **Dependency notes:** Notable internal calls: `Save-Config`, `Write-Color`, `Show-Header`, `Wait-Back`, `Read-LineOrEsc`.

### Set-StringSetting

- **Lines:** 3196-3205
- **Area:** Configuration and settings
- **Primary role:** Mutates the s et s tr in gs et ti ng state in one named place so the rest of the script does not duplicate update rules.

`Set-StringSetting` belongs to the **Configuration and settings** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It mainly depends on `$script:Config`, `$script:ConfigPath`, and the default config shape. When it writes data, the write is intentional configuration persistence.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Name`. The output is either updated state, a small helper value, or no direct return value depending on caller context.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is invalid or incomplete configuration. The surrounding workflow either repairs missing shape or reports malformed JSON instead of guessing.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Set-StringSetting` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** first run, config repair, settings edits, and watcher refresh.
- **Dependency notes:** Notable internal calls: `Save-Config`, `Initialize-App`, `Show-Header`, `Read-LineOrEsc`.

### Toggle-BoolSetting

- **Lines:** 3206-3211
- **Area:** Configuration and settings
- **Primary role:** Provides the t og gl e b oo ls et ti ng helper behavior used by nearby workflows.

`Toggle-BoolSetting` belongs to the **Configuration and settings** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It mainly depends on `$script:Config`, `$script:ConfigPath`, and the default config shape. When it writes data, the write is intentional configuration persistence.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Name`. The output is either updated state, a small helper value, or no direct return value depending on caller context.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is invalid or incomplete configuration. The surrounding workflow either repairs missing shape or reports malformed JSON instead of guessing.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Toggle-BoolSetting` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** first run, config repair, settings edits, and watcher refresh.
- **Dependency notes:** Notable internal calls: `Save-Config`.

### Install-Required

- **Lines:** 3212-3246
- **Area:** Installation, scheduled task, and process lifecycle
- **Primary role:** Creates the scheduled watcher task after elevation checks and starts it so watch mode can run at logon.

`Install-Required` belongs to the **Installation, scheduled task, and process lifecycle** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on administrator rights, Task Scheduler cmdlets, watcher process discovery, runtime helper paths, and the configured task name.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. No explicit function parameters; it reads from script-scoped state or acts as an internal workflow step. The output is either updated state, a small helper value, or no direct return value depending on caller context.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is leaving background tasks or processes behind. Lifecycle helpers isolate task registration, restart, removal, and runtime cleanup.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Install-Required` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** install, restart, remove watcher, uninstall, elevation, and background process checks.
- **Dependency notes:** Notable internal calls: `Write-Color`, `Write-Log`, `Show-Header`, `Wait-Back`, `New-HiddenWatchLauncher`, `Test-IsAdministrator`, `Invoke-ElevatedMode`, `Show-PostElevatedTaskStatus`, `Remove-KnownScheduledTasks`, `Stop-KnownWatcherProcesses`.

### New-HiddenWatchLauncher

- **Lines:** 3247-3261
- **Area:** Shared core helper
- **Primary role:** Writes the hidden VBS launcher that starts MiraQueue watch mode from the recorded script directory.

`New-HiddenWatchLauncher` belongs to the **Shared core helper** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on explicit parameters and script-scoped state supplied indirectly by the caller.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. No explicit function parameters; it reads from script-scoped state or acts as an internal workflow step. The caller expects a derived object, string, number, or collection and should not need to know how it was produced.

Side effects are intentionally bounded. It is expected to be side-effect-light and primarily returns data or decisions to the caller. The important failure mode is inconsistent behavior across callers, so this helper keeps one rule in one place.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `New-HiddenWatchLauncher` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** shared workflow support across the script.
- **Dependency notes:** No notable internal function calls were detected in this function body.

### Uninstall-Everything

- **Lines:** 3262-3323
- **Area:** Installation, scheduled task, and process lifecycle
- **Primary role:** Removes MiraQueue-created scheduled task resources, runtime data, config, and shortcuts while preserving user source and destination folders.

`Uninstall-Everything` belongs to the **Installation, scheduled task, and process lifecycle** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on administrator rights, Task Scheduler cmdlets, watcher process discovery, runtime helper paths, and the configured task name.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. No explicit function parameters; it reads from script-scoped state or acts as an internal workflow step. The output is either updated state, a small helper value, or no direct return value depending on caller context.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is leaving background tasks or processes behind. Lifecycle helpers isolate task registration, restart, removal, and runtime cleanup.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Uninstall-Everything` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** install, restart, remove watcher, uninstall, elevation, and background process checks.
- **Dependency notes:** Notable internal calls: `Write-Color`, `Show-Header`, `Wait-Back`, `Read-EnterOrEsc`, `Test-IsAdministrator`, `Invoke-ElevatedMode`, `Show-PostElevatedTaskStatus`, `Remove-KnownScheduledTasks`, `Stop-KnownWatcherProcesses`.

### Test-IsAdministrator

- **Lines:** 3324-3333
- **Area:** Installation, scheduled task, and process lifecycle
- **Primary role:** Evaluates the t es t i sa dm in is tr at or condition and lets the caller choose a safe branch based on a clear result.

`Test-IsAdministrator` belongs to the **Installation, scheduled task, and process lifecycle** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on administrator rights, Task Scheduler cmdlets, watcher process discovery, runtime helper paths, and the configured task name.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. No explicit function parameters; it reads from script-scoped state or acts as an internal workflow step. The caller expects a boolean or compact status object that can be used immediately in a branch.

Side effects are intentionally bounded. It is expected to be side-effect-light and primarily returns data or decisions to the caller. The important failure mode is leaving background tasks or processes behind. Lifecycle helpers isolate task registration, restart, removal, and runtime cleanup.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Test-IsAdministrator` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** install, restart, remove watcher, uninstall, elevation, and background process checks.
- **Dependency notes:** No notable internal function calls were detected in this function body.

### Invoke-ElevatedMode

- **Lines:** 3334-3348
- **Area:** Installation, scheduled task, and process lifecycle
- **Primary role:** Runs the i nv ok e e le va te dm od e workflow and coordinates helper calls around a user-visible operation.

`Invoke-ElevatedMode` belongs to the **Installation, scheduled task, and process lifecycle** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on administrator rights, Task Scheduler cmdlets, watcher process discovery, runtime helper paths, and the configured task name.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `TargetMode`. The output is workflow-level: visible progress, result objects, changed files, or system state depending on mode.

Side effects are intentionally bounded. It is expected to be side-effect-light and primarily returns data or decisions to the caller. The important failure mode is leaving background tasks or processes behind. Lifecycle helpers isolate task registration, restart, removal, and runtime cleanup.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Invoke-ElevatedMode` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** install, restart, remove watcher, uninstall, elevation, and background process checks.
- **Dependency notes:** Notable internal calls: `Write-Color`.

### Show-PostElevatedTaskStatus

- **Lines:** 3349-3378
- **Area:** Installation, scheduled task, and process lifecycle
- **Primary role:** Presents the s ho w p os te le va te dt as ks ta tu s screen or menu and keeps display concerns separate from lower-level operations.

`Show-PostElevatedTaskStatus` belongs to the **Installation, scheduled task, and process lifecycle** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on administrator rights, Task Scheduler cmdlets, watcher process discovery, runtime helper paths, and the configured task name.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `Operation`. The main output is console presentation. Any return value is secondary to navigation or display.

Side effects are intentionally bounded. Its side effect is user interaction: console output, cursor movement, or waiting for input. It should not silently perform backup changes by itself. The important failure mode is leaving background tasks or processes behind. Lifecycle helpers isolate task registration, restart, removal, and runtime cleanup.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Show-PostElevatedTaskStatus` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** install, restart, remove watcher, uninstall, elevation, and background process checks.
- **Dependency notes:** Notable internal calls: `Write-Color`, `Get-WatcherProcesses`.

### Remove-KnownScheduledTasks

- **Lines:** 3379-3394
- **Area:** Installation, scheduled task, and process lifecycle
- **Primary role:** Mutates the r em ov e k no wn sc he du le dt as ks state in one named place so the rest of the script does not duplicate update rules.

`Remove-KnownScheduledTasks` belongs to the **Installation, scheduled task, and process lifecycle** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on administrator rights, Task Scheduler cmdlets, watcher process discovery, runtime helper paths, and the configured task name.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. Explicit parameters: `KeepTaskName`. The output is either updated state, a small helper value, or no direct return value depending on caller context.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is leaving background tasks or processes behind. Lifecycle helpers isolate task registration, restart, removal, and runtime cleanup.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Remove-KnownScheduledTasks` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** install, restart, remove watcher, uninstall, elevation, and background process checks.
- **Dependency notes:** Notable internal calls: `Write-Color`.

### InstallMenu

- **Lines:** 3395-3414
- **Area:** Installation, scheduled task, and process lifecycle
- **Primary role:** Presents the i ns ta ll me nu screen or menu and keeps display concerns separate from lower-level operations.

`InstallMenu` belongs to the **Installation, scheduled task, and process lifecycle** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on administrator rights, Task Scheduler cmdlets, watcher process discovery, runtime helper paths, and the configured task name.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. No explicit function parameters; it reads from script-scoped state or acts as an internal workflow step. The main output is console presentation. Any return value is secondary to navigation or display.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is leaving background tasks or processes behind. Lifecycle helpers isolate task registration, restart, removal, and runtime cleanup.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `InstallMenu` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** install, restart, remove watcher, uninstall, elevation, and background process checks.
- **Dependency notes:** Notable internal calls: `Write-Color`, `Show-Header`, `Read-KeyChoice`, `Install-Required`, `Uninstall-Everything`, `Restart-ScheduledWatcher`, `Remove-ScheduledWatcherOnly`.

### Restart-ScheduledWatcher

- **Lines:** 3415-3420
- **Area:** Watcher lifecycle and file system events
- **Primary role:** Provides the r es ta rt s ch ed ul ed wa tc he r helper behavior used by nearby workflows.

`Restart-ScheduledWatcher` belongs to the **Watcher lifecycle and file system events** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on configured pairs, FileSystemWatcher events, debounce timing, exclusions, and the watcher mutex.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. No explicit function parameters; it reads from script-scoped state or acts as an internal workflow step. The output is either updated state, a small helper value, or no direct return value depending on caller context.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is event bursts or missed nested directory events. Debounce buffering and directory snapshots reduce that risk.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Restart-ScheduledWatcher` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** manual or scheduled watch mode, created/changed/deleted/renamed events, and directory snapshots.
- **Dependency notes:** Notable internal calls: `Refresh-WatcherAfterConfigChange`, `Show-Header`, `Wait-Back`.

### Remove-ScheduledWatcherOnly

- **Lines:** 3421-3440
- **Area:** Watcher lifecycle and file system events
- **Primary role:** Mutates the r em ov e s ch ed ul ed wa tc he ro nl y state in one named place so the rest of the script does not duplicate update rules.

`Remove-ScheduledWatcherOnly` belongs to the **Watcher lifecycle and file system events** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on configured pairs, FileSystemWatcher events, debounce timing, exclusions, and the watcher mutex.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. No explicit function parameters; it reads from script-scoped state or acts as an internal workflow step. The output is either updated state, a small helper value, or no direct return value depending on caller context.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is event bursts or missed nested directory events. Debounce buffering and directory snapshots reduce that risk.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Remove-ScheduledWatcherOnly` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** manual or scheduled watch mode, created/changed/deleted/renamed events, and directory snapshots.
- **Dependency notes:** Notable internal calls: `Write-Color`, `Show-Header`, `Wait-Back`, `Test-IsAdministrator`, `Invoke-ElevatedMode`, `Show-PostElevatedTaskStatus`, `Remove-KnownScheduledTasks`, `Stop-KnownWatcherProcesses`.

### Stop-KnownWatcherProcesses

- **Lines:** 3441-3452
- **Area:** Watcher lifecycle and file system events
- **Primary role:** Provides the s to p k no wn wa tc he rp ro ce ss es helper behavior used by nearby workflows.

`Stop-KnownWatcherProcesses` belongs to the **Watcher lifecycle and file system events** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on configured pairs, FileSystemWatcher events, debounce timing, exclusions, and the watcher mutex.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. No explicit function parameters; it reads from script-scoped state or acts as an internal workflow step. The output is either updated state, a small helper value, or no direct return value depending on caller context.

Side effects are intentionally bounded. This is a mutating helper. Its side effects are part of the public workflow, so callers should reach it only after validation, preview, or explicit user choice has already happened. The important failure mode is event bursts or missed nested directory events. Debounce buffering and directory snapshots reduce that risk.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Stop-KnownWatcherProcesses` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** manual or scheduled watch mode, created/changed/deleted/renamed events, and directory snapshots.
- **Dependency notes:** Notable internal calls: `Write-Color`, `Get-WatcherProcesses`.

### Get-WatcherProcesses

- **Lines:** 3453-3464
- **Area:** Watcher lifecycle and file system events
- **Primary role:** Calculates or formats g et w at ch er pr oc es se s data for callers that need a stable value instead of duplicating the logic.

`Get-WatcherProcesses` belongs to the **Watcher lifecycle and file system events** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on configured pairs, FileSystemWatcher events, debounce timing, exclusions, and the watcher mutex.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. No explicit function parameters; it reads from script-scoped state or acts as an internal workflow step. The caller expects a derived object, string, number, or collection and should not need to know how it was produced.

Side effects are intentionally bounded. It may participate in long-running watcher state, but the watcher contract remains queue-only: it records work and does not apply file changes. The important failure mode is event bursts or missed nested directory events. Debounce buffering and directory snapshots reduce that risk.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Get-WatcherProcesses` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** manual or scheduled watch mode, created/changed/deleted/renamed events, and directory snapshots.
- **Dependency notes:** No notable internal function calls were detected in this function body.

### Test-AllDriveMapsOnline

- **Lines:** 3465-3483
- **Area:** Path, pair, drive map, and exclusion handling
- **Primary role:** Evaluates the t es t a ll dr iv em ap so nl in e condition and lets the caller choose a safe branch based on a clear result.

`Test-AllDriveMapsOnline` belongs to the **Path, pair, drive map, and exclusion handling** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on configured pairs, drive maps, exclusion maps, and path text supplied by the user or file system events.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. No explicit function parameters; it reads from script-scoped state or acts as an internal workflow step. The caller expects a boolean or compact status object that can be used immediately in a branch.

Side effects are intentionally bounded. It is expected to be side-effect-light and primarily returns data or decisions to the caller. The important failure mode is pointing at the wrong folder. Path helpers centralize normalization and destination resolution so previews and applies use the same interpretation.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Test-AllDriveMapsOnline` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** adding pairs, resolving destinations, drive maps, and exclusions.
- **Dependency notes:** Notable internal calls: `Get-Pairs`.

### Show-MainMenu

- **Lines:** 3484-3529
- **Area:** Menus, reports, and status screens
- **Primary role:** Renders the main interactive command hub and routes user choices into the major workflows.

`Show-MainMenu` belongs to the **Menus, reports, and status screens** layer of MiraQueue. In practical terms, this means it is part of the path from user intent to a safe, inspectable backup action rather than an isolated utility with no workflow meaning. It depends on current config, queue summaries, drive availability, and user key choices.

When the surrounding workflow reaches this function, the expected contract is straightforward: inputs are already shaped by the caller, the function performs one named responsibility, and the caller receives either a value, a state change, or a user-visible result. No explicit function parameters; it reads from script-scoped state or acts as an internal workflow step. The main output is console presentation. Any return value is secondary to navigation or display.

Side effects are intentionally bounded. Its side effect is user interaction: console output, cursor movement, or waiting for input. It should not silently perform backup changes by itself. The important failure mode is inconsistent behavior across callers, so this helper keeps one rule in one place.

The reason this function exists separately is maintainability: the behavior has a name, a line range, and a documented boundary. That makes future review easier because changes to `Show-MainMenu` can be checked against this responsibility instead of being hidden inside a larger menu or copy loop.

- **Related scenario coverage:** main menu routing, status reports, submenus, and user navigation.
- **Dependency notes:** Notable internal calls: `Get-Pairs`, `Write-Color`, `Show-Header`, `Read-KeyChoice`, `Read-QueueEntries`, `Get-LatestQueueEntries`, `Remove-OrphanedUpserts`, `Clear-PendingQueue`, `Invoke-ApplyPending`, `Show-PendingPreview`.

