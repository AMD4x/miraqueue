# Safety

MiraQueue is review-oriented, but it can copy and delete files when told to apply changes.

## Preview First

Use **Preview Pending** before **Apply Pending** and use Full Mirror preview before applying a full mirror policy.

## Delete Behavior

Pending delete entries can remove destination files or folders when `DeleteDestOnSourceDelete` is true. Strict Full Mirror can delete destination-only items because its purpose is to make destination match source.

## Offline Destinations

If a destination root is unavailable, Apply Pending skips the entry and keeps it visible when needed. Full Mirror reports an error for that pair.

## Temp Copy Behavior

When `CopyTempThenReplace` is true, MiraQueue copies to a temporary file in the destination folder and then replaces the target.

## Uninstall Boundary

Uninstall removes MiraQueue-created runtime data and scheduled task resources. It does not delete source folders or backup destination content.
