using PBSMan
cman = PBSManager()
addprocs(cman, 127, jobgroup="jg_n28_384_none_NEX_gsu_a")
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
    x = rand(div(1_000_000_000,8))
    write(STDOUT, "running on $(nprocs()) processes including master\n")
    @time futures = bcast(x)
    @time observed = stats(futures)
    expected = mean(x)
    for _observed in observed
        Test.@test _observed ≈ expected
    end

    futures = ArrayFutures(Float64, (div(1_000_000_000,8),))
    @sync for pid in procs()
        @async remotecall_fetch(myfill!, pid, futures[pid])
    end
    @time reduce!(futures)
    Test.@test fetch(futures[myid()]) ≈ nprocs()*ones(size(x))
end

main()

rmprocs(cman)
