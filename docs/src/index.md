# Locks.jl

```@eval
using DocumentationOverview
using Locks
DocumentationOverview.table_md(
    Locks,
    signature = :name,
    include = api -> api.hasdoc && !(api.value isa Module),
)
```

```@docs
ReentrantCLHLock
NonreentrantCLHLock
ReentrantBackoffSpinLock
NonreentrantBackoffSpinLock
TaskObliviousLock
acquire
release
try_race_acquire
race_acquire
acquire_then
```
