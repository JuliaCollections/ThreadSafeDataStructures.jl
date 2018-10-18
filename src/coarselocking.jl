
function breakup_sigargs(sigargs)
    args = Vector{Union{Symbol,Expr}}()
    for sigarg in sigargs
        arg, kind = @match sigarg begin
            x_::T_  => (x,T)
            ::T_    => (Base.gensym(), T)
            x_      => (x, :Any)
            #TODO: there are other kinds too
        end
        push!(args, arg)
    end
    args
end

function declare_unthreadsafe(funcname, sigargs, args)
    call = Expr(:call, 
                funcname, 
                replace(args, :datastruct => :(datastruct.backing))...
            )


    unsafe_funcname = Symbol(:unthreadsafe_, funcname)

    unsafe_funcname, :($unsafe_funcname($(sigargs...)) = $call)
end

"""
Delegates a function to the backing of the datastruct.

Note the name `datastruct` must be used for the argument.
it must have a `lock` and a `backing` field.
"""
macro locking_delegate(expr, cast=:identity)
    @capture(expr, modname_.funcname_(sigargs__)) || error("Invalid expression")
    args = breakup_sigargs(sigargs)
    unsafe_funcname, unsafefunc_def = declare_unthreadsafe(funcname, sigargs, args)
    
    quote
        $unsafefunc_def

        function $modname.$funcname($(sigargs...))
            try 
                # `try-finally` is faster than `lock(...) do` because sometimes optimiser fails
                lock(datastruct)
                ret = $(Expr(:call, unsafe_funcname, args...))
                $cast(ret)
            finally
                unlock(datastruct)
            end
        end

    end |>esc
end

##############
struct TS_Array{T, N, A<:AbstractArray{T,N}} <: AbstractArray{T,N}
    backing::A
    lock::RecursiveSpinLock
end


TS_Matrix{T} = TS_Array{T,2}
TS_Vector{T} = TS_Array{T,1}

TS_Array(array) = TS_Array(array, RecursiveSpinLock())

ThreadSaftyStyle(::Type{<:TS_Array}) = CoarseGrainedLocking()

# === AbstractLock ===
Base.Threads.islocked(datastruct::TS_Array) = Base.Threads.islocked(datastruct.lock)
Base.Threads.lock(datastruct::TS_Array) = Base.Threads.lock(datastruct.lock)
Base.Threads.trylock(datastruct::TS_Array) = Base.Threads.trylock(datastruct.lock)
Base.Threads.unlock(datastruct::TS_Array) = Base.Threads.unlock(datastruct.lock)



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