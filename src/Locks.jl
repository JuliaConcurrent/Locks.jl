baremodule Locks

export
    # Constructors
    NonreentrantBackoffLock,
    NonreentrantBackoffSpinLock,
    NonreentrantCLHLock,
    NotAcquirableError,
    ReentrantBackoffLock,
    ReentrantBackoffSpinLock,
    ReentrantCLHLock,
    TaskObliviousLock,
    TooManyTries

export Try, Err, Ok
using Try: Try, Ok, Err

module InternalPrelude
include("prelude.jl")
end  # module InternalPrelude

struct NotAcquirableError <: InternalPrelude.Exception end
struct TooManyTries <: InternalPrelude.Exception
    nspins::Int
    ntries::Int
end

InternalPrelude.@exported_function acquire
InternalPrelude.@exported_function release
InternalPrelude.@exported_function race_acquire
InternalPrelude.@exported_function try_race_acquire
# function try_race_acquire_then end
InternalPrelude.@exported_function acquire_then
InternalPrelude.@exported_function lock_supports_nspins

#=
InternalPrelude.@exported_function isacquirable
=#

"""
    Internal

Internal module that contains main implementations.
"""
module Internal

using Core.Intrinsics: atomic_fence
using Random: Xoshiro

using ExternalDocstrings: @define_docstrings
using Try: Try, Ok, Err, @?

using ..Locks:
    Locks,
    NotAcquirableError,
    TooManyTries,
    acquire,
    race_acquire,
    release,
    try_race_acquire

if isfile(joinpath(@__DIR__, "config.jl"))
    include("config.jl")
else
    include("default-config.jl")
end

include("utils.jl")
include("thread_local_storage.jl")

# Locks
include("lock_interface.jl")
include("backoff_lock.jl")
include("clh_lock.jl")

end  # module Internal

const ReentrantBackoffLock = Internal.ReentrantBackoffLock
const NonreentrantBackoffLock = Internal.NonreentrantBackoffLock
const ReentrantBackoffSpinLock = Internal.ReentrantBackoffSpinLock
const NonreentrantBackoffSpinLock = Internal.NonreentrantBackoffSpinLock
const ReentrantCLHLock = Internal.ReentrantCLHLock
const NonreentrantCLHLock = Internal.NonreentrantCLHLock
const TaskObliviousLock = NonreentrantCLHLock

Internal.@define_docstrings

end  # baremodule Locks
