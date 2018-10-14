using ThreadSafeDataStructures
using Test

const testfiles = [
    "test_coarselocking.jl",
]



for testfile in testfiles
    @testset "$testfile" begin
        include(testfile)
    end
end
