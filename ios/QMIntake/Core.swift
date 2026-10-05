import Foundation
import Security

struct IntakeError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

struct Connection: Codable, Equatable {
    var origin: String
    var device: String
    var secret: String
}

enum Input {
    static func origin(_ raw: String) throws -> String {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let parts = URLComponents(string: text), parts.scheme == "https",
              let host = parts.host, !host.isEmpty, parts.user == nil, parts.password == nil,
              parts.query == nil, parts.fragment == nil, parts.path.isEmpty || parts.path == "/",
              parts.url != nil else { throw IntakeError(message: "Use an HTTPS server address without a path.") }
        return text.hasSuffix("/") ? String(text.dropLast()) : text
    }
    static func quantity(_ text: String, consumable: Bool) throws -> Int {
        guard !text.isEmpty, text.allSatisfy({ $0.isASCII && $0.isNumber }),
              let value = Int(text), value >= (consumable ? 0 : 1), value <= 1_000_000 else {
            throw IntakeError(message: consumable ? "Enter a quantity from 0 to 1,000,000." : "Enter a quantity from 1 to 1,000,000. Zero requires Consumable.")
        }
        return value
    }
    static func tags(_ text: String) throws -> [String] {
        var seen = Set<String>()
        let tags = text.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
        guard tags.count <= 20, tags.allSatisfy({ $0.utf16.count <= 60 }) else {
            throw IntakeError(message: "Use up to 20 tags, each up to 60 characters.")
        }
        return tags
    }
}

enum CredentialStore {
    static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: Bundle.main.bundleIdentifier ?? "net.chateaulore.quartermaster.intake",
         kSecAttrAccount as String: "connection"]
    }
    static func load() throws -> Connection? {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw IntakeError(message: "Unable to unlock the saved connection. Unlock your phone and try again.")
        }
        return try JSONDecoder().decode(Connection.self, from: data)
    }
    static func save(_ connection: Connection) throws {
        let attributes: [String: Any] = [kSecValueData as String: try JSONEncoder().encode(connection),
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            status = SecItemAdd(query.merging(attributes) { _, new in new } as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw IntakeError(message: "Could not save the device credential securely.") }
    }
}

struct Location: Decodable, Identifiable { let id: Int; let name: String; let path: String }
struct Tag: Decodable { let name: String }
struct PhotoResponse: Decodable { let id: String }
struct ItemResponse: Decodable { let identifier: String }
struct APIError: Decodable { let error: String }

final class NoRedirects: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}

final class API {
    let connection: Connection
    private let session: URLSession
    init(_ connection: Connection, configuration: URLSessionConfiguration = .ephemeral) {
        self.connection = connection
        let config = configuration
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 90
        config.httpCookieStorage = nil
        config.urlCache = nil
        session = URLSession(configuration: config, delegate: NoRedirects(), delegateQueue: nil)
    }
    deinit { session.invalidateAndCancel() }
    func request(_ path: String, body: Data? = nil, type: String = "application/json") async throws -> Data {
        let origin = try Input.origin(connection.origin)
        guard let url = URL(string: origin + "/v1" + path) else { throw IntakeError(message: "Invalid server address.") }
        var request = URLRequest(url: url)
        request.setValue(connection.device, forHTTPHeaderField: "X-Device-Id")
        request.setValue("Bearer " + connection.secret, forHTTPHeaderField: "Authorization")
        if let body { request.httpMethod = "POST"; request.httpBody = body; request.setValue(type, forHTTPHeaderField: "Content-Type") }
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw IntakeError(message: "Invalid server response.") }
        guard (200..<300).contains(response.statusCode) else {
            let message = (try? JSONDecoder().decode(APIError.self, from: data).error)
                ?? "Server returned HTTP \(response.statusCode). Check your connection and device registration."
            throw IntakeError(message: message)
        }
        return data
    }
    func get<T: Decodable>(_ path: String) async throws -> T { try JSONDecoder().decode(T.self, from: await request(path)) }
}

struct Draft: Codable, Equatable {
    var description = ""
    var notes = ""
    var quantity = "1"
    var consumable = false
    var tags = ""
    var locationID: Int?
    var uncertain = false
    // Bind a recovered draft to its original server and device; never store the secret here.
    var origin = ""
    var device = ""
    var stage = "review"
    func body(photoID: String) throws -> Data {
        let description = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !description.isEmpty, description.utf16.count <= 2000 else { throw IntakeError(message: "Enter a description of 1–2,000 characters.") }
        guard notes.utf16.count <= 10_000 else { throw IntakeError(message: "Notes must be at most 10,000 characters.") }
        guard let locationID, locationID > 0 else { throw IntakeError(message: "Choose a location.") }
        return try JSONSerialization.data(withJSONObject: ["description": description, "notes": notes,
            "quantity": Input.quantity(quantity, consumable: consumable), "consumable": consumable,
            "tags": Input.tags(tags), "location_id": locationID, "photo_id": photoID])
    }
}

struct DraftStore {
    let directory: URL
    init(directory: URL? = nil) throws {
        self.directory = try directory ?? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("IntakeDraft")
        try FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
        var folder = self.directory
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        try folder.setResourceValues(values)
    }
    var photoURL: URL { directory.appendingPathComponent("photo.jpg") }
    var draftURL: URL { directory.appendingPathComponent("draft.json") }
    func save(_ draft: Draft) throws { try JSONEncoder().encode(draft).write(to: draftURL, options: [.atomic, .completeFileProtection]) }
    func load() throws -> Draft? {
        guard FileManager.default.fileExists(atPath: draftURL.path) else { return nil }
        return try JSONDecoder().decode(Draft.self, from: Data(contentsOf: draftURL))
    }
    func clear() throws {
        for url in [draftURL, photoURL] where FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }
}
