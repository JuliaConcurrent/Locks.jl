# Naming convention

Following the [naming convention style guide of `Base`][base-naming-convention],
ConcurrentUtils.jl uses underscore `_` to separate underlying concepts.

[base-naming-convention]: https://docs.julialang.org/en/v1/manual/style-guide/#Use-naming-conventions-consistent-with-Julia-base/

* `try_` (prefix): Use Try.jl-based error handling
* `_or` (suffix): Run a callback upon some kind of "failure"
* `race`

Common verbs that appear as a primitive concept:

* `put`
* `fetch`
* `acquire`
* `release`

Using `acquire`/`release` instead of `lock`/`unlock` so that:

1. Variable `lock` can be used.
2. Make it clear that `ConcurrentUtils.try_acquire(lock) -> result::Union{Ok,Err}` and
   `Base.trylock(lock) -> locked::Bool` have different return types.
