# Complete Scenario Matrix

| Scenario | Trigger | MiraQueue Action | Result |
| --- | --- | --- | --- |
| First launch | No config exists | Create config and runtime queue | Main menu opens |
| Invalid config | Malformed JSON | Show error and exit | No silent repair |
| No pairs | Watch or Full Mirror selected | Show warning | No work starts |
| Add pair | Source and destination entered | Normalize and save | Pair has exclusion keys |
| Edit pair | Pair changed | Update pair and maps | Exclusions stay attached |
| Remove pair | Pair selected | Remove config entry | Files untouched |
| Global exclusion | Pattern added | Skip matching paths | All pairs affected |
| Pair exclusion | Pattern added to one pair | Skip for that pair | Other pairs unchanged |
| Created file | Watcher Created | Queue Upsert | Apply copies if needed |
| Changed file | Watcher Changed | Queue Upsert | Apply copies if different |
| Deleted file | Watcher Deleted | Queue Delete | Apply deletes when enabled |
| Renamed file | Watcher Renamed | Queue old delete and new upsert | Rename reflected after apply |
| Created directory | New folder appears | Queue folder and snapshot children | Nested items included |
| Excluded event | Path matches exclusion | Drop event | Queue stays clean |
| Burst events | Many quick changes | Debounce writes | Queue receives consolidated entries |
| Clear queue | User confirms clear | Queue and buffer cleared | Pending work discarded |
| Destination offline | Root unavailable | Skip or report error | User can reconnect |
| Source missing | Queued source vanished | Fail copy entry | User can review |
| Already current | Destination matches | Skip copy | No needless write |
| Directory exists | MKDIR target exists | Skip mkdir | No error |
| Delete disabled | Delete setting false | Skip delete | Destination preserved |
| Strict preview | STRICT with preview | List comparison | No delete happens |
| Strict apply | STRICT with apply | Mirror source to destination | Extras can be removed |
| Update apply | UPDATE_KEEP_EXTRAS | Copy new and updated items | Extras remain |
| Missing-only apply | MISSING_ONLY | Copy missing items only | Updates ignored |
| Robocopy failure | Failure code | Report error | Failure count visible |
| Install watcher | Install selected | Elevate and register task | Watcher starts at logon |
| Restart watcher | Restart selected | Stop and start task | Config reloads |
| Remove watcher | Remove selected | Unregister task | Config and queue remain |
| Full uninstall | Confirmed uninstall | Remove generated runtime resources | User data preserved |
| Status | Status selected | Show health data | User can diagnose |
| Log rotation | Log grows large | Move old log | Runtime stays bounded |
| Temp cleanup | Old internal temp file | Remove eligible file only | Unrelated files preserved |
