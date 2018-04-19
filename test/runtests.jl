addprocs(6)
using Base.Test
@everywhere using ParallelOperations

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

@testset "Broadcast" for n in ((10,), (10,11)), T in (Float32,Float64)
    x = rand(T,n)
    futures = bcast(x)
    for pid in procs()
        @test fetch(futures[pid]) ≈ x
    end
end

@testset "Reduce" for n in ((10,), (10,11)), T in (Float32,Float64)
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

@testset "localpart" for n in ((10,), (10,11)), T in (Float32,Float64)
    futures = ArrayFutures(T, n)
    @everywhere myfill!(future) = begin fill!(fetch(future), myid()*π); nothing end
    @sync for pid in procs()
        @async remotecall_fetch(myfill!, pid, futures[pid])
    end
    for pid in procs()
        @test remotecall_fetch(localpart, pid, futures) ≈ pid*π*ones(T,n)
    end
end
