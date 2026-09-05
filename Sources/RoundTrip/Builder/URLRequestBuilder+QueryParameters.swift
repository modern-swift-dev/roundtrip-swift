import Foundation

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

// MARK: - Query Parameters
public extension URLRequestBuilder {

    /// Add a query param
    /// - parameter name: The name of the parameter
    /// - parameter value: the value of the parameter
    /// - returns: `self`
    func addQueryParam(name: String, value: any FormEncodable) -> Self {
        if pendingQueryItems == nil {
            pendingQueryItems = components.percentEncodedQueryItems ?? []
        }
        let item = URLQueryItem(
            name: name.addingPercentEncoding(withAllowedCharacters: .improvedQueryAllowed) ?? name,
            value: value.formEncodableValue().addingPercentEncoding(withAllowedCharacters: .improvedQueryAllowed)
        )
        pendingQueryItems?.append(item)
        return self
    }

    /// Add a query parameters
    /// - parameter parameters: The parameters
    /// - returns: `self`
    func addQueryParams(_ parameters: [URLRequestBuilder.FormParameter]) -> Self {
        guard !parameters.isEmpty else {
            return self
        }
        if pendingQueryItems == nil {
            pendingQueryItems = components.percentEncodedQueryItems ?? []
        }
        for param in parameters {
            let item = URLQueryItem(
                name: param.name.addingPercentEncoding(withAllowedCharacters: .improvedQueryAllowed) ?? param.name,
                value: param.value
                    .formEncodableValue()
                    .addingPercentEncoding(withAllowedCharacters: .improvedQueryAllowed)
            )
            pendingQueryItems?.append(item)
        }
        return self
    }
}

public extension CharacterSet {

    /// A special character set for encoding `GET` and `DELETE` parameters for
    /// a django back-end, which does not like those special character when
    /// decoding parameters
    static let improvedQueryAllowed: CharacterSet = {
        var characterSet = CharacterSet.urlQueryAllowed
        characterSet.remove(charactersIn: ":#[]@!$&'()*+,;=/ ?")
        return characterSet
    }()
}
