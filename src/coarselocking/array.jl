
##############
struct TS_Array{T, N, A<:AbstractArray{T,N}} <: AbstractArray{T,N}
    backing::A
    lock::RecursiveSpinLock
end


TS_Matrix{T} = TS_Array{T,2}
TS_Vector{T} = TS_Array{T,1}

TS_Array(array) = TS_Array(array, RecursiveSpinLock())

ThreadSaftyStyle(::Type{<:TS_Array}) = CoarseGrainedLocking()
@delegate_lock_operations TS_Array


## === AbstractArray ===
# Delegate everything in https://docs.julialang.org/en/v1/manual/interfaces/index.html#man-interface-array-1
# Even the ones with defaults, since we might be wrapping something that makes them act different

@locking_delegate Base.size(datastruct::TS_Array)
@locking_delegate Base.getindex(datastruct::TS_Array, i::Int)
@locking_delegate Base.getindex(datastruct::TS_Array, i...)
@locking_delegate Base.setindex!(datastruct::TS_Array, v, i::Int)
@locking_delegate Base.setindex(datastruct::TS_Array, i...)

Base.IndexStyle(::Type{<:TS_Array{T, N, A}}) where {A, T, N} = IndexStyle(A)
@locking_delegate Base.iterate(datastruct::TS_Array)
@locking_delegate Base.iterate(datastruct::TS_Array, state)

@locking_delegate Base.length(datastruct::TS_Array)
@locking_delegate Base.axes(datastruct::TS_Array)


@locking_delegate Base.similar(datastruct::TS_Array)                        TS_Array
@locking_delegate Base.similar(datastruct::TS_Array, s::Type)               TS_Array
@locking_delegate Base.similar(datastruct::TS_Array, dims::Dims)            TS_Array
@locking_delegate Base.similar(datastruct::TS_Array, s::Type, dims::Dims)   TS_Array

@locking_delegate Base.similar(datastruct::TS_Array, s::Type, inds)         TS_Array
@locking_delegate Base.similar(T::Union{Type,Function}, inds)               TS_Array

## === dequeue-ish ===
@locking_delegate Base.push!(datastruct::TS_Vector, x)
@locking_delegate Base.pushfirst!(datastruct::TS_Vector, x)
@locking_delegate Base.pop!(datastruct::TS_Vector, x)
@locking_delegate Base.popfirst!(datastruct::TS_Vector, x)

@locking_delegate Base.insert!(datastruct::TS_Vector, ind::Integer, item)
@locking_delegate Base.deleteat!(datastruct::TS_Vector, ind)




## Concrete constructors 


TS_Array{T,N}() where {T,N} = TS_Array(Array{T,N}())
TS_Matrix() = TS_Array{Any,2}()
TS_Vector() = TS_Array{Any,1}()

##