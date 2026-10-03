# Configuration migration

`New-DefaultConfig` is the canonical public settings shape. Defaults contain no backup pairs or drive mappings. `Ensure-ConfigShape` fills absent properties without resetting existing pairs, exclusions or unknown user properties. ParallelFileTransfers is constrained to 1–32, with invalid values falling back to 4. Pair names are unique case-insensitive identifiers; editing roots does not silently rename them.

QueueFile and LogFile must be distinct simple filenames. DataDir cannot be a filesystem root or lie inside a configured source/destination tree. Unsafe existing layouts are rejected for review, not silently relocated. Old records continue to point to their original roots; an apply detects a changed pair rather than redirecting a destructive action.

`Save-Config` validates, writes a sibling temporary JSON file, replaces the destination atomically, invalidates the in-process snapshot and requests a watcher refresh. See [all settings](../configuration.md).
