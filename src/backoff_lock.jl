mutable struct Backoff
    limit::Int
    @const maxdelay::Int
end

# Avoid introducing a function boundaries and move `backoff` to stack (or registers).
@inline function (backoff::Backoff)()
    limit = backoff.limit
    backoff.limit = min(backoff.maxdelay, 2limit)
    delay = rand(THREAD_LOCAL_RNG[], 1:limit)
    spinfor(delay)
    return delay
end

abstract type BackoffSpinLock <: Lockable end

@enum BackoffSpinLockState LCK_AVAILABLE LCK_HELD

mutable struct NonreentrantBackoffSpinLock <: BackoffSpinLock
    @atomic state::BackoffSpinLockState
    @const _pad::NTuple{7,Int}
    mindelay::Int
    maxdelay::Int
end

NonreentrantBackoffSpinLock(; mindelay = 1, maxdelay = 1000) =
    NonreentrantBackoffSpinLock(LCK_AVAILABLE, pad7(), mindelay, maxdelay)

mutable struct ReentrantBackoffSpinLock <: BackoffSpinLock
    @atomic state::BackoffSpinLockState
    @const _pad1::NTuple{7,Int}
    mindelay::Int
    maxdelay::Int
    @const _pad2::NTuple{7,Int}
    @atomic owner::Union{Nothing,Task}
    count::Int
end

ReentrantBackoffSpinLock(; mindelay = 1, maxdelay = 1000) =
    ReentrantBackoffSpinLock(LCK_AVAILABLE, pad7(), mindelay, maxdelay, pad7(), nothing, 0)

isreentrant(::ReentrantBackoffSpinLock) = true

Base.islocked(lock::BackoffSpinLock) = (@atomic :monotonic lock.state) !== LCK_AVAILABLE

function Locks.try_race_acquire(
    lock::BackoffSpinLock;
    mindelay = lock.mindelay,
    maxdelay = lock.maxdelay,
    nspins = -∞,
    ntries = -∞,
)
    handle_reentrant_acquire(lock) && return Ok(nothing)

    if !islocked(lock) && (@atomicswap :acquire lock.state = LCK_HELD) === LCK_AVAILABLE
        @goto locked
    end

    local nt::Int = 0
    while true
        # Check this first so that no loop is executed if `nspins == -∞`
        nt < nspins || return Err(TooManyTries(nt, 0))
        islocked(lock) || break
        spinloop()
        nt += 1
    end

    local nb::Int = 0
    backoff = Backoff(max(1, mindelay), max(1, maxdelay))
    while true
        if (@atomicswap :acquire lock.state = LCK_HELD) === LCK_AVAILABLE
            @goto locked
        end
        nb < ntries || return Err(TooManyTries(nt, nb))
        nt += backoff()
        nb += 1
        while islocked(lock)
            nt < nspins || return Err(TooManyTries(nt, nb))
            spinloop()
            nt += 1
        end
    end

    @label locked
    start_reentrant_acquire(lock)
    return Ok(nothing)
end

function Base.lock(
    lock::BackoffSpinLock;
    mindelay = lock.mindelay,
    maxdelay = lock.maxdelay,
)
    try_race_acquire(lock; mindelay, maxdelay, nspins = ∞, ntries = ∞)::Ok
    return
end

function Base.unlock(lock::BackoffSpinLock)
    handle_reentrant_release(lock) && return
    @atomic :release lock.state = LCK_AVAILABLE
    return
end
