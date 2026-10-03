# Overview

MiraQueue V2.0.0 keeps detection, inspection and application separate. `Start-Watcher` records source events; it never copies or deletes destination content. `Sync-PendingSessionSnapshot -ReadOnly` prepares the menu/preview without changing storage. `Invoke-ApplyPending` holds an apply lock, refreshes/reconciles current work, executes it and acknowledges only matching successful IDs.

Full Mirror is a separate comparison across complete pairs. `Invoke-FullMirrorScan` runs bounded internal scan workers. This avoids dependence on localized robocopy output. Applying the selected policy processes previewed paths with current checks and preserves the watcher queue. Robocopy remains the bulk transport for new directory staging.

The runtime is still one PowerShell script with a CMD launcher. Dot-sourcing the script defines functions/state but does not initialize configuration, create runtime files, start watchers or touch scheduled tasks. Scan workers use this boundary to load the functions without starting the application.
