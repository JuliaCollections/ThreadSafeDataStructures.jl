using ThreadSafeDataStructures
using Test

@testset "Abstract Array Interface" begin
    for xs in ([1,2,3], rand(10,10), 1:100, [1.5im, 0.5, 2.5+2im]')
        ts_xs = TS_Array(xs)

        @test length(ts_xs) == length(xs)
        @test axes(ts_xs) == axes(xs)
        @test size(ts_xs) == size(xs)

        @testset "Iteration" begin
            for (x,t) in zip(xs, ts_xs)
                @test x==t
            end
        end
        
        @testset "Similar" begin
            sim = similar(ts_xs, Float32)
            @test sim isa TS_Array
            @test size(sim) ==size(xs)
            @test eltype(sim) == Float32
        end
    end
end