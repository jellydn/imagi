# Testing Patterns

**Analysis Date:** 2026-09-05

## Test Framework

**Runner:**
- XCTest through Swift Package Manager for `Tests/StudioCoreTests/ProviderTests.swift`, and XCTest through an Xcode unit-test target for `NativeTests/LocalLibraryTests.swift`.
- Config: `Package.swift` defines `StudioCoreTests`; `project.yml` defines the macOS `ImageStudio-NativeTests` target and scheme.

**Assertion Library:**
- XCTest assertions: `XCTAssertEqual`, `XCTAssertTrue`, `XCTAssertFalse`, `XCTAssertNil`, `XCTAssertNotNil`, `XCTAssertLessThanOrEqual`, `XCTAssertThrowsError`, `XCTFail`, and `XCTUnwrap`.

**Run Commands:**
```bash
swift test -Xswiftc -warnings-as-errors
xcodegen generate && xcodebuild test -project ImageStudio.xcodeproj -scheme ImageStudio-NativeTests -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
```
- The shared-package command previously passed 13 tests. The Apple command was not run here. No watch-mode or coverage command is configured.

## Test File Organization

**Location:**
- Shared, Linux-compatible package tests are separate under `Tests/StudioCoreTests/`.
- Tests requiring Apple frameworks are separate under `NativeTests/` and compile with selected app model and storage sources through `project.yml`.

**Naming:**
- Test files and XCTestCase classes end in `Tests`. Individual test methods start with `test` and state the expected behavior.

**Structure:**
```text
Tests/StudioCoreTests/ProviderTests.swift  # Request building, service routing, decoding, errors, cancellation
NativeTests/LocalLibraryTests.swift        # SwiftData persistence and ImageStore filesystem/image behavior
```

## Test Structure

**Suite Organization:**
```swift
final class ProviderTests: XCTestCase {
    func testServiceRoutesOnlyToSelectedProvider() async throws {
        let openAI = RecordingProvider(), xAI = RecordingProvider()
        let service = ImageGenerationService(openAI: openAI, xAI: xAI)
        _ = try await service.generate(input(.xAI), apiKey: "test-key")
        let openCalls = await openAI.calls, xCalls = await xAI.calls
        XCTAssertEqual(openCalls, 0)
        XCTAssertEqual(xCalls, 1)
    }
}
```

**Patterns:**
- Tests create state locally inside each method. Repeated request, JSON, URLSession, and PNG setup is extracted into private helper methods in the same file.
- Cleanup uses `defer`, including `URLSession.invalidateAndCancel()` in `Tests/StudioCoreTests/ProviderTests.swift` and temporary-directory removal in `NativeTests/LocalLibraryTests.swift`.
- Assertions inspect exact request URLs, headers, JSON or multipart fields, persisted relationships, image dimensions, file counts, and typed errors.

## Mocking

**Framework:** Hand-written protocol fakes and `URLProtocol`; no external mocking library

**Patterns:**
```swift
private actor RecordingProvider: ImageGenerationProvider {
    var calls = 0
    func generate(_ request: ImageRequest, apiKey: String) async throws -> [Data] {
        calls += 1
        return [Data([1])]
    }
}

private final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    static var response = (200, Data())
    override class func canInit(with request: URLRequest) -> Bool { true }
    // Delivers the configured status and bytes without network access.
}
```

**What to Mock:**
- Provider routing uses injected `ImageGenerationProvider` actors to count calls.
- HTTP response handling uses an ephemeral `URLSession` whose `protocolClasses` contains `MockURLProtocol`, so package tests do not reach live providers.
- `MockURLProtocol.response` is mutable static state in `Tests/StudioCoreTests/ProviderTests.swift`. The suite assumes serial execution; parallel tests in the same process would need isolated response fixtures.
- SwiftData tests use an in-memory `ModelContainer`; image-storage tests use a unique temporary directory.

**What NOT to Mock:**
- Request serialization, response decoding, cancellation checks, SwiftData relationships, PNG encoding/cropping, thumbnails, and filesystem cleanup are exercised with their real implementations.
- Keychain, Photos, notifications, rendered SwiftUI, and live providers are not mocked or covered by the current tests.

## Fixtures and Factories

**Test Data:**
```swift
private func input(
    _ provider: ProviderID = .openAI,
    count: Int = 1,
    ratio: AspectRatio = .square,
    reference: Data? = nil
) -> ImageRequest {
    ImageRequest(prompt: "A tiny astronaut in Singapore",
                 options: .init(provider: provider, count: count, ratio: ratio),
                 referencePNG: reference)
}
```

**Location:**
- Fixtures are private helpers and inline values in each test file. `Tests/StudioCoreTests/ProviderTests.swift` builds requests and mock sessions; `NativeTests/LocalLibraryTests.swift` creates valid PNG bytes with Core Graphics. There is no shared fixture directory.

## Coverage

**Requirements:** None enforced; no coverage threshold or coverage configuration was found in `Package.swift` or `project.yml`.

**View Coverage:**
```bash
Not configured
```

## Test Types

**Unit Tests:**
- `Tests/StudioCoreTests/ProviderTests.swift` covers OpenAI and xAI request shape, generation versus edit formats, aspect-ratio mapping, Codable round trips, invalid inputs, missing credentials, provider selection, base64 decoding, malformed/partial responses, HTTP error privacy, and cancellation.
- `NativeTests/LocalLibraryTests.swift` covers persistence reloads, favorites and refinement links, deletion semantics, PNG cropping, thumbnail sizing, storage removal, and failed-batch cleanup.

**Integration Tests:**
- The native suite integrates real SwiftData models with an in-memory container and real ImageIO/Core Graphics/filesystem behavior in a temporary directory.
- URL loading is integrated through a real ephemeral `URLSession`, but `MockURLProtocol` supplies responses. No paid or external network call is made.

**E2E Tests:**
- Not used. No XCUITest target, snapshot tests, or UI automation was found in `project.yml`.

## Common Patterns

**Async Testing:**
```swift
func testBothProvidersDecodeBase64() async throws {
    let service = ImageGenerationService(openAI: OpenAIProvider(session: session),
                                         xAI: XAIProvider(session: session))
    let result = try await service.generate(input(provider), apiKey: "test-key")
    XCTAssertEqual(result, [Data([1, 2, 3])])
}
```

**Error Testing:**
```swift
do {
    _ = try await service.generate(input(), apiKey: " \n")
    XCTFail("Expected credential failure")
} catch {
    XCTAssertTrue(error is StudioError)
}
```

- The shared `swift test -Xswiftc -warnings-as-errors` run was previously reported as passing 13 tests; it was not rerun for this documentation task.
- Apple tests and app builds were not run. Actual UI behavior, Keychain, Photos, notifications, and live OpenAI/xAI provider behavior remain unverified here.
- Current gaps include direct tests for `App/StudioModel.swift` state transitions and rollback paths, `App/CredentialStore.swift`, `App/NativeActions.swift`, SwiftUI views, search and settings behavior, accessibility, persistence-open failure, background expiration, and real provider compatibility.

---

*Testing analysis: 2026-09-05*
