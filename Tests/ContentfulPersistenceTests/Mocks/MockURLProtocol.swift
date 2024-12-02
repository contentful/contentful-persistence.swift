import Foundation

class MockURLProtocol: URLProtocol {
    /// Dictionary maps URLs to error, data, and response
    static var mockURLs = [URL?: (error: Error?, data: Data?, response: HTTPURLResponse?)]()

    override class func canInit(with _: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        defer {
            self.client?.urlProtocolDidFinishLoading(self)
        }

        if let url = request.url {
            guard MockURLProtocol.mockURLs.keys.contains(url) else {
                fatalError("URL not mocked")
            }

            if let (error, data, response) = MockURLProtocol.mockURLs[url] {
                if let data {
                    client?.urlProtocol(self, didLoad: data)
                }
                
                if let response {
                    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                }
                
                if let error {
                    client?.urlProtocol(self, didFailWithError: error)
                }
            }
        }
    }

    override func stopLoading() {}
}
