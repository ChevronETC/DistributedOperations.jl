__precompile__(true)

module ParallelOperations

struct ArrayFutures{T,N} f::Dict{Int,Future} end
Base.getindex(a::ArrayFutures, i::Int) = getindex(a.f, i)
Base.setindex!(a::ArrayFutures, f::Future, i::Int) = setindex!(a.f, f, i)
Base.keys(a::ArrayFutures) = keys(a.f)

function ArrayFutures(_T::Type{T}, n::NTuple{N,Int}, pids=procs()) where {T,N}
    pids[1] == myid() || error("expected myid()==pids[1], got pids[1]=$(pids[1]) where-as myid()=$(myid())")

    futures = Dict()
    @sync for pid in pids
        futures[pid] = remotecall(zeros, pid, T, n)
        @async remotecall_fetch(wait, pid, futures[pid])
    end
    ArrayFutures{T,N}(futures)
end
function ArrayFutures(x::Array{T,N}, pids=procs()) where {T,N}
    futures = Dict()
    n = size(x)
    @sync for pid in pids
        if pid == myid()
            futures[pid] = Future()
            put!(futures[pid], x)
        else
            futures[pid] = remotecall(zeros, pid, T, n)
            @async remotecall_fetch(wait, pid, futures[pid])
        end
    end
    ArrayFutures{T,N}(futures)
end

function bcast(x::AbstractArray{T,N}, pids=procs()) where {T,N}
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

    ArrayFutures{T,N}(futures)
end

function reduce!(futures::ArrayFutures{T,N}) where {T,N}
    function _reduce!(future_mine, future_theirs, T::DataType, N::Int)
        x = remotecall_fetch(fetch, future_theirs.where, future_theirs)::Array{T,N}
        y = fetch(future_mine)::Array{T,N}
        y .+= x
        nothing
    end

    pids = sort(collect(keys(futures)))
    M = length(pids)
    L = round(Int,log2(prevpow2(M)))
    m = 2^L
    R = M - m

    if R != 0
        @sync for i = 1:R
            @async remotecall_fetch(_reduce!, pids[i], futures[pids[i]], futures[pids[m+i]], T, N)
        end
    end

    for l = L:-1:1
        m = 2^(l-1)
        @sync for i = 1:m
            @async remotecall_fetch(_reduce!, pids[i], futures[pids[i]], futures[pids[m+i]], T, N)
        end
    end
    fetch(futures[myid()])::Array{T,N}
end

function Base.copy!(to::ArrayFutures, from::ArrayFutures, pids=procs())
    function _copy!(future_to, future_from)
        x = fetch(future_to)
        y = fetch(future_from)
        x .= y
        nothing
    end
    @sync for pid in pids
        @async pid ∈ keys(to) && pid ∈ keys(from) && remotecall_fetch(_copy!, pid, to[pid], from[pid])
    end
end

function Base.fill!(futures::ArrayFutures, a::Number, pids=Int[])
    pids = isempty(pids) ? keys(futures) : pids
    function _fill!(future, a)
        x = fetch(future)
        x .= a
        nothing
    end
    @sync for pid in pids
        @async remotecall_fetch(_fill!, pid, futures[pid], a)
    end
end

using DistributedArrays
import DistributedArrays.localpart
localpart(futures::ArrayFutures{T,N}) where {T,N} = fetch(futures[myid()])::Array{T,N}

Base.show(io::IO, futures::ArrayFutures) = write(io, "ArrayFutures with pids=$(keys(futures)) and size $(size(localpart(futures)))")

export ArrayFutures, bcast, localpart, reduce!

end
