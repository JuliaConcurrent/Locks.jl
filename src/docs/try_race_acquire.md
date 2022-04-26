    try_race_acquire(lock) -> Ok(nothing) or Err(reason)

Try to acquire `lock` and return `Ok(nothing)` on success.  Return an `Err` wrapping a value
explaining a `reason` of failure.

See the documentation of `typeof(lock)` for possible error types.

## Examples
```julia
julia> using Locks

julia> lock = NonreentrantCLHLock();

julia> try_race_acquire(lock)
Try.Ok: nothing

julia> try_race_acquire(lock)
Try.Err: TooManyTries(0, 0)
```
