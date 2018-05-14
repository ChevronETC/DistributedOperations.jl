__precompile__(true)

module ParallelOperations

struct TypeFutures{T} f::Dict{Int,Future} end
Base.getindex(a::TypeFutures, i::Int) = getindex(a.f, i)
Base.setindex!(a::TypeFutures, f::Future, i::Int) = setindex!(a.f, f, i)
Base.keys(a::TypeFutures) = keys(a.f)

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

function TypeFutures(x::T, f::Function, pids::AbstractArray, fargs::Vararg) where {T}
    futures = Dict()
    n = size(x)
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
TypeFutures(x::T, f::Function, fargs::Vararg) where {T} = TypeFutures(x, f, pids, fargs...)

ArrayFutures{T,N} = TypeFutures{Array{T,N}}
ArrayFutures(_T::Type{T}, n::NTuple{N,I}, pids=procs()) where {T,N,I<:Integer} = TypeFutures(Array{T,N}, zeros, pids, T, n)
ArrayFutures(x::Array{T,N}, pids=procs()) where {T,N} = TypeFutures(x, zeros, pids, T, size(x))

function bcast(x::T, pids=procs()) where {T}
    pids[1] == myid() || error("expected myid()==pids[1], got pids[1]=$(pids[1]) where-as myid()=$(myid())")

    M = length(pids)
    L = round(Int,log2(prevpow2(M)))
    m = 2^L
    R = M - m

    _f(x) = x
    futures = Dict(pids[1]=>remotecall(_f, myid(), x))

    if R != 0
        @sync for i = 1:R
            futures[pids[i+m]] = remotecall(fetch, pids[i+m], futures[pids[1]])
            @async remotecall_fetch(wait, pids[i+m], futures[pids[i+m]])
        end
    end

    for l = 1:L
        m = 2^(l-1)
        @sync for i = 1:m
            futures[pids[i+m]] = remotecall(fetch, pids[i+m], futures[pids[i]])
            @async remotecall_fetch(wait, pids[i+m], futures[pids[i+m]])
        end
    end

    TypeFutures{T}(futures)
end

@inline paralleloperations_reduce!(y, x) = begin y .+= x; nothing end
function reduce!(futures::TypeFutures{T}, reducemethod!::Function=paralleloperations_reduce!) where {T}
    function _reduce!(future_mine, future_theirs, reducemethod!, _T::Type{T}) where {T}
        x = remotecall_fetch(fetch, future_theirs.where, future_theirs)::T
        y = fetch(future_mine)::T
        reducemethod!(y, x)
        nothing
    end

    pids = sort(collect(keys(futures)))
    M = length(pids)
    L = round(Int,log2(prevpow2(M)))
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
localpart(futures::TypeFutures{T}) where {T} = fetch(futures[myid()])::T

Base.show(io::IO, futures::TypeFutures) = write(io, "TypeFutures with pids=$(keys(futures)) and type $(typeof(localpart(futures)))")
Base.show(io::IO, futures::ArrayFutures) = write(io, "ArrayFutures with pids=$(keys(futures)) and type $(size(localpart(futures)))")

export ArrayFutures, TypeFutures, bcast, localpart, reduce!

end
