# REST cancellation and concurrency

[Documentation index](<doc:RoundTripREST>)

Use `RestClient` from async tasks and propagate cancellation from the caller. A cancelled URLSession operation may surface as `ApiError.cancelled` or `URLError.cancelled` depending on the operation path.

`NetworkService.cancelAll()` cancels all tasks in that service's session. `invalidate()` also invalidates the session. Give separate features separate services when their cancellation lifetimes differ.

The error publisher is a Combine value. Keep its subscriptions alive for as long as the observer needs them, and deliver UI changes on the main actor.
