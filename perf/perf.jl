using PBSMan
cman = PBSManager()
addprocs(cman, 16, jobgroup="jg_n28_384_none_NEX_gsu_a")
@everywhere using ParallelOperations

@everywhere myfill!(future) = begin fill!(fetch(future), 1.0); nothing; end
@everywhere g(future) = mean(fetch(future)::Array{Float64,1})
function stats(futures)
    s = zeros(nworkers())
    @sync for (ipid,pid) in enumerate(workers())
        @async s[ipid] = remotecall_fetch(g, pid, futures[pid])
    end
    s
end

function main()
    N = div(10_000_000_000,8)
    x = rand(N)
    write(STDOUT, "running on $(nprocs()) processes including master\n")
    @time futures = bcast(x)
    @time observed = stats(futures)
    expected = mean(x)
    for _observed in observed
        Test.@test _observed ≈ expected
    end

    futures = ArrayFutures(Float64, (N,))
    @sync for pid in procs()
        @async remotecall_fetch(myfill!, pid, futures[pid])
    end
    @time reduce!(futures)
    Test.@test fetch(futures[myid()]) ≈ nprocs()*ones(size(x))
end

main()

rmprocs(cman)
