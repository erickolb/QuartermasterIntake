import XCTest
@testable import QMIntake

final class IntakeTests: XCTestCase {
    func testAuthenticatedPhotoUploadAndRevocation() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubProtocol.self]
        let connection = Connection(origin: "https://inventory.invalid", device: "test-phone", secret: "test-secret")
        let api = API(connection, configuration: configuration)
        let photo = try await api.request("/photos", body: Data([1, 2, 3]), type: "image/jpeg")
        XCTAssertEqual(try JSONDecoder().decode(PhotoResponse.self, from: photo).id, "test-photo")
        do {
            _ = try await api.request("/health")
            XCTFail("Revoked devices must fail.")
        } catch { XCTAssertEqual(error.localizedDescription, "Device revoked") }
    }
    func testOriginRejectsCredentialLeakTargets() throws {
        XCTAssertEqual(try Input.origin(" https://example.com/ "), "https://example.com")
        for value in ["http://example.com", "https://user:pass@example.com", "https://example.com/v1", "https://example.com?x=1", "https://example.com#fragment"] {
            XCTAssertThrowsError(try Input.origin(value))
        }
    }
    func testQuantityAndTags() throws {
        XCTAssertEqual(try Input.quantity("0", consumable: true), 0)
        XCTAssertThrowsError(try Input.quantity("0", consumable: false))
        XCTAssertThrowsError(try Input.quantity("1000001", consumable: true))
        XCTAssertThrowsError(try Input.quantity("-1", consumable: true))
        XCTAssertEqual(try Input.tags(" tools, Tools, camping, "), ["tools", "camping"])
        XCTAssertThrowsError(try Input.tags(String(repeating: "x", count: 61)))
    }
    func testDraftRecoveryPreservesUncertainSubmission() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try DraftStore(directory: directory)
        var draft = Draft(); draft.description = "Tent"; draft.locationID = 4; draft.uncertain = true
        draft.origin = "https://example.com"; draft.device = "phone"; draft.notes = "Keep dry\nTop shelf"
        try store.save(draft)
        XCTAssertEqual(try store.load(), draft)
        let body = try JSONSerialization.jsonObject(with: draft.body(photoID: "photo")) as! [String: Any]
        XCTAssertEqual(body["notes"] as? String, draft.notes)
        XCTAssertEqual(body["location_id"] as? Int, 4)
        XCTAssertEqual(body["photo_id"] as? String, "photo")
        try store.clear(); XCTAssertNil(try store.load())
    }
    func testRequiredFields() {
        XCTAssertThrowsError(try Draft().body(photoID: "photo"))
        var draft = Draft(); draft.description = "Tent"
        XCTAssertThrowsError(try draft.body(photoID: "photo"))
        draft.locationID = 1; draft.notes = String(repeating: "x", count: 10_001)
        XCTAssertThrowsError(try draft.body(photoID: "photo"))
    }
}

final class StubProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Device-Id"), "test-phone")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-secret")
        XCTAssertEqual(request.url?.scheme, "https")
        let upload = request.url?.path == "/v1/photos"
        if upload {
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "image/jpeg")
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: upload ? 201 : 401, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data((upload ? "{\"id\":\"test-photo\"}" : "{\"error\":\"Device revoked\"}").utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
