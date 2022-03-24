module DistributedOperations

using Distributed

struct TypeFutures{T} f::Dict{Int,Future} end
Base.getindex(a::TypeFutures, i::Int) = getindex(a.f, i)
Base.setindex!(a::TypeFutures, f::Future, i::Int) = setindex!(a.f, f, i)
Base.keys(a::TypeFutures) = keys(a.f)

"""
    x = TypeFutures(T, f, pids, fargs...)

Construt a `x::TypeFutures` of type `T` on workers defined by the process id's `pids`.  On each
worker `pid`, `f` is evaluated, and a future for what is returned by `f` is stored.

# Example
```
using Distributed
addprocs(2)
@everywhere using DistributedOperations
@everywhere struct MyStruct
    x::Vector{Float64}
    y::Vector{Float64}
end
@everywhere foo() = MyStruct(rand(10), rand(10))
x = TypeFutures(MyStruct, foo, procs())
@show remotecall_fetch(localpart, workers()[1], x)
rmprocs(workers())
```
"""
function TypeFutures(_T::Type{T}, f::Function, pids::AbstractArray, fargs::Vararg) where {T}
    pids[1] == myid() || error("expected myid()==pids[1], got pids[1]=$(pids[1]) where-as myid()=$(myid())")

    futures = Dict()
    @sync for pid in pids
        futures[pid] = remotecall(f, pid, fargs...)
        @async remotecall_fetch(wait, pid, futures[pid])
    end
    TypeFutures{T}(futures)
end
TypeFutures(_T::Type{T}, f::Function, fargs::Vararg) where {T} = TypeFutures(_T, f, procs(), fargs...)

"""
    x = TypeFutures(y::T, f[, pids=procs()], fargs...)

Construt a `x::TypeFutures` from `y::T` on workers defined by the process id's `pids`.  On
each worker `pid`, `f` is evaluated, and a future for what is returned by `f` is stored.

# Example
```
using Distributed
addprocs(2)
@everywhere using DistributedOperations
@everywhere struct MyStruct
    x::Vector{Float64}
    y::Vector{Float64}
end
@everywhere foo() = MyStruct(rand(10), rand(10))
x = foo()
x = TypeFutures(x, foo, procs())
@show remotecall_fetch(localpart, workers()[1], x)
rmprocs(workers())
```
"""
function TypeFutures(x::T, f::Function, pids::AbstractArray, fargs::Vararg) where {T}
    futures = Dict()
    @sync for pid in pids
        if pid == myid()
            futures[pid] = Future()
            put!(futures[pid], x)
        else
            futures[pid] = remotecall(f, pid, fargs...)
            @async remotecall_fetch(wait, pid, futures[pid])
        end
    end
    TypeFutures{T}(futures)
end
TypeFutures(x::T, f::Function, fargs::Vararg) where {T} = TypeFutures(x, f, procs(), fargs...)

"""
    x = TypeFutures(y::T, pids)

Construct a `x::TypeFutures` from `y::T` on the master process.  This is useful
for creating `x` prior to the construction of a cluster.  Subsequently, `x` can
be used to broadcast `y` to workers.

# Example
```
using Distributed, DistributedOperations
y = (x=rand(2),y=rand(2))
x = TypeFutures(y)
addprocs(2)
@everywhere using DistributedOperations
bcast!(x, workers())
```
"""
TypeFutures(x::T) where {T} = TypeFutures(x, ()->nothing, [1])

ArrayFutures{T,N} = TypeFutures{Array{T,N}}

"""
    x = ArrayFutures(T, n::NTuple{N,Int}[, pids=procs()])

Create `x::TypeFutures`, and where each proccess id (pid) in `pids` is
assigned `zeros(T,n)`.

# Example
```
using Distributed
addprocs(2)
@everywhere using DistributedOperations
x = ArrayFutures(Float32, (10,20), procs())
localpart(x)
rmprocs(workers())
```
"""
ArrayFutures(_T::Type{T}, n::NTuple{N,I}, pids=procs()) where {T,N,I<:Integer} = TypeFutures(Array{T,N}, zeros, pids, T, n)

"""
    x = ArrayFutures(x::Array[, pids=procs()])

Create `x::TypeFutures`, and where `myid()` is assigned `x`, and all other processes
are assigned `zeros(eltype(x), size(x))`.
"""
ArrayFutures(x::Array{T,N}, pids=procs()) where {T,N} = TypeFutures(x, zeros, pids, T, size(x))

"""
    bcast!(x::TypeFutures, pids)

Broadcast an existing `x::TypeFutures` to `pids`.  This is useful for
elastic computing where the cluster may grow after the construction
and broadcast of `x::TypeFuture`.
"""
function bcast!(x::TypeFutures{T}, pids) where {T}
    _pids = 1 ∈ pids ? pids : [1;pids]
    _x = bcast(localpart(x)::T, _pids)
    merge!(x.f, _x.f)
    x
end

