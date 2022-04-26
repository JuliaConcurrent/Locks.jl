const Guard = GenericGuard{ReentrantLock}
const ReadWriteGuard = GenericReadWriteGuard{ReadWriteLock}

Locks.guardwith(data, lock) = GenericGuard(lock, data)
Locks.guardwith(data, lock::AbstractReadWriteLock) = GenericReadWriteGuard(lock, data)

function Locks.GenericGuard{Lock}(data) where {Lock}
    lock = Lock()
    return GenericGuard(lock, data)
end

function Locks.GenericReadWriteGuard{Lock}(data) where {Lock}
    lock = Lock()
    return GenericReadWriteGuard(lock, data)
end

function Locks.guarding(f!::F, g::GenericGuard) where {F}
    data = g.data
    criticalsection() = f!(data)
    lock(criticalsection, g.lock)
end

Locks.guarding_read(f::F, g::GenericGuard) where {F} = Locks.guarding(f, g)

function Locks.guarding(f!::F, g::GenericReadWriteGuard) where {F}
    data = g.data
    criticalsection() = f!(data)
    lock(criticalsection, g.lock)
end

function Locks.guarding_read(f::F, g::GenericReadWriteGuard) where {F}
    data = g.data
    criticalsection() = f(data)
    acquire_read_then(criticalsection, g.lock)
end

# Maybe this is a bad idea since it's hard to remember that `guarding(_, ::ReadGuard)`
# should not mutate the data just from its syntax.
#=
struct ReadGuard{Guard}
    guard::Guard
end

struct WriteGuard{Guard}
    guard::Guard
end

Locks.guarding(f::F, readguard::ReadGuard) where {F} =
    Locks.guarding_read(f, readguard.guard)

Locks.guarding(f::F, writeguard::WriteGuard) where {F} =
    Locks.guarding(f, writeguard.guard)

function Locks.read_write_guard(guard::AbstractReadWriteGuard)
    readguard = ReadGuard(guard)
    writeguard = WriteGuard(guard)
    return (readguard, writeguard)
end

Locks.read_write_guard(lock::AbstractReadWriteLock, data) =
    Locks.read_write_guard(GenericReadWriteGuard(lock, data))
=#
