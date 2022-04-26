# Locks.jl

## Promise

```@eval
using DocumentationOverview
using Locks
DocumentationOverview.table_md(
    :[
        Promise,
        try_race_fetch,
        try_race_fetch_or!,
        race_fetch_or!,
        try_race_put!,
    ],
    namespace = Locks,
    signature = :name,
)
```

```@docs
Promise
try_race_fetch
try_race_fetch_or!
race_fetch_or!
try_race_put!
```

## Promise-like interfaces

```@eval
using DocumentationOverview
using Locks
DocumentationOverview.table_md(
    :[
        var"@tasklet",
        var"@once",
    ],
    namespace = Locks,
    signature = :name,
)
```

```@docs
@tasklet
@once
```

## Locks

```@eval
using DocumentationOverview
using Locks
DocumentationOverview.table_md(
    :[
        ReentrantCLHLock,
        NonreentrantCLHLock,
        ReentrantBackoffSpinLock,
        NonreentrantBackoffSpinLock,
        TaskObliviousLock,
        read_write_lock,
        acquire,
        release,
        try_race_acquire,
        race_acquire,
        acquire_then,
    ],
    namespace = Locks,
    signature = :name,
)
```

```@docs
ReentrantCLHLock
NonreentrantCLHLock
ReentrantBackoffSpinLock
NonreentrantBackoffSpinLock
TaskObliviousLock
read_write_lock
acquire
release
try_race_acquire
race_acquire
acquire_then
```

## Guards

```@eval
using DocumentationOverview
using Locks
DocumentationOverview.table_md(
    :[
        Guard,
        ReadWriteGuard,
        guarding,
        guarding_read,
    ],
    namespace = Locks,
    signature = :name,
)
```

```@docs
Guard
ReadWriteGuard
guarding
guarding_read
```

## Low-level interfaces

```@eval
using DocumentationOverview
using Locks
DocumentationOverview.table_md(
    :[
        ThreadLocalStorage,
        spinloop,
    ],
    namespace = Locks,
    signature = :name,
)
```

```@docs
ThreadLocalStorage
spinloop
```