"""
    bcast(x[, pids=procs()])

Broadcast `x` to `pids`.

# Example
```
using Distributed
addprocs(2)
@everywhere using DistributedOperations
x = rand(10)
_x = bcast(x)
y = remotecall_fetch(localpart, workers()[1], _x)
y ≈ x  # true
rmprocs(workers())
```
"""
function bcast(x::T, pids=procs()) where {T}
    pids[1] == myid() || error("expected myid()==pids[1], got pids[1]=$(pids[1]) where-as myid()=$(myid())")

    M = length(pids)
    L = round(Int,log2(prevpow(2,M)))

    _f(x) = x
    futures = Dict(pids[1]=>remotecall(_f, myid(), x))

    for l = 1:L
        m = 2^(l-1)
        @sync for i = 1:m
            futures[pids[i+m]] = remotecall(fetch, pids[i+m], futures[pids[i]])
            @async remotecall_fetch(wait, pids[i+m], futures[pids[i+m]])
        end
    end

    m = 2^L
    R = M - m

    if R != 0
        @sync for i = 1:R
            futures[pids[i+m]] = remotecall(fetch, pids[i+m], futures[pids[i]])
            @async remotecall_fetch(wait, pids[i+m], futures[pids[i+m]])
        end
    end

    TypeFutures{T}(futures)
end

@inline paralleloperations_reduce!(y, x) = begin y .+= x; nothing end

"""
    y = reduce!(x::TypeFutures[, reducemethod!=DistributedOperations.paralleloperations_reduce!])

Parallel reduction of `x::TypeFutures` using `reducemethod!`.  By default, the reduction
is a mutating in-place element-wise addition, such that `y=localpart(x)`.

# Example
```
using Distributed
addprocs(2)
@everywhere using DistributedOperations
x = ArrayFutures(Float64, (3,))
fill!(x, 1, workers())
y = reduce!(x)
y ≈ [2.0,2.0,2.0] # true
localpart(x) ≈ [2.0,2.0,2.0] # true
rmprocs(workers())
```
"""
function reduce!(futures::TypeFutures{T}, reducemethod!::Function=paralleloperations_reduce!) where {T}
    function _reduce!(future_mine, future_theirs, reducemethod!, _T::Type{T}) where {T}
        x = remotecall_fetch(fetch, future_theirs.where, future_theirs)::T
        y = fetch(future_mine)::T
        reducemethod!(y, x)
        nothing
    end

    pids = sort(collect(keys(futures)))
    M = length(pids)
    L = round(Int,log2(prevpow(2,M)))
    m = 2^L
    R = M - m

    if R != 0
        @sync for i = 1:R
            @async remotecall_fetch(_reduce!, pids[i], futures[pids[i]], futures[pids[m+i]], reducemethod!, T)
        end
    end

    for l = L:-1:1
        m = 2^(l-1)
        @sync for i = 1:m
            @async remotecall_fetch(_reduce!, pids[i], futures[pids[i]], futures[pids[m+i]], reducemethod!, T)
        end
    end
    fetch(futures[myid()])::T
end

@inline paralleloperations_copy!(y, x) = begin y .= x; nothing end

"""
    copy!(to::TypeFutures, from::TypeFutures[, copymethod!=DistributedOperations.paralleloperations_copy!, pids])

Copy `from` into `to` using `copymethod!`.
"""
function Base.copy!(to::TypeFutures{T}, from::TypeFutures{T}, copymethod!::Function, pids::AbstractArray=Int[]) where {T}
    pids = isempty(pids) ? keys(to) : pids
    function _copy!(future_to, future_from, copymethod!, _T::Type{T}) where {T}
        y = fetch(future_to)::T
        x = fetch(future_from)::T
        copymethod!(y, x)
        nothing
    end
    @sync for pid in pids
        @async pid ∈ keys(to) && pid ∈ keys(from) && remotecall_fetch(_copy!, pid, to[pid], from[pid], copymethod!, T)
    end
end
Base.copy!(to::TypeFutures, from::TypeFutures, pids::AbstractArray=procs()) = copy!(to, from, paralleloperations_copy!, pids)

@inline paralleloperations_fill!(x, a) = begin x .= a; nothing end

"""
    fill!(x::TypeFutures, a[, fillmethod!=DistributedOperations.fillmethod!, pids])

Fill `x` with `a::Number` using the `fillmethod!::Function`.
"""
function Base.fill!(futures::TypeFutures{T}, a::Number, fillmethod!::Function, pids::AbstractArray=Int[]) where {T}
    pids = isempty(pids) ? keys(futures) : pids
    function _fill!(future, a, fillmethod!, _T::Type{T}) where {T}
        x = fetch(future)::T
        fillmethod!(x,a)
        nothing
    end
    @sync for pid in pids
        @async remotecall_fetch(_fill!, pid, futures[pid], a, fillmethod!, T)
    end
end
Base.fill!(futures::TypeFutures, a::Number, pids::AbstractArray=Int[]) = fill!(futures, a, paralleloperations_fill!, pids)

using DistributedArrays
import DistributedArrays.localpart

"""
    localpart(x::TypeFutures)

Get the piece of `x::TypeFutures` that is local to `myid()`.
"""
localpart(futures::TypeFutures{T}) where {T} = fetch(futures[myid()])::T

Base.show(io::IO, futures::TypeFutures) = write(io, "TypeFutures with pids=$(keys(futures)) and type $(typeof(localpart(futures)))")
Base.show(io::IO, futures::ArrayFutures) = write(io, "ArrayFutures with pids=$(keys(futures)) and type $(size(localpart(futures)))")

export ArrayFutures, TypeFutures, bcast, bcast!, localpart, reduce!

end
