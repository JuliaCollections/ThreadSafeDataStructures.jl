
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
                replace(args, :datasruct => :(datastruct.backing)...)
            )


    unsafe_funcname = Symbol(:unthreadsafe_, funcname)

    unsafe_funcname, quote
        function $unsafe_funcname($(sigargs...))
            $call        
        end
    end
end

"""
Delegates a function to the backing of the datastruct.

Note the name `datastruct` must be used for the argument.
it must have a `lock` and a `backing` field.
"""
macro locking_delegate(expr)
    @capture(expr, funcname_(sigargs__)) || error("Invalid expression")
    args = breakup_sigargs(sigargs)
    unsafe_funcname, unsafefunc_def = declare_unthreadsafe(funcname, sigargs, args)
    
    quote
        $unsafefunc_def

        function $funcname($(sigargs...))
            try 
                # `try-finally` is faster than `lock(...) do` because sometimes optimiser fails
                lock(datastruct.lock)
                $unsafe_funcname(($args...))
            finally
                unlock(datastruct.lock)
            end
        end

    end |>esc
end

##############
struct TS_Array{T, N, A<:AbstractArray{T,N}} <: AbstractArray{T,N}
    backing::A
    lock::SpinLock
end

TS_Array(array) = TS_Array(array, SpinLock())


# TODO Deletate everything in https://docs.julialang.org/en/v1/manual/interfaces/index.html#man-interface-array-1
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

#= Similar needs special handling
Base.similar(datastruct::TS_Array)
Base.similar(A, ::Type{S})
Base.similar(A, dims::Dims)
Base.similar(A, ::Type{S}, dims::Dims)

Base.similar(A, ::Type{S}, inds)
Base.similar(T::Union{Type,Function}, inds)
=#



#TODO should we delegate to datastruct.lock, `islocked`, `lock`, `unlock` and `trylock` ? 

## Concrete constructors 

#TS_Array{T,N}() where {T,N} = TS_Array(Array{T,N}())
#TS_Matrix{T}() where T = TS_Array{T,2}()
#TS_Vector{T}() where T = TS_Array{T,1}()

