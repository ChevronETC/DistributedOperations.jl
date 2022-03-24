# Examples

## Broadcast, and reduce arrays example

```julia
addprocs(7)
@everywhere using DistributedOperations

x = ones(10)

# broadcast x to all pids
_x = bcast(x) # equivalent to bcast(x, procs())

# manipulate x on one of the workers
@everywhere myop!(future) = begin fetch(future)::Vector{Float64} .= 2.0; nothing end
remotecall_fetch(myop!, workers()[1], _x[workers()[1]])

# parallel reduction
y = reduce!(futures)
@show y

rmprocs(workers())
```

## Reduce arrays example

```julia
addprocs(7)
@everywhere using DistributedOperations

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

## Broadcast and reduce applied to a composite struct
For generic types, we provide custom reduction and copy methods.  For example,
```julia
addprocs(7)
@everywhere using DistributedOperations

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
```

Continuing from the previous example, we illustrate how to
make a copy of a `TypeFuture` when using a composite
structure.
```julia
@everywhere function copymethod!(b,a)
    b.x .= a.x
    b.y .= a.y
end

futures_copy = TypeFutures(B, ()->B(zeros(10), zeros(10)))
copy!(futures_copy, futures, copymethod!)
```

## In-place broadcast
It is sometimes useful to broadcast an existing `TypeFutures` to new Julia processes.  For example with an
`ArrayFutures` we have,
```julia
using Distributed, DistributedOperations
y = rand(2)
x = ArrayFutures(y)
addprocs(2)
@everywhere using Distributed, DistributedOperations
bcast!(x, workers())
rmprocs(workers())
```
Second, we have an example for `TypeFutures`,
```julia
using Distributed, DistributedOperations
y = (x=rand(2),y=rand(2))
x = TypeFutures(y)
addprocs(2)
@everywhere using Distributed, DistributedOperations
bcast!(x, workers())
rmprocs(workers())
```