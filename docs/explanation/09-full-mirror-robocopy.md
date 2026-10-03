# Full Mirror scanning and directory transport

Full Mirror compares complete configured pairs with STRICT, UPDATE_KEEP_EXTRAS or MISSING_ONLY. `Invoke-FullMirrorScan` uses bounded runspaces controlled by the retained RobocopyParallelBatches config key. Each worker dot-sources the script without starting the application, then calls `Get-InternalMirrorScan`.

Internal scans index source/destination trees and use terminating enumeration errors. They do not parse localized robocopy messages. Permission failures, unavailable roots, reparse points and type conflicts abort a pair's scan instead of returning a misleading partial plan. Exclusions apply to both sides.

Apply operates on previewed paths. Creating a directory does not copy an unpreviewed subtree. Strict deletes recheck the source; update keeps extras; missing-only refuses to overwrite destinations appearing after preview. All policies preserve pending watcher work. The user may subsequently run Apply Pending to reconcile/acknowledge it.

Robocopy remains in `Invoke-NewDirectoryTreeCopy` as bulk transport into a private staging directory. Exit codes 8+ fail that job. Windows argument quoting preserves spaces, special characters and trailing backslashes. This transport never uses /MIR or /PURGE.
