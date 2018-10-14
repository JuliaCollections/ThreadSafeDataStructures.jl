using ThreadSafeDataStructures
using Test

@testset begin
    xs = [1,2,3]
    ts_xs = TS_Array(xs)

    @test length(ts_xs) == length(xs)
    @test axes(ts_xs) == axes(xs)
end