# Errors and safety invariants

A missing-path exception is distinct from Access Denied or a network error. `Get-ExactPathProbe` returns Exists, Missing or Error. Negative destination observations require a root confirmation; a missing source root never authorizes deleting a backup.

Queue parsing and lock failures throw rather than returning an empty successful snapshot. Failed temporary writes leave the old queue. A metadata write failure does not undo an already committed queue; metadata can be rebuilt. Apply acknowledgments compare IDs under the same mutex used by the watcher.

Destructive operations validate containment and current filesystem state. Snapshot observations improve display/performance only. Full Mirror never clears the queue based on an older scan. Pending deletion disabled by configuration is retained. Parent deletion cannot bypass an excluded descendant.

Preview and apply do not provide a filesystem-wide transaction against unrelated writers.
