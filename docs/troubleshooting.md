# Troubleshooting

## Execution Policy

Use the launcher or run PowerShell with `-ExecutionPolicy Bypass` for this script invocation.

## Admin Prompt

Scheduled task installation and removal require elevation. Normal menu use, preview, status, and apply actions do not need elevation unless your folders require it.

## Watcher Not Running

Open **Status** and check scheduled task state and watcher process count. Restart the scheduled watcher after changing paths or settings.

## Destination Offline

Reconnect the drive or update drive maps before applying changes.

## Locked Or Unauthorized Files

Locked files may fail copy or robocopy operations. MiraQueue summarizes errors and keeps failed pending entries when needed.

## Invalid Config

Compare `MiraQueue.config.json` with `examples/MiraQueue.config.example.json` and fix malformed JSON.

## Queue Looks Too Large

Use Preview Pending. MiraQueue collapses repeated events into effective entries. Clear Pending Queue only when you intentionally want to discard queued changes.
