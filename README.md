# ParallelOperations.jl
Fast parallel broadcast and reduction operations for Julia using binary-tree algorithms.  Note that
we can broadcast and reduce over any Julia type, but we provide convenience methods for performing
these operations on Julia arrays.

## Specific to Julia Arrays:

```julia
addprocs(7)
@everywhere using ParallelOperations

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
```

## Generic types
For generic types, we provide custom reduction and copy methods.  For example,
```julia
addprocs(7)
@everywhere using ParallelOperations

@everywhere struct B
	x::Vector{Float64}
	y::Vector{Float64}
end

x = B(ones(10),2*ones(10))
futures = bcast(x)

@everywhere function reducemethod!(b,a)
	b.x .+= a.x
	b.y .+= b.y
end

y = reduce!(futures, reducemethod!)

@everywhere function copymethod!(b,a)
	b.x .= a.x
	b.y .= a.y
end

futures_copy = TypeFutures(B, ()->B(zeros(10), zeros(10)))
copy!(futures_copy, futures, copymethod!)

```
