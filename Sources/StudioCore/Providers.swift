import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct OpenAIProvider: ImageGenerationProvider {
    private let session: URLSession
    public init(session: URLSession = .shared) { self.session = session }

    public func makeRequest(_ input: ImageRequest, apiKey: String) throws -> URLRequest {
        try input.validate()
        let editing = input.referencePNG != nil
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/images/\(editing ? "edits" : "generations")")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 300
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let fields = [
            "model": ProviderID.openAI.model, "prompt": input.prompt,
            "size": input.options.ratio.openAISize, "output_format": "png"
        ]
        if let reference = input.referencePNG {
            let boundary = "Studio-\(UUID().uuidString)"
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            var body = Data()
            for (key, value) in (fields.merging(["n": String(input.options.count)]) { _, new in new }).sorted(by: { $0.key < $1.key }) {
                body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(key)\"\r\n\r\n\(value)\r\n".utf8))
            }
            body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"image[]\"; filename=\"reference.png\"\r\nContent-Type: image/png\r\n\r\n".utf8))
            body.append(reference)
            body.append(Data("\r\n--\(boundary)--\r\n".utf8))
            request.httpBody = body
        } else {
            var json: [String: Any] = fields
            json["n"] = input.options.count
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: json)
        }
        return request
    }

    public func generate(_ request: ImageRequest, apiKey: String) async throws -> [Data] {
        try await imageResponse(session: session, request: makeRequest(request, apiKey: apiKey), count: request.options.count)
    }
}

public struct XAIProvider: ImageGenerationProvider {
    private let session: URLSession
    public init(session: URLSession = .shared) { self.session = session }

    public func makeRequest(_ input: ImageRequest, apiKey: String) throws -> URLRequest {
        try input.validate()
        var request = URLRequest(url: URL(string: "https://api.x.ai/v1/images/\(input.referencePNG == nil ? "generations" : "edits")")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 300
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var json: [String: Any] = [
            "model": ProviderID.xAI.model, "prompt": input.prompt,
            "n": input.options.count, "aspect_ratio": input.options.ratio.rawValue,
            "response_format": "b64_json"
        ]
        if let reference = input.referencePNG {
            json["image"] = ["type": "image_url", "url": "data:image/png;base64,\(reference.base64EncodedString())"]
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: json)
        return request
    }

    public func generate(_ request: ImageRequest, apiKey: String) async throws -> [Data] {
        try await imageResponse(session: session, request: makeRequest(request, apiKey: apiKey), count: request.options.count)
    }
}

private struct ImageResponse: Decodable {
    struct Item: Decodable { let b64_json: String? }
    let data: [Item]
}

private func imageResponse(session: URLSession, request: URLRequest, count: Int) async throws -> [Data] {
    let (data, response) = try await session.data(for: request)
    try Task.checkCancellation()
    guard let http = response as? HTTPURLResponse else { throw StudioError.invalidResponse }
    guard (200...299).contains(http.statusCode) else { throw StudioError.http(http.statusCode) }
    // Do not surface raw provider bodies: they can contain prompts or other private data.
    guard let result = try? JSONDecoder().decode(ImageResponse.self, from: data), result.data.count == count else {
        throw StudioError.invalidResponse
    }
    return try result.data.map {
        guard let base64 = $0.b64_json, let bytes = Data(base64Encoded: base64), !bytes.isEmpty else {
            throw StudioError.invalidResponse
        }
        return bytes
    }
}
