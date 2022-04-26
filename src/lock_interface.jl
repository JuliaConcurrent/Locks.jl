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

Locks.lock_supports_nspins(lock) = Locks.lock_supports_nspins(typeof(lock))

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
