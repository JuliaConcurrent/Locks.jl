module LocksTests

include("utils.jl")

include("test_thread_local_storage.jl")
include("test_locks.jl")
include("test_benchmarks.jl")
include("test_doctest.jl")

end  # module LocksTests
