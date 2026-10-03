# Installation and V1 → V2 upgrade

MiraQueue V2.0.0 remains a portable Windows PowerShell application. Keep `MiraQueue.ps1` and `Start_MiraQueue.cmd` together in a writable folder. The launcher uses Windows PowerShell 5.1; PowerShell 7+ is an optional alternative. `robocopy.exe` ships with Windows and is used for directory staging.

## Upgrade an existing installation

1. Stop the **V1 watcher** through V1's lifecycle menu, and close all V1 consoles. V1 does not participate in V2's queue synchronization protocol.
2. Keep a copy of your existing `MiraQueue.config.json` and runtime folder. Do not replace them with the example config.
3. Replace the application files with V2, keeping the config beside the script. Your existing DataDir, queue filename, pairs, exclusions, drive maps and preferences are loaded.
4. Start V2. Missing settings receive defaults in memory, including `ParallelFileTransfers=4`. Saving settings writes the V2 marker atomically; merely loading an old config does not overwrite it.
5. Review Preview Pending, then reinstall/restart the scheduled watcher using V2's menu so the Unicode-aware helper is regenerated.

Valid V1 NDJSON entries retain IDs, paths, actions and effective work. Normalization adds `SchemaVersion=2`, `EventKind=Legacy`, `BaselineState=Unknown` and a derived operation. Destination observations refine classification; an event alone is not proof of destination absence. Queue migration is atomic and idempotent. Invalid JSON, invalid record shapes, unsafe paths or unsupported schemas stop processing without skipping records or emptying the queue.

Do not downgrade a migrated queue by reopening it in V1. Restore a pre-upgrade backup only with all application instances stopped, and reconcile changes made since that backup.

## Watcher lifecycle

The default task is `MiraQueue`. Its action points to this installation's generated `MiraQueue.watch.hidden.vbs`; the helper reads the UTF-16 script-directory pointer and starts `MiraQueue.ps1 -Mode Watch` hidden at logon. Task operations verify action ownership; an unrelated same-name task is never overwritten or removed.

**Remove scheduled watcher only** preserves configuration and queued work. **Uninstall everything** requires confirmation and removes exact owned runtime files. Unknown files/directories and user-created shortcuts remain. It never recursively deletes DataDir. It never deletes source or backup trees. V2 does not generate shortcuts, so it does not claim ownership of arbitrary `.lnk` files with its name.
