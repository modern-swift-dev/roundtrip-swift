#if canImport(SwiftUI) || canImport(UIKit) || canImport(AppKit)
    #if canImport(UIKit)
        import Foundation
        #if canImport(FoundationNetworking)
            import FoundationNetworking
        #endif
        import RoundTrip
        import Testing
        import UIKit

        @Suite(.serialized) struct HttpRequestBuilderTests {

            @Test func formBody() throws {
                let builder = try #require(URLRequestBuilder(string: "http://www.google.ca")?
                    .setMethod(.post)
                    .setBody(formEncoded: [
                        .init(name: "test", value: "123")
                    ]))

                let result = try builder.buildRequest(baseUrl: nil, encoder: JSONEncoder()).httpBody ?? Data(capacity: 1)
                let string = String(data: result, encoding: .utf8)
                #expect(string == "test=123")
                #expect(string != "test=124")
            }
        }
    #endif

#endif
