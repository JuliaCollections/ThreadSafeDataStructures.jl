
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


"""
    @delegate_lock_operations(T)

Declares all the lock operations to be delegated to the lock field.
"""
macro delegate_lock_operations(T)
    quote
        Base.Threads.islocked(datastruct::$T) = Base.Threads.islocked(datastruct.lock)
        Base.Threads.lock(datastruct::$T) = Base.Threads.lock(datastruct.lock)
        Base.Threads.trylock(datastruct::$T) = Base.Threads.trylock(datastruct.lock)
        Base.Threads.unlock(datastruct::$T) = Base.Threads.unlock(datastruct.lock)
    end |> esc
end

#############
include("coarselocking/array.jl")
include("coarselocking/condition.jl")