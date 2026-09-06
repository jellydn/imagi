import XCTest
@testable import StudioCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class ProviderTests: XCTestCase {
    private func input(_ provider: ProviderID = .openAI, count: Int = 1, ratio: AspectRatio = .square, reference: Data? = nil) -> ImageRequest {
        ImageRequest(prompt: "A tiny astronaut in Singapore", options: .init(provider: provider, count: count, ratio: ratio), referencePNG: reference)
    }

    private func json(_ request: URLRequest) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any])
    }

    func testOpenAIGenerationUsesNativeSizeAndNumericCount() throws {
        let request = try OpenAIProvider().makeRequest(input(count: 4, ratio: .widescreen), apiKey: "test-key")
        let body = try json(request)
        XCTAssertEqual(request.url?.absoluteString, "https://api.openai.com/v1/images/generations")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-key")
        XCTAssertEqual(body["model"] as? String, "gpt-image-1")
        XCTAssertEqual(body["size"] as? String, "1536x1024")
        XCTAssertEqual(body["n"] as? Int, 4)
        XCTAssertEqual(body["output_format"] as? String, "png")
        XCTAssertNil(body["response_format"])
        XCTAssertNil(body["aspect_ratio"])
    }

    func testOpenAIEditContainsReferenceAndBoundary() throws {
        let bytes = Data([0, 1, 2, 255])
        let request = try OpenAIProvider().makeRequest(input(count: 2, reference: bytes), apiKey: "test-key")
        XCTAssertEqual(request.url?.path, "/v1/images/edits")
        let header = try XCTUnwrap(request.value(forHTTPHeaderField: "Content-Type"))
        let boundary = try XCTUnwrap(header.components(separatedBy: "boundary=").last)
        let body = try XCTUnwrap(request.httpBody)
        let text = String(decoding: body, as: UTF8.self)
        XCTAssertTrue(text.contains("name=\"image[]\"; filename=\"reference.png\""))
        XCTAssertTrue(text.contains("Content-Type: image/png\r\n\r\n"))
        XCTAssertTrue(text.contains("name=\"n\"\r\n\r\n2\r\n"))
        XCTAssertNotNil(body.range(of: bytes))
        XCTAssertTrue(text.hasSuffix("--\(boundary)--\r\n"))
    }

    func testXAIUsesAllRequestedRatios() throws {
        for ratio in AspectRatio.allCases {
            let request = try XAIProvider().makeRequest(input(.xAI, count: 3, ratio: ratio), apiKey: "test-key")
            let body = try json(request)
            XCTAssertEqual(request.url?.host, "api.x.ai")
            XCTAssertEqual(body["aspect_ratio"] as? String, ratio.rawValue)
            XCTAssertEqual(body["model"] as? String, "grok-imagine-image-2.0")
            XCTAssertEqual(body["n"] as? Int, 3)
            XCTAssertEqual(body["response_format"] as? String, "b64_json")
            XCTAssertNil(body["size"])
        }
    }

    func testXAIEditUsesJSONDataURI() throws {
        let bytes = Data([1, 2, 3])
        let request = try XAIProvider().makeRequest(input(.xAI, reference: bytes), apiKey: "test-key")
        let body = try json(request)
        let image = try XCTUnwrap(body["image"] as? [String: String])
        XCTAssertEqual(request.url?.path, "/v1/images/edits")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(image["type"], "image_url")
        XCTAssertEqual(image["url"], "data:image/png;base64,AQID")
    }

    func testOptionsCodableRoundTrip() throws {
        let options = input(.xAI, count: 4, ratio: .story).options
        XCTAssertEqual(try JSONDecoder().decode(GenerationOptions.self, from: JSONEncoder().encode(options)), options)
    }

    func testAspectSizeMapping() {
        XCTAssertEqual(AspectRatio.square.openAISize, "1024x1024")
        XCTAssertEqual(AspectRatio.landscape.openAISize, "1536x1024")
        XCTAssertEqual(AspectRatio.portrait.openAISize, "1024x1536")
        XCTAssertEqual(AspectRatio.story.value, 9.0 / 16)
    }

    func testProviderAuthenticationOptionsUseOfficialHTTPSPages() {
        XCTAssertEqual(ProviderID.openAI.authentication.subscriptionStatus, "API billing is separate")
        XCTAssertEqual(ProviderID.xAI.authentication.subscriptionStatus, "API key connects account")

        for provider in ProviderID.allCases {
            XCTAssertEqual(provider.authentication.subscriptionHelpURL.scheme, "https")
            XCTAssertEqual(provider.authentication.apiKeyURL.scheme, "https")
            XCTAssertEqual(provider.authentication.apiUsageURL.scheme, "https")
        }

        XCTAssertEqual(ProviderID.openAI.authentication.apiKeyURL.host, "platform.openai.com")
        XCTAssertEqual(ProviderID.xAI.authentication.apiKeyURL.host, "console.x.ai")
    }

    func testInvalidInputsRejected() {
        XCTAssertThrowsError(try ImageRequest(prompt: " \n ", options: input().options).validate())
        XCTAssertThrowsError(try input(count: 0).validate())
        XCTAssertThrowsError(try input(count: 5).validate())
        XCTAssertThrowsError(try input(reference: Data()).validate())
    }

    func testServiceRoutesOnlyToSelectedProvider() async throws {
        let openAI = RecordingProvider(), xAI = RecordingProvider()
        let service = ImageGenerationService(openAI: openAI, xAI: xAI)
        _ = try await service.generate(input(.xAI), apiKey: "test-key")
        let openCalls = await openAI.calls, xCalls = await xAI.calls
        XCTAssertEqual(openCalls, 0)
        XCTAssertEqual(xCalls, 1)
    }

    func testMissingKeyNeverCallsProvider() async {
        let provider = RecordingProvider()
        let service = ImageGenerationService(openAI: provider, xAI: provider)
        do {
            _ = try await service.generate(input(), apiKey: " \n")
            XCTFail("Expected credential failure")
        } catch {
            XCTAssertTrue(error is StudioError)
            XCTAssertEqual(error.localizedDescription, "Add an API key for this provider in Settings. Provider image APIs do not offer subscription OAuth to this app.")
        }
        let calls = await provider.calls
        XCTAssertEqual(calls, 0)
    }

    func testBothProvidersDecodeBase64() async throws {
        for provider in [ProviderID.openAI, .xAI] {
            let session = session(status: 200, body: #"{"data":[{"b64_json":"AQID"}]}"#)
            defer { session.invalidateAndCancel() }
            let service = ImageGenerationService(openAI: OpenAIProvider(session: session), xAI: XAIProvider(session: session))
            let result = try await service.generate(input(provider), apiKey: "test-key")
            XCTAssertEqual(result, [Data([1, 2, 3])])
        }
    }

    func testMalformedAndPartialResponsesFail() async {
        for body in ["not json", #"{"data":[]}"#, #"{"data":[{"b64_json":"!"}]}"#,
                     #"{"data":[{"b64_json":""}]}"#, #"{"data":[{"url":"https://example.com/image.png"}]}"#] {
            let session = session(status: 200, body: body)
            defer { session.invalidateAndCancel() }
            do {
                _ = try await OpenAIProvider(session: session).generate(input(), apiKey: "test-key")
                XCTFail("Expected invalid response")
            } catch { XCTAssertTrue(error is StudioError) }
        }
    }

    func testHTTPFailuresDoNotExposeProviderBody() async {
        for status in [400, 401, 403, 429, 500] {
            let session = session(status: status, body: "private-provider-body")
            defer { session.invalidateAndCancel() }
            do {
                _ = try await XAIProvider(session: session).generate(input(.xAI), apiKey: "test-key")
                XCTFail("Expected HTTP failure")
            } catch {
                guard case StudioError.http(let actual) = error else { return XCTFail("Expected HTTP error") }
                XCTAssertEqual(actual, status)
                XCTAssertFalse(error.localizedDescription.contains("private-provider-body"))
            }
        }
    }

    func testCancellationDoesNotReturnImages() async {
        let session = session(status: 200, body: #"{"data":[{"b64_json":"AQID"}]}"#)
        defer { session.invalidateAndCancel() }
        let request = input()
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await OpenAIProvider(session: session).generate(request, apiKey: "test-key")
        }
        do { _ = try await task.value; XCTFail("Expected cancellation") }
        catch { XCTAssertTrue(error is CancellationError || (error as? URLError)?.code == .cancelled) }
    }

    private func session(status: Int, body: String) -> URLSession {
        MockURLProtocol.response = (status, Data(body.utf8))
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

private actor RecordingProvider: ImageGenerationProvider {
    var calls = 0
    func generate(_ request: ImageRequest, apiKey: String) async throws -> [Data] {
        calls += 1
        return [Data([1])]
    }
}

// XCTest runs this test case serially. The mock never reaches the network.
private final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    static var response = (200, Data())
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let (status, data) = Self.response
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
