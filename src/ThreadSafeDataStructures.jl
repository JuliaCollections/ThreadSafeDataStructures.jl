module ThreadSafeDataStructures
using MacroTools
using Base.Threads

export TS_Array, TS_Vector, TS_Matrix

include("traits.jl")

include("coarselocking.jl")


end # module
