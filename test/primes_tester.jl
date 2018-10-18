using Base.Threads

"""
    everythread(fun)
Run `fun` on everythread.
Returns when every instance of `fun` completes
"""
everythread(fun) = ccall(:jl_threading_run, Ref{Nothing}, (Any,), fun)


"""
inserts `xs` at the last position such that all elements prior to it are smaller than it.
And all after (if any) are larger.
Assumes `xs` is sorted (increasing),
"""
function push_sorted!(xs, y)
    lock(xs) do
        for ii in lastindex(xs):-1:1
            @inbounds prev = xs[ii]
            if prev < y
                insert!(xs, ii+1, y) # ii+1 is the index in the resulting array for y
                return xs
            end
        end
        # If got to here then y must be the smallest element, so put at start
        pushfirst!(xs, y)
    end
end


"""
    primes_threaded(n, store_type)

Returns the first `n` primes.
Storing them in an vector of the type specified.
That store must be threadsafe.
"""
function primes_threaded(n, ::Type{T}) where T<:AbstractVector
    prime_added = TS_Condition()
    known_primes = T()
    push!(known_primes, 2)
    
    function ith_prime(ii) # try and read the ith prime, if it is available. If not theen wait til it is
        while(length(known_primes) < ii)
            wait(prime_added)
        end
        @inbounds known_primes[ii]
    end
    
    function add_prime!(p) # Add a prime to our list and let anyone why was waiting for it know 
        push_sorted!(known_primes, p)
        notify(prime_added, all=true)
    end

    # Now the the actual code
    next_check = Atomic{Int}(3) # This is the (potentially prime) number the next thread that asked for something to check will et
    everythread() do
        while(true)
            x=atomic_add!(next_check, 1) #atomic_add! returns the *old* value befoe the addition
            for ii in 1:x # Not going to get up to this but it will be fine (except at x=2, got to watch that, good thing we already have 2 covered)
                p = ith_prime(ii) 
                if p > sqrt(x)
                    # Must be prime as we have not found any divisor
                    add_prime!(x)
                    break
                end
                if x % p == 0 # p divides
                    # not prime
                    break
                end
            end

            if length(known_primes) >= n
                return
            end
        end
    end
    return known_primes
end

"""
primes_array(n)

Returns the first `n` primes
"""
function primes_array(n)
    known_primes = Vector([2])
    sizehint!(known_primes, n)
    
    x=3
    while true
        for p in known_primes
            if p > sqrt(x)
                # Must be prime as we have not found any divisor
                push!(known_primes, x)
                break
            end
            if x % p == 0 # p divides
                # not prime
                break
            end
        end
        x+=1
        length(known_primes) == n && break
    end
    return known_primes
end


##################

using ThreadSafeDataStructures
@show nthreads()
@time primes_threaded(10_000, TS_Vector{Int});
@time primes_threaded(10_000, TS_Vector{Int});
@time primes_threaded(10_000, TS_Vector{Int});
@time primes_threaded(10_000, TS_Vector{Int});
@time primes_threaded(10_000, TS_Vector{Int});
