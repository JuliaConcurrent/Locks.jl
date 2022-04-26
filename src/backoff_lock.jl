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

abstract type BackoffLock <: Lockable end

Locks.lock_supports_nspins(::Type{<:BackoffLock}) = true

mutable struct Waiter
    task::Task
    next::Union{Waiter,Nothing}
end

mutable struct NonreentrantBackoffLock <: BackoffLock
    @atomic state::Union{IsLocked,Nothing,Waiter}
    @const _pad::NTuple{7,Int}
    mindelay::Int
    maxdelay::Int
    nspins::Int
    ntries::Int
end

NonreentrantBackoffLock(; mindelay = 1, maxdelay = 1000, nspins = 1000_000, ntries = 1000) =
    NonreentrantBackoffLock(nothing, pad7(), mindelay, maxdelay, nspins, ntries)

mutable struct ReentrantBackoffLock <: BackoffLock
    @atomic state::Union{IsLocked,Nothing,Waiter}
    @const _pad1::NTuple{7,Int}
    mindelay::Int
    maxdelay::Int
    nspins::Int
    ntries::Int
    @const _pad2::NTuple{7,Int}
    @atomic owner::Union{Nothing,Task}
    count::Int
end

ReentrantBackoffLock(; mindelay = 1, maxdelay = 1000, nspins = 1000_000, ntries = 1000) =
    ReentrantBackoffLock(
        nothing,
        pad7(),
        mindelay,
        maxdelay,
        nspins,
        ntries,
        pad7(),
        nothing,
        0,
    )

isreentrant(::ReentrantBackoffLock) = true

Base.islocked(lock::BackoffLock) = (@atomic :monotonic lock.state) !== nothing

function Base.trylock(lock::BackoffLock)
    _, ok = @atomicreplace(:acquire, lock.state, nothing => IsLocked())
    return ok
end

struct SpinLockError
    state::Union{IsLocked,Waiter}
    ns::Int
end

"""
    spinlock_or_error(lock::BackoffLock, ns, nspins) -> nothing or SpinLockError(state, ns′)
"""
@inline function spinlock_or_error(lock::BackoffLock, ns, nspins)
    while true
        state = @atomic :monotonic lock.state
        if state === nothing
            state, ok = @atomicreplace(:acquire, lock.state, nothing => IsLocked())
            if ok
                @tlc spinlock_cas_ok
                return nothing
            else
                state === nothing && unreachable()
                @tlc spinlock_cas_err
                return SpinLockError(state, ns)
            end
        end
        if !(ns < nspins)
            @tlc spinlock_toomany_spins
            return SpinLockError(state, ns)
        end
        spinloop()
        ns += 1
    end
end

function lock_or_wait(lock::BackoffLock, ex::SpinLockError)
    @tlc lock_or_wait
    state = ex.state
    waiter = Waiter(current_task(), state === IsLocked() ? nothing : state)
    while true
        state, ok = @atomicreplace(:acquire_release, :acquire, lock.state, state => waiter)
        if ok
            wait()
            state = @atomic :monotonic lock.state
        end
        while true
            state === nothing || break
            trylock(lock) && return
            state = @atomic :monotonic lock.state
        end
        state = state::Union{IsLocked,Waiter}
        waiter.next = state === IsLocked() ? nothing : state
    end
    return
end

function Base.lock(
    lock::BackoffLock;
    mindelay = lock.mindelay,
    maxdelay = lock.maxdelay,
    nspins = lock.nspins,
    ntries = lock.ntries,
)
    handle_reentrant_acquire(lock) && return
    nspins = something(nspins, -∞)
    ntries = something(ntries, -∞)

    ans = spinlock_or_error(lock, 0, nspins)
    if ans isa SpinLockError
        ex = ans

        # Allocating `Backoff` after the first try just in case it is not optimized out.
        backoff = Backoff(max(1, mindelay), max(1, maxdelay))

        local nb::Int = 0
        while true
            ns = ex.ns
            if !(ns < nspins && nb < ntries)
                lock_or_wait(lock, ex)
                break
            end

            ns += backoff()
            nb += 1
            ex = @something(spinlock_or_error(lock, ns, nspins), break)
        end
    end

    start_reentrant_acquire(lock)
    return
end

function Base.unlock(lock::BackoffLock)
    handle_reentrant_release(lock) && return
    state = @atomicswap :acquire_release lock.state = nothing
    # TODO: implement other notify policies like LIFO and FIFO?
    if state isa Waiter
        local waiter::Waiter = state
        while true
            # Load next field before `waiter.task` potentially start mutating it:
            next = waiter.next

            schedule(waiter.task)
            if next === nothing
                break
            else
                waiter = next
            end
        end
    end
    return
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
