# Apply Pending

`Invoke-ApplyPending` acquires the exclusive apply handle, then prepares a fresh snapshot even when called from an older preview. Destination checks classify adds/updates; restored deletes become upserts, and restored directories expand into child work. Errors are indeterminate and retain work.

The execution plan orders deletes, staged directory jobs and files. Staged jobs publish a new tree or merge safely into an existing directory while retaining extras. Individual files use a bounded runspace pool; physically conflicting destinations serialize. File readers deny concurrent writers, and default copies publish through a temporary sibling.

Deletion rechecks source absence and source/destination roots immediately before removing the target. Exclusions, containment and reparse-point boundaries are revalidated. Delete-disabled entries remain pending. Successful/obsolete entries are acknowledged only when the current queue ID still matches the attempted event. Any newer same-path event remains.

Progress and result tables distinguish failures, skipped/current content, canceled deletes and grouped tree copies. Apply lock, runspaces, streams and private staging are released in finally blocks on handled failures.
