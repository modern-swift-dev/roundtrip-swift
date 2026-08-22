# WebSockets

[Documentation index](<doc:RoundTrip>)

Create a WebSocket from ``HttpClient/webSocketClient(request:keepAlive:)``. ``WSSClient`` publishes connection and message events through Combine.

```swift
import Combine

let request = URLRequestBuilder(string: "wss://example.com/socket")!
let socket = try HttpClient().webSocketClient(request: request)
let events = socket.event.sink { event in
    if case let .textMessageReceived(text) = event {
        print(text)
    }
}

socket.connect()
socket.send(text: "hello")
```

Keep the Combine cancellable for as long as you need events. Call `disconnect()` when the connection is no longer needed. Configure `WSSClient.KeepAliveConfig` when the server expects pings.
