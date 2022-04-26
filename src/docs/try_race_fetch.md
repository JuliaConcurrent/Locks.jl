    try_race_fetch(promiselike) -> Ok(value::T) or Err(NotSetError())

Try to retrieve a `value` if it is already set.  Return `Ok(value)` on success and
`Err(NotSetError())` on failure.

`try_race_fetch` can be called on a [`Promise`](@ref) or a tasklet ([`@tasklet`](@ref)).

# Extended help

## Examples
```julia
julia> using Locks

julia> p = Promise{Int}();

julia> try_race_fetch(p)
Try.Err: NotSetError()

julia> put!(p, 123);

julia> try_race_fetch(p)
Try.Ok: 123
```
