using Distributed
addprocs(6)
@everywhere using Distributed, ParallelOperations, Random, Test

@testset "Construction" for n in ((10,), (10,11)), T in (Float32,Float64)
    x = ones(T,n)
    futures = ArrayFutures(x)
    for pid in procs()
        y = fetch(futures[pid])
        @test size(y) == n
        @test eltype(y) == T
    end
    futures = ArrayFutures(T, n)
    for pid in procs()
        y = fetch(futures[pid])
        @test size(y) == n
        @test eltype(y) == T
    end
end

@testset "Broadcast, array" for n in ((10,), (10,11)), T in (Float32,Float64)
    x = rand(T,n)
    futures = bcast(x)
    for pid in procs()
        @test fetch(futures[pid]) ≈ x
    end
end

@testset "Broadcast, type" for n = ((10,), (10,11)), T in (Float32,Float64)
    x = (rand(T,n),rand(T,n))
    futures = bcast(x)
    for pid in procs()
        @test fetch(futures[pid])[1] ≈ x[1]
        @test fetch(futures[pid])[2] ≈ x[2]
    end
end

@testset "In-place broadcast" for n in ((10,), (10,11)), T in (Float32,Float64)
    x = rand(T,n)
    futures = bcast(x)
    wrkrs = addprocs(2)
    bcast!(futures, wrkrs)
    for pid in procs()
        @test fetch(futures[pid]) ≈ x
    end
    rmprocs(wrkrs)
end

@testset "Reduce, array" for n in ((10,), (10,11)), T in (Float32,Float64)
    futures = ArrayFutures(T, n)
    @everywhere myfill!(future) = begin rand!(fetch(future)); nothing end
    @sync for pid in procs()
        @async remotecall_fetch(myfill!, pid, futures[pid])
    end
    expected = zeros(T,n)
    for pid in procs()
        expected .+= remotecall_fetch(fetch, pid, futures[pid])
    end
    for pid in procs()
        fetch(futures[pid])
    end
    @test reduce!(futures) ≈ expected
end

@testset "Reduce, type" for n = ((10,), (10,11)), T in (Float32,Float64)
    _foo() = (zeros(T,n),zeros(T,n))
    N = length(n)
    futures = TypeFutures(Tuple{Array{T,N},Array{T,N}}, _foo)
    @everywhere myfill!(future) = begin t = fetch(future); rand!(t[1]); rand!(t[2]); nothing end
    @sync for pid in procs()
        @async remotecall_fetch(myfill!, pid, futures[pid])
    end
    expected = (zeros(T,n),zeros(T,n))
    for pid in procs()
        x = remotecall_fetch(fetch, pid, futures[pid])
        expected[1] .+= x[1]
        expected[2] .+= x[2]
    end
    for pid in procs()
        fetch(futures[pid])
    end
    observed = reduce!(futures, (y,x)->begin y[1] .+= x[1]; y[2] .+= x[2] end)
    @test observed[1] ≈ expected[1]
    @test observed[2] ≈ expected[2]
end

@testset "localpart, array" for n in ((10,), (10,11)), T in (Float32,Float64)
    futures = ArrayFutures(T, n)
    @everywhere myfill!(future) = begin fill!(fetch(future), myid()*π); nothing end
    @sync for pid in procs()
        @async remotecall_fetch(myfill!, pid, futures[pid])
    end
    for pid in procs()
        @test remotecall_fetch(localpart, pid, futures) ≈ pid*π*ones(T,n)
    end
end

@testset "localpart, type" for n = ((10,), (10,11)), T in (Float32,Float64)
    N = length(n)
    _foo() = (myid()*T(π)*ones(T,n), 2*myid()*T(π)*ones(T,n))
    futures = TypeFutures(Tuple{Array{T,N},Array{T,N}}, _foo)
    for pid in procs()
        r = remotecall_fetch(localpart, pid, futures)
        @test r[1] ≈ pid*π*ones(T,n)
        @test r[2] ≈ 2*pid*π*ones(T,n)
    end
