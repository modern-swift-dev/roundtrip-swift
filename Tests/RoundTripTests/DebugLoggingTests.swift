@testable import RoundTrip
import Testing

struct DebugLoggingTests {
    @Test func debugMessageIsOnlyBuiltWhenLoggingIsEnabled() {
        var messageBuildCount = 0
        func makeMessage() -> String {
            messageBuildCount += 1
            return "RoundTrip debug logging evaluation test"
        }

        let isEnabled = RoundTripSupport.isDebugLoggingEnabled
        RoundTripSupport.logDebug(makeMessage())

        #expect(messageBuildCount == (isEnabled ? 1 : 0))
    }
}
