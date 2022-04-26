module Utils

using Locks

function poll_until(f)
    for _ in 1:1000
        f() && return true
        sleep(0.01)
    end
    return false
end

end  # module
