

struct TS_Condition
    backing::Condition
    lock::RecursiveSpinLock
end

TS_Condition(cond::Condition) = TS_Condition(cond, RecursiveSpinLock())
TS_Condition() = TS_Condition(Condition())

ThreadSaftyStyle(::Type{<:TS_Condition}) = CoarseGrainedLocking()
@delegate_lock_operations TS_Condition



@locking_delegate Base.wait(datastruct::TS_Condition)
@locking_delegate Base.notify(datastruct::TS_Condition, arg, all, error)

Base.notify(c::TS_Condition, @nospecialize(arg = nothing); all=true, error=false) = notify(c, arg, all, error)
