import Foundation

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

public extension URLResponse {

    /// Returns the HTTP status code if this is an HTTPURLResponse, nil otherwise
    private var httpStatusCode: Int? {
        (self as? HTTPURLResponse)?.statusCode
    }

    /// return true if the code is in the 200-299 range
    var is2xx: Bool {
        guard let code = httpStatusCode else {
            return false
        }
        return (200 ..< 300).contains(code)
    }

    /// return true if the code is in the 300-399 range
    var is3xx: Bool {
        guard let code = httpStatusCode else {
            return false
        }
        return (300 ..< 400).contains(code)
    }

    /// return true if the code is in the 400-499 range
    var is4xx: Bool {
        guard let code = httpStatusCode else {
            return false
        }
        return (400 ..< 500).contains(code)
    }

    /// return true if the code is in the 500-599 range
    var is5xx: Bool {
        guard let code = httpStatusCode else {
            return false
        }
        return (500 ..< 600).contains(code)
    }

    /// Return true if status code is 200
    var is200: Bool {
        httpStatusCode == 200
    }

    /// Return true if status code is 201
    var is201: Bool {
        httpStatusCode == 201
    }

    /// Return true if status code is 302
    var is302: Bool {
        httpStatusCode == 302
    }

    /// Return true if status code is 304
    var is304: Bool {
        httpStatusCode == 304
    }

    /// Return true if status code is 400
    var is400: Bool {
        httpStatusCode == 400
    }

    /// Return true if status code is 401
    var is401: Bool {
        httpStatusCode == 401
    }

    /// Return true if status code is 403
    var is403: Bool {
        httpStatusCode == 403
    }

    /// Return true if status code is 404
    var is404: Bool {
        httpStatusCode == 404
    }

    /// Return true if status code is 500
    var is500: Bool {
        httpStatusCode == 500
    }

    /// Return true if status code is 503
    var is503: Bool {
        httpStatusCode == 503
    }

    /// Return the last modified of this response
    var lastModified: Date? {
        guard let response = self as? HTTPURLResponse,
              let string = response.allHeaderFields["Last-Modified"] as? String,
              let date = DateFormatter.httpHeaderFormatter.date(from: string) else {
            return nil
        }

        return date
    }

    /// Return the last modified of this response
    var expires: Date? {
        guard let response = self as? HTTPURLResponse,
              let string = response.allHeaderFields["Expires"] as? String,
              let date = DateFormatter.httpHeaderFormatter.date(from: string) else {
            return nil
        }

        return date
    }

    /// Return the etag of this response
    var etag: String? {
        guard let response = self as? HTTPURLResponse else {
            return nil
        }
        // Header field lookup is case-insensitive in HTTP, but allHeaderFields dictionary is case-sensitive
        // HTTPURLResponse normalizes header names, so we need to find the key case-insensitively
        for (key, value) in response.allHeaderFields {
            if let keyString = key as? String,
               keyString.lowercased() == "etag",
               let valueString = value as? String {
                return valueString
            }
        }
        return nil
    }

}
