# Quick Start

## Launch

Run `Start_MiraQueue.cmd` or:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\MiraQueue.ps1
```

## Add A Pair

Open **Manage Paths**, choose **Add pair**, enter a source folder, then enter a destination folder. MiraQueue detects a pair name from the paths.

## Start Watching

Use **Install / Uninstall** to install the scheduled watcher, or run `MiraQueue.ps1 -Mode Watch`. Watch mode queues changes only; it does not copy files by itself.

## Review And Apply

Use **Preview Pending** to inspect effective changes. Use **Apply Pending** when the preview looks correct. Use Full Mirror preview before any apply action.
