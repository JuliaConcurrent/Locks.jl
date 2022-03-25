mutable struct ThreadLocalStorage{T,Factory}
    # TODO: pad `T`
    @const factory::Factory
    @atomic storages::Vector{T}
    @const cond::Threads.Condition
end

ThreadLocalStorage{T}(factory = T) where {T} =
    ThreadLocalStorage{T,_typeof(factory)}(factory, T[], Threads.Condition())

function ThreadLocalStorage(factory)
    value = factory()
    return ThreadLocalStorage{typeof(value),_typeof(factory)}(
        factory,
        [value],
        Threads.Condition(),
    )
end

#=
function unsafe_empty!(tls::ThreadLocalStorage)
    empty!(tls.storages)
    return tls
end
=#

function getstorages!(tls::ThreadLocalStorage)
    storages = @atomic :acquire tls.storages
    if length(storages) >= Threads.nthreads()
        return storages
    end
    lock(tls.cond) do
        local storages = @atomic :acquire tls.storages
        n = length(storages)
        if n >= Threads.nthreads()
            return storages
        end
        resize!(storages, Threads.nthreads())
        local factory = tls.factory
        if factory !== nothing
            for i in n+1:Threads.nthreads()
                storages[i] = factory()
            end
        end
        return storages
    end
end

Base.getindex(tls::ThreadLocalStorage) = getstorages!(tls)[Threads.threadid()]
