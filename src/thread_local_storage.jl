mutable struct ThreadLocalStorage{T}
    # TODO: pad `T`
    @atomic storages::Vector{T}
    @const cond::Threads.Condition
end

ThreadLocalStorage{T}() where {T} = ThreadLocalStorage{T}(T[], Threads.Condition())
ThreadLocalStorage() = ThreadLocalStorage{Any}()

function getstorages!(tls::ThreadLocalStorage)
    storages = @atomic :acquire tls.storages
    if length(storages) >= Threads.nthreads()
        return storages
    end
    lock(tls.cond) do
        local storages = @atomic :acquire tls.storages
        if length(storages) >= Threads.nthreads()
            return storages
        end
        resize!(storages, Threads.nthreads())
        return storages
    end
end

Base.getindex(tls::ThreadLocalStorage) = getstorages!(tls)[Threads.threadid()]
Base.setindex!(tls::ThreadLocalStorage, value) =
    getstorages!(tls)[Threads.threadid()] = value
