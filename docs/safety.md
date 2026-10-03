# Safety

MiraQueue V2 follows **preview first, explicit apply, fail safe**. A preview is a point-in-time description, not a transaction or a promise that the filesystem will stay unchanged.

## Deletion boundaries

Pending deletion requires `DeleteDestOnSourceDelete=true`. Strict Full Mirror has its own explicit deletion policy; that pending setting does not disable Strict. Both paths recheck the current source, source root, destination root and target. A restored source, permission failure or unavailable root prevents deletion. Failed pending work is retained.

Rooted queue paths, traversal, alternate data streams, ambiguous Windows path segments, overlapping source/destination trees and reparse points are rejected. A directory containing an excluded descendant is preserved as a whole rather than deleting through the exclusion. Type conflicts require review; the program does not silently delete one kind of object to replace it with another.

## Queue and concurrency

Queue mutations use a mutex derived from the absolute queue path. Reads validate every nonblank record. Replacements use a same-directory temporary file and `File.Replace`; failures do not fall back to deleting the original queue. Metadata is a rebuildable cache. Apply acknowledgments compare entry IDs so newer watcher events survive.

Apply and Full Mirror hold an exclusive file handle for their whole operation. The reusable `MiraQueue.apply.lock` file can remain after completion; its existence alone is not a held lock. Do not delete it to bypass a running operation.

## Copy and preview

Preview Pending does not rewrite the queue or metadata. It can reconcile restored paths in memory. Opening the normal application may initialize/migrate runtime storage before the menu appears. Full Mirror preview only reads trees. Applying Full Mirror preserves pending work, including events arriving during scans.

With `CopyTempThenReplace=true`, file content is copied to a sibling temporary file, then published. Missing-only file publication never overwrites a destination created after preview, even when the normal temp-copy setting is disabled. Readers deny concurrent file writers during stream copies. Directory transfers use a private staging tree, then publish or merge it; merge preserves destination extras.

## Limits and recovery

The program cannot atomically lock whole source/destination trees against unrelated processes. Keep those trees stable while applying. Size and modified time within `TimeToleranceSeconds` determine whether files differ; content hashes, version history, open-file snapshots, alternate streams, ACL replication and ransomware protection are not provided. Excluded files are intentionally outside the mirror contract.

Junctions, symbolic links and other reparse points are not followed. Watcher buffer overflow is logged; run Full Mirror preview after an overflow, interrupted watcher, missed event or source outage. Forced termination/power loss can leave an owned temporary file or staging directory; review and remove abandoned items only after all instances stop. Age alone does not prove ownership or inactivity, so V2 does not sweep arbitrary staging directories.

Uninstall uses an exact runtime-file allowlist and preserves unknown DataDir content.
