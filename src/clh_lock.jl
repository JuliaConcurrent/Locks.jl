struct IsLocked end

mutable struct LockQueueNode
    @atomic state::Union{IsLocked,Task,Nothing}
end

@inline _islocked(node::LockQueueNode) = (@atomic :monotonic node.state) isa IsLocked

# TODO: Compare it with MCSLock
abstract type CLHLock <: Lockable end

mutable struct NonreentrantCLHLock <: CLHLock
    # TODO: padding
    # TODO: node caching
    @atomic tail::LockQueueNode
    current::LockQueueNode
end

const DUMMY_NODE = LockQueueNode(nothing)

NonreentrantCLHLock() = NonreentrantCLHLock(LockQueueNode(nothing), DUMMY_NODE)

mutable struct ReentrantCLHLock <: CLHLock
    # TODO: padding
    # TODO: node caching
    @atomic tail::LockQueueNode
    current::LockQueueNode
    @atomic owner::Union{Nothing,Task}
    count::Int
end

ReentrantCLHLock() = ReentrantCLHLock(LockQueueNode(nothing), DUMMY_NODE, nothing, 0)

function ConcurrentUtils.acquire(lock::CLHLock; nspins::Integer = 0)
    if lock isa ReentrantCLHLock
        if (@atomic :monotonic lock.owner) === current_task()
            lock.count += 1
            return
        end
    end

    node = LockQueueNode(IsLocked())
    pred = @atomicswap :acquire_release lock.tail = node
    if !_islocked(pred)
        atomic_fence(:acquire)
        @goto locked
    end
    for _ in 1:nspins
        if !_islocked(pred)
            atomic_fence(:acquire)
            @goto locked
        end
    end

    task = current_task()
    state, ok = @atomicreplace pred.state IsLocked() => task
    if ok
        @assert state isa IsLocked
        wait()
        @assert pred.state === task
        # @atomic :monotonic pred.state = nothing  # if reusing
    else
        @assert state === nothing
    end

    @label locked
    if lock isa ReentrantCLHLock
        @atomic :monotonic lock.owner = current_task()
        lock.count = 1
    end
    lock.current = node
    return
end

function ConcurrentUtils.release(lock::CLHLock)
    if lock isa ReentrantCLHLock
        @assert (@atomic :monotonic lock.owner) === current_task()
        if (lock.count -= 1) > 0
            return
        end
        @atomic :monotonic lock.owner = nothing
    end
    node = lock.current
    state, ok = @atomicreplace(
        :acquire_release,
        :acquire,
        node.state,
        IsLocked() => nothing,  # try to unlock the node
    )
    if !ok
        # The waiter is already sleeping. Wake it up.
        task = state::Task
        schedule(task)
    end
    return
end
