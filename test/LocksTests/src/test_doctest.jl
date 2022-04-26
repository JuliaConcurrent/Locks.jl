module TestDoctest

using Locks
using Documenter

test() = doctest(Locks; manual = false)

end  # module