end

@testset "copy!, array" for n in ((10,), (10,11)), T in (Float32,Float64)
    futures = ArrayFutures(T,n)
    @everywhere myfill!(future) = begin fill!(fetch(future), myid()*π); nothing end
    @sync for pid in procs()
        @async remotecall_fetch(myfill!, pid, futures[pid])
    end
    futures_copy = ArrayFutures(T,n)
    copy!(futures_copy, futures)
    for pid in procs()
        @test remotecall_fetch(localpart, pid, futures_copy) ≈ pid*π*ones(T,n)
    end
    fill!(futures_copy, 0)
    copy!(futures_copy, futures, [3,5])
    for pid in procs()
        if pid ∈ (3,5)
            @test remotecall_fetch(localpart, pid, futures_copy) ≈ pid*π*ones(T,n)
        else
            @test remotecall_fetch(localpart, pid, futures_copy) ≈ zeros(T,n)
        end
    end
end

@testset "copy!, type" for n in ((10,), (10,11)), T in (Float32,Float64)
    N = length(n)
    _foo() = (myid()*T(π)*ones(T,n), 2*myid()*T(π)*ones(T,n))
    futures = TypeFutures(Tuple{Array{T,N},Array{T,N}}, _foo)
    futures_copy = TypeFutures(Tuple{Array{T,N},Array{T,N}}, ()->(zeros(T,n),zeros(T,n)))
    copy!(futures_copy, futures, (x,y)->begin x[1] .=  y[1]; x[2] .= y[2] end)
    for pid in procs()
        r = remotecall_fetch(localpart, pid, futures_copy)
        @test r[1] ≈ pid*π*ones(T,n)
        @test r[2] ≈ 2*pid*π*ones(T,n)
    end
    fill!(futures_copy, 0, (x,a)->begin x[1] .= a; x[2] .= a end)
    copy!(futures_copy, futures, (x,y)->begin x[1] .= y[1]; x[2] .= y[2] end, [3,5])
    for pid in procs()
        r = remotecall_fetch(localpart, pid, futures_copy)
        if pid ∈ (3,5)
            @test r[1] ≈ pid*π*ones(T,n)
            @test r[2] ≈ 2*pid*π*ones(T,n)
        else
            @test r[1] ≈ zeros(T,n)
            @test r[2] ≈ zeros(T,n)
        end
    end
end

@testset "fill!, array" for n in ((10,), (10,11)), T in (Float32,Float64)
    futures = ArrayFutures(T,n)
    fill!(futures, π)
    for pid in procs()
        @test remotecall_fetch(localpart, pid, futures) ≈ π*ones(T,n)
    end
    fill!(futures, 2*pi, [3,5])
    for pid in procs()
        if pid ∈ (3,5)
            @test remotecall_fetch(localpart, pid, futures) ≈ 2*π*ones(T,n)
        else
            @test remotecall_fetch(localpart, pid, futures) ≈ π*ones(T,n)
        end
    end
end

@testset "fill!, type" for n in ((10,), (10,11)), T in (Float32,Float64)
    N = length(n)
    _foo() = (T(π)*ones(T,n), 2*T(π)*ones(T,n))
    futures = TypeFutures(Tuple{Array{T,N},Array{T,N}}, _foo)
    fill!(futures, 3*π, (x,a)->begin x[1] .= a; x[2] .= a end, [3,5])
    for pid in procs()
        r = remotecall_fetch(localpart, pid, futures)
        if pid ∈ (3,5)
            @test r[1] ≈ 3*π*ones(T,n)
            @test r[2] ≈ 3*π*ones(T,n)
        else
            @test r[1] ≈ π*ones(T,n)
            @test r[2] ≈ 2*π*ones(T,n)
        end
    end
end
