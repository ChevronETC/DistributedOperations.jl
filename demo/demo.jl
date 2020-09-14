using Distributed
addprocs(7)
@everywhere using DistributedOperations

x = ones(10)

# broadcast x to all pids
futures = bcast(x)

# broadcast x to specific pids (must include myid())
futures = bcast(x, procs())

# manipulate x on one of the workers
@everywhere myop!(future) = begin fetch(future) .= 2.0; nothing end
remotecall_fetch(myop!, workers()[1], futures[workers()[1]])

# parallel reduction
y = reduce!(futures)
@show y

# construct arrays of the same size on each process
futures = ArrayFutures(Float64, (10,))

# fill with values
@everywhere myfill!(future) = begin fetch(future) .= π; nothing end
@sync for pid in procs()
    @async remotecall_fetch(myfill!, pid, futures[pid])
end

# parallel reduction
y = reduce!(futures)

rmprocs(workers())
