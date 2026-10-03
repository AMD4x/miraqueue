# Quick start — V2.0.0

Run `Start_MiraQueue.cmd` from a writable application folder. It locates the script beside itself, invokes Windows PowerShell 5.1 and preserves its exit code. For PowerShell 7, run `pwsh.exe -NoProfile -File .\MiraQueue.ps1`.

## Configure and seed a backup

Use **[4] Manage Paths → [1] Add pair**. Enter absolute Windows paths, such as `C:\Demo\Documents` and `D:\DemoBackup\Documents`. The name is detected from the source; duplicates receive a numeric suffix. Keep source and destination separate. Drive maps are optional string substitutions within MiraQueue; they do not create Windows mappings.

Use **[5] Manage Exclusions** before your first backup. For existing source files, choose **[3] Full Mirror → [3] Safe Missing Only → [1] Show preview first, then apply**. Watching starts from filesystem events, not an automatic initial full copy.

## Watch, preview, apply

Start a foreground watcher in a separate console:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\MiraQueue.ps1 -Mode Watch
```

For logon startup, use **[8] Install / Uninstall → [1] Install required scheduled watcher**. The program requests elevation for task operations. It never automatically applies backups.

**[2] Preview Pending** shows Add / Update / Delete labels and groups suitable directory work into TREE rows. N/P changes page, Esc returns, and Enter explicitly applies. **[1] Apply Pending** is also an explicit apply command. In scripts, `-Mode ApplyPending -NoPause` applies immediately; use `-Mode PreviewPending -NoPause` first to inspect without applying.

Reconnect offline destinations and retry. Failed or uncertain work remains queued. After Full Mirror, use Apply Pending to reconcile/acknowledge matching work; Full Mirror does not clear the watcher queue.
