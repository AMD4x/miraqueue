# Installation

MiraQueue V1.0.0 is portable.

## Launcher

Double-click `Start_MiraQueue.cmd`. The launcher starts `MiraQueue.ps1` from the same folder.

## PowerShell

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\MiraQueue.ps1
```

## Scheduled Watcher

Open **Install / Uninstall**, then choose **Install required scheduled watcher**. MiraQueue requests elevation only for task creation. The scheduled task starts the hidden watcher helper at logon.

## Remove Or Uninstall

Remove scheduled watcher only to preserve config, queue, logs, sources, and destinations. Full uninstall removes generated runtime resources and config, but not source or destination content.
