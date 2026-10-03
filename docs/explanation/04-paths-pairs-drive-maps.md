# Paths, pairs and drive maps

A pair has Name, Source and Dest. Source/destination must be separate absolute Windows drive or UNC paths; destination cannot overlap any configured source. DriveMaps substitutes a configured logical destination prefix and never creates a Windows drive mapping.

`Normalize-QueueRelPath` rejects traversal, rooted/device paths, alternate streams, wildcard path syntax, reserved device segments and trailing-dot/space aliases. `Join-PathSafe` then verifies strict containment. `Get-RelativePath` checks the root prefix including its separator, preventing a similarly named sibling from becoming a false child.

`Assert-NoReparsePath` inspects path ancestry. Reparse points are rejected, including junctions that could redirect a copy or delete outside the selected tree. `Get-SafeEntryPaths` recomputes current paths and checks them against saved queue paths. `Get-PhysicalDestinationKey` serializes file transfers sharing a resolved destination; uncertain resolutions use a conservative common group.
