using Locks
using Locks.Internal: AbstractReadWriteLock  # TODO: export?

# https://en.wikipedia.org/wiki/Readers%E2%80%93writer_lock#Using_two_mutexes
mutable struct RaynalReadWriteLock{ReadLock,GlobalLock} <: AbstractReadWriteLock
    readlock::ReadLock
    globallock::GlobalLock  # must be task-oblivious
    _pad::NTuple{7,Int}
    nreaders::Int
end

RaynalReadWriteLock(readlock = ReentrantLock(), globallock = TaskObliviousLock()) =
    RaynalReadWriteLock(readlock, globallock, ntuple(_ -> 0, Val(7)), 0)

function Locks.acquire_read(lock::RaynalReadWriteLock)
    acquire_then(lock.readlock) do
        n = lock.nreaders
        lock.nreaders = n + 1
        if n == 0
            acquire(lock.globallock)
        end
    end
end

function Locks.release_read(lock::RaynalReadWriteLock)
    acquire_then(lock.readlock) do
        n = lock.nreaders -= 1
        if n == 0
            release(lock.globallock)
        end
    end
end

Locks.acquire(lock::RaynalReadWriteLock) = acquire(lock.globallock)
Locks.release(lock::RaynalReadWriteLock) = release(lock.globallock)
