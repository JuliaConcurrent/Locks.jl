###
### Base.AbstractLock adapters
###

Locks.acquire(lck::Base.AbstractLock; options...) = lock(lck; options...)
Locks.release(lck::Base.AbstractLock) = unlock(lck)

Locks.acquire(x) = Base.acquire(x)
Locks.release(x) = Base.release(x)

Locks.race_acquire(lck) = trylock(lck)

function Locks.try_race_acquire(lck::Base.AbstractLock)
    if trylock(lck)
        return Ok(nothing)
    else
        return Err(NotAcquirableError())
    end
end

function Locks.acquire_then(f, lock; acquire_options...)
    acquire(lock; acquire_options...)
    try
        return f()
    finally
        release(lock)
    end
end

Locks.lock_supports_nspins(::Type{<:Base.AbstractLock}) = false

Locks.lock_supports_nspins(lock) =
    Locks.lock_supports_nspins(typeof(lock))

need_lock_object() = error("need lock type or object")
Locks.lock_supports_nspins(::Type{Union{}}) = need_lock_object()
Locks.lock_supports_nspins(::Type) = need_lock_object()

###
### Main Locks' lock interface
###

abstract type Lockable <: Base.AbstractLock end

Base.trylock(lck::Lockable) = Try.isok(try_race_acquire(lck))

function Base.lock(f, lck::Lockable; options...)
    lock(lck; options...)
    try
        return f()
    finally
        unlock(lck)
    end
end

#=
function Locks.try_race_acquire_then(f, lock::Lockable)
    @? try_race_acquire(lock)
    try
        return f()
    finally
        release(lock)
    end
end
=#

###
### Reader-writer lock interface
###

abstract type AbstractReadWriteLock <: Lockable end

function Locks.acquire_read_then(f, lock::AbstractReadWriteLock)
    acquire_read(lock)
    try
        return f()
    finally
        release_read(lock)
    end
end

struct WriteLockHandle{RWLock} <: Lockable
    rwlock::RWLock
end

struct ReadLockHandle{RWLock} <: Lockable
    rwlock::RWLock
end

Locks.try_race_acquire(lock::WriteLockHandle) = try_race_acquire(lock.rwlock)
Base.lock(lck::WriteLockHandle) = acquire(lck.rwlock)
Base.unlock(lck::WriteLockHandle) = release(lck.rwlock)

Locks.try_race_acquire(lock::ReadLockHandle) = try_race_acquire_read(lock.rwlock)
Base.lock(lck::ReadLockHandle) = acquire_read(lck.rwlock)
Base.unlock(lck::ReadLockHandle) = release_read(lck.rwlock)

Locks.read_write_lock(lock::AbstractReadWriteLock = ReadWriteLock()) =
    (ReadLockHandle(lock), WriteLockHandle(lock))
