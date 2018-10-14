
abstract type ThreadSafty end
struct NotThreadSafe <: ThreadSafty end
struct CoarseGrainedLocking <: ThreadSafty end


ThreadSaftyStyle(::Type) = NotThreadSafe()