# Scheduled task installation and ownership

Task installation remains optional. The default logon task is MiraQueue, running an interactive user's hidden watcher through wscript.exe and a generated VBS helper. Execution time is unlimited; duplicate starts are ignored. Normal backup operations do not require elevation unless filesystem permissions do.

`Test-OwnedScheduledTask` requires the exact generated launcher argument and expected executable. An unrelated same-name task cannot be overwritten or unregistered. Lifecycle reads locate only the exact task in the root task folder. Watcher process discovery checks this installation's full -File path and -Mode Watch argument, not just the script filename.

The helper and script-directory pointer use UTF-16, preserving Unicode installation paths. Elevation invokes powershell.exe directly with correctly quoted arguments; it does not build a cmd.exe command containing the installation path.

Stopping writes this DataDir's stop request and waits for the watcher to flush. Removing only the watcher preserves queue/config/logs. Full uninstall removes exact owned runtime files; unknown files and user-created shortcuts stay.
