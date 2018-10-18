
abstract type ThreadSafty end
abstract type ThreadSafe <: ThreadSafty end
struct NotThreadSafe <: ThreadSafty end
struct CoarseGrainedLocking <: ThreadSafe end


ThreadSaftyStyle(::Type) = NotThreadSafe()