# Design and performance decisions

V2 keeps a portable PowerShell implementation and Windows PowerShell 5.1 compatibility. Runspace pools provide bounded concurrency without requiring PowerShell 7's parallel pipeline syntax. Bulk new-directory transport remains robocopy; the language-dependent full-scan parser was removed after audit because partial/error output could authorize an unsafe plan.

Queue reduction uses a per-pair path index to visit relevant descendants. Pending snapshots reuse unchanged observations in the same process and invalidate them when roots/context/entry identities change. Sparse groups use exact probes. Dense groups (at least eight requested paths) use bounded, nonrecursive name enumeration with exact fallback for missing names; partial enumeration never proves absence.

Destination discovery occurs outside the queue mutex; the final classification commit compares IDs and captures entries/fingerprint under the lock. A changed event marks the returned snapshot stale for refresh rather than overwriting newer data. Read-only previews omit the commit entirely.

`-TracePendingPerformance` records counters and timings for diagnosis. Transfer speed depends on storage, network conditions and cache state; the counters help identify where time is spent.

Safety changes intentionally trade some shortcuts for checks: no recursive uninstall, no age-only lock stealing, no whole-queue clear after Full Mirror, no following reparse points and no silent partial scans.
