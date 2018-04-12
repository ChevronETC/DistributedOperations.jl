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
    @everywhere myfill!(future) = begin fill!(fetch(future), π); nothing end
    @sync for pid in procs()
        @async remotecall_fetch(myfill!, pid, futures[pid])
    end
    @test reduce!(futures) ≈ ones(n)*π*nprocs()
end
