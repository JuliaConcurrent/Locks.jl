    ReentrantCLHLock

A reentrant CLH "spinnable" lock that provides first-come-first-served fairness.  Keyword
argument `nspins::Integer` can be passed to [`acquire`](@ref) to specify a number of spins
tried before falling back to "cooperative" waiting in the Julia scheduler.

# Extended help

`ReentrantCLHLock` implements the spin lock by Craig (1993) and Magnussen, Landin, and
Hagersten (1994) with a fallback to "cooperatively" wait in the scheduler instead of
spinning (hence "spinnable").  See [`NonreentrantCLHLock`](@ref) that provides a
non-reentrant version.

## Memory ordering

A `release` invocation on a `lock` establishes happened-before edges to subsequent
invocations of `acquire` and `try_race_acquire` that returns an `Ok` on the same `lock`.

## Supported operations

* [`acquire(lock::ReentrantCLHLock; [nspins::Integer])`](@ref acquire) (`lock`)
* [`try_race_acquire(lock::ReentrantCLHLock)`](@ref try_race_acquire) (`trylock`): Not very efficient
  but lock-free.  Fail with `AcquiredByWriterError`.
* [`release(lock::ReentrantCLHLock)`](@ref) (`unlock`)
