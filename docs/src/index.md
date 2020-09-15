# DistributedOperations.jl
Fast parallel broadcast and reduction operations for Julia using binary-tree
algorithms.  Note that we can broadcast and reduce over any Julia type, but we
provide convenience methods for performing these operations on Julia arrays.

## Broadcast
The `bcast` method copies an object to a set of machines.  The object can be
either an array or a composite structure.  The broadcasted object is stored as
an `Dict{Int,Future}` using the `TypeFutures` struct.  We retrieve the local
part of the `TypeFuture` using the `fetch` method.

## Reduce
The `reduce!` method, reduces a `TypeFuture` across all participating workers.  The
reduction follows the `reducemethod!` which is an optional argument to `reduce!`. By default
the reduction is a element-wise addition (i.e. `.+=`).  This is appropriate for our most
common use case where each item in `TypeFuture` is an array of a common size and
type.  In this case the resulting reduction is another array of that same common size
and type.

Please note that `reduce!` mutates the `TypeFuture` that it is applied to.  Hence,
calling `reduce!` twice on the same `TypeFuture` will produce different results.

## Similar packages
There are other packages that provide similar (but not equivalent) functionality, and
it may be worth thinking about how to consolidate efforts in the future:
* ParallelOperations.jl - https://github.com/JuliaAstroSim/ParallelOperations.jl
* ParallelDataTransfer.jl - https://github.com/ChrisRackauckas/ParallelDataTransfer.jl
* ArrayChannels.jl - https://github.com/rohanmclure/ArrayChannels.jl
