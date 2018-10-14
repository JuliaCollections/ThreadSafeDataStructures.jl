
expr = :(Base.length(datastruct))

"""
Delegates a function to the backing of the datastruct.

Note the name `datastruct` must be used for the argument.
it must have a `lock` and a `backing` field.
"""
macro locking_delegate(expr)
    @capture(expr, func_(sigargs__)) || error("Invalid expression")

    args = Vector{Symbol}()
    for sigarg in sigargs
        arg, kind = @match sigarg begin
            x_::T_  => (x,T)
            ::T_    => (Base.gensym(), T)
            x_      => (x, :Any)
            #TODO: there are other kinds too
        end
        push!(args, arg)
    end

    call = Expr(:call, func, 
                (arg == :datastruct ? :(datastruct.backing) : arg for arg in args)...)

    body = quote
        try 
            # `try-finally` is faster than `lock(...) do` because sometimes optimiser fails
            lock(datastruct.lock)
            $call
        finally
            unlock(datastruct.lock)
        end
    end |>esc
    #TODO should we actually generare `unthreadsafe_$func`, then have
    Expr(:function, esc(expr), body)
end

##############
struct TS_Array{T, N, A<:AbstractArray{T,N}} <: AbstractArray{T,N}
    backing::A
    lock::SpinLock
end

TS_Array(array) = TS_Array(array, SpinLock())


# TODO Deletate everything in https://docs.julialang.org/en/v1/manual/interfaces/index.html#man-interface-array-1
# Even the ones with defaults, since we might be wrapping something that makes them act different

@locking_delegate Base.length(datastruct::TS_Array)
@locking_delegate Base.axes(datastruct::TS_Array)


#TODO should we delegate to datastruct.lock, `islocked`, `lock`, `unlock` and `trylock` ? 

## Concrete constructors 

#TS_Array{T,N}() where {T,N} = TS_Array(Array{T,N}())
#TS_Matrix{T}() where T = TS_Array{T,2}()
#TS_Vector{T}() where T = TS_Array{T,1}()

