# Exclusions

Global folder/file patterns apply to every pair; per-pair maps use the stable pair name. Simple directory names match directory segments. Relative directory patterns can constrain a subtree; file patterns can match a leaf or relative path. PowerShell wildcard syntax applies, including bracket expressions: escape literal brackets in an exclusion pattern when needed.

Watcher events, directory snapshots, pending execution and Full Mirror use exclusions. Applying an old queued item rechecks the current config. Such an excluded pending item stays queued for review. Internal temporary/staging names are protected even when a migrated V1 user kept their own exclusion list; the narrow legacy temp patterns remain protected for compatibility.

Deleting a directory first checks all descendants. If any descendant is excluded, the directory deletion is retained rather than removing the excluded content indirectly. Robocopy directory transport converts per-pair relative directory/file exclusions into source-root paths.
