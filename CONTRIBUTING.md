# Contributing

Run these before opening a pull request:

```powershell
./tests/Test-MiraQueueStatic.ps1
./tests/Test-VersionConsistency.ps1
./tests/Test-DocsLinks.ps1
./tools/Test-DocumentationCoverage.ps1
```

Any function added to `MiraQueue.ps1` must also be documented in `docs/explanation/15-function-reference.md`. Any new user-facing behavior must be added to the scenario matrix and relevant map.
