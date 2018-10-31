using ThreadSafeDataStructures
using Test
using Base.Threads
@show nthreads()

const testfiles = [
    "test_coarselocking.jl",
    "primes_tester.jl"
]



for testfile in testfiles
    @testset "$testfile" begin
        include(testfile)
    end
end
