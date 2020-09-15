using DistributedArrays, DistributedOperations, Documenter

makedocs(sitename="DistributedOperations", modules=[DistributedOperations])
 

deploydocs(
    repo = "git@github.com:ChevronETC/DistributedOperations.jl.git"
)