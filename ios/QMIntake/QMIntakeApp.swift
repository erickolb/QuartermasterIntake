import SwiftUI
import UIKit
import AVFoundation

@main
struct QMIntakeApp: App {
    var body: some Scene { WindowGroup { IntakeView() } }
}

@MainActor
final class IntakeModel: ObservableObject {
    @Published var connection: Connection?
    @Published var draft = Draft()
    @Published var photo: UIImage?
    @Published var locations: [Location] = []
    @Published var tags: [String] = []
    @Published var busy = false
    @Published var message = ""
    @Published var screen = "home"
    private var storage: DraftStore?
    init() {
        do {
            connection = try CredentialStore.load()
            let store = try DraftStore(); storage = store
            if let saved = try store.load() {
                draft = saved
                photo = UIImage(contentsOfFile: store.photoURL.path)
                screen = "review"
                if photo == nil { message = "The saved draft photo is unavailable. Discard the draft to start again." }
            }
            if connection == nil { screen = "settings" }
        } catch { message = error.localizedDescription }
    }
    func persist() -> Bool {
        do {
            guard let storage else { throw IntakeError(message: "Draft storage is unavailable. Restart the app and try again.") }
            try storage.save(draft); return true
        } catch { message = error.localizedDescription; return false }
    }
    func clear() {
        do {
            try storage?.clear(); draft = Draft(); photo = nil; screen = "home"
        } catch { message = error.localizedDescription }
    }
    func capture(_ image: UIImage) {
        do {
            guard let storage, let connection else { throw IntakeError(message: "Configure the connection first.") }
            let scale = min(1, 1600 / max(image.size.width, image.size.height))
            let size = CGSize(width: max(1, image.size.width * scale), height: max(1, image.size.height * scale))
            let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
            let normalized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
                UIColor.white.setFill(); UIRectFill(CGRect(origin: .zero, size: size))
                image.draw(in: CGRect(origin: .zero, size: size))
            }
            guard let bytes = normalized.jpegData(compressionQuality: 0.88), bytes.count <= 10_000_000 else {
                throw IntakeError(message: "Photo is too large. Please retake it.")
            }
            try bytes.write(to: storage.photoURL, options: [.atomic, .completeFileProtection])
            draft.origin = connection.origin; draft.device = connection.device; draft.stage = "review"
            guard persist() else { return }
            photo = normalized; screen = "review"; message = ""
        } catch { message = error.localizedDescription }
    }
    func perform(_ operation: @escaping () async throws -> Void) {
        guard !busy else { return }; busy = true; message = ""
        Task { defer { busy = false }; do { try await operation() } catch { message = error.localizedDescription } }
    }
    func loadForm() {
        perform {
            guard let connection = self.connection else { return }
            guard self.draft.origin == connection.origin, self.draft.device == connection.device else {
                throw IntakeError(message: "This draft belongs to a different server or device. Restore its connection or discard it.")
            }
            let api = API(connection)
            let locations: [Location] = try await api.get("/locations")
            let tags: [Tag] = try await api.get("/tags")
            self.locations = locations; self.tags = tags.map(\.name)
            self.draft.stage = "form"; self.screen = "form"; _ = self.persist()
        }
    }
    func submit() {
        guard !draft.uncertain, let connection, let storage else { return }
        perform {
            guard self.draft.origin == connection.origin, self.draft.device == connection.device,
                  self.locations.contains(where: { $0.id == self.draft.locationID }) else {
                throw IntakeError(message: "Reload the locations and verify this draft's connection.")
            }
            _ = try self.draft.body(photoID: "validation")
            guard self.persist() else { return }
            let bytes = try Data(contentsOf: storage.photoURL)
            let api = API(connection)
            let uploaded = try await api.request("/photos", body: bytes, type: "image/jpeg")
            let photoID = try JSONDecoder().decode(PhotoResponse.self, from: uploaded).id
            let body = try self.draft.body(photoID: photoID)
            // Persist before POST. A crash or lost response must never enable an automatic retry.
            self.draft.uncertain = true
            guard self.persist() else { return }
            let response = try await api.request("/items", body: body)
            let item = try JSONDecoder().decode(ItemResponse.self, from: response)
            self.clear(); self.message = "Created \(item.identifier)."
        }
    }
}

struct IntakeView: View {
    @StateObject private var model = IntakeModel()
    @State private var camera = false
    @State private var discard = false
    @State private var about = false
    @Environment(\.scenePhase) private var scenePhase
    private let plum = Color(red: 103/255, green: 59/255, blue: 97/255)
    var body: some View {
        NavigationStack {
            Group {
                switch model.screen {
                case "settings": SettingsView(model: model)
                case "review": review
                case "form": form
                default: home
                }
            }
            .navigationTitle(model.screen == "settings" ? "Connection" : "QM Intake")
            .disabled(model.busy)
            .safeAreaInset(edge: .bottom) {
                VStack {
                    if model.busy { ProgressView("Working…") }
                    if !model.message.isEmpty { Text(model.message).font(.callout).padding() }
                }.frame(maxWidth: .infinity).background(.regularMaterial)
            }
        }
        .tint(plum)
        .fullScreenCover(isPresented: $camera) { CameraView { image in camera = false; if let image { model.capture(image) } } }
        .confirmationDialog(model.draft.uncertain ? "A submitted item may already exist. Discard the local draft?" : "Discard this draft?", isPresented: $discard, titleVisibility: .visible) {
            Button("Discard draft", role: .destructive) { model.clear() }
        }
        .sheet(isPresented: $about) {
            NavigationStack {
                Form {
                    Text("QM Intake for iOS · 0.2.0")
                    Link("Hiking icons created by max.icons — Flaticon", destination: URL(string: "https://www.flaticon.com/free-icons/hiking")!)
                }.navigationTitle("About").toolbar { Button("Done") { about = false } }
            }
        }
        .onChange(of: model.draft) { _, _ in if model.photo != nil { _ = model.persist() } }
        .onChange(of: scenePhase) { _, phase in if phase != .active && model.photo != nil { _ = model.persist() } }
        .onChange(of: model.message) { _, message in
            if !message.isEmpty { UIAccessibility.post(notification: .announcement, argument: message) }
        }
    }
    private var home: some View {
        Form {
            Section {
                Image("Backpack").resizable().scaledToFit().frame(height: 90).frame(maxWidth: .infinity).padding()
                Text("Create inventory entries from camera photos. Visit Quartermaster for browsing and other inventory tasks.")
                if let connection = model.connection, let url = URL(string: connection.origin) { Link("Open Quartermaster", destination: url) }
            }
            Section {
                Button("Create Item", systemImage: "camera") { openCamera() }
                if model.photo != nil || !model.draft.origin.isEmpty { Button("Resume draft") { model.screen = "review" } }
                Button("Settings", systemImage: "gearshape") { model.screen = "settings" }
                Button("About", systemImage: "info.circle") { about = true }
            }
        }
    }
    private var preview: some View {
        Group { if let photo = model.photo { Image(uiImage: photo).resizable().scaledToFit().frame(maxHeight: 300).accessibilityLabel("Item photo") } }
    }
    private var review: some View {
        Form {
            Section("Review photo") { preview }
            Section {
                Button("Use photo") { model.loadForm() }.disabled(model.photo == nil)
                Button("Retake") { openCamera() }.disabled(model.draft.uncertain)
                Button("Discard draft", role: .destructive) { discard = true }
            }
            if model.draft.uncertain { reconciliation }
        }
    }
    private var form: some View {
        Form {
            Section { preview }
            Section("Item details") {
                TextField("Description", text: $model.draft.description, axis: .vertical)
                TextField("Notes (optional)", text: $model.draft.notes, axis: .vertical).lineLimit(3...8)
                TextField("Quantity", text: $model.draft.quantity).keyboardType(.numberPad)
                Toggle("Consumable", isOn: $model.draft.consumable)
                Text("Consumables may have zero quantity.").font(.caption).foregroundStyle(.secondary)
                Picker("Location", selection: $model.draft.locationID) {
                    Text("Choose a location").tag(nil as Int?)
                    ForEach(model.locations) { Text($0.path).tag(Optional($0.id)) }
                }
                TextField("Tags, separated with commas", text: $model.draft.tags).textInputAutocapitalization(.never)
                ForEach(suggestedTags.prefix(8), id: \.self) { tag in
                    Button(tag, systemImage: "plus.circle") { appendTag(tag) }
                }
            }.disabled(model.draft.uncertain)
            if model.draft.uncertain { reconciliation }
            else { Section { Button("Submit Item", systemImage: "tray.and.arrow.up") { model.submit() } } }
            Section { Button("Discard draft", role: .destructive) { discard = true } }
        }
    }
    private var reconciliation: some View {
        Section("Check inventory before continuing") {
            Text("The submission outcome is unknown. Check Quartermaster to avoid creating a duplicate.")
            if let url = URL(string: model.draft.origin) { Link("Open inventory", destination: url) }
            Button("I checked — item was created") { model.clear() }
            Button("I checked — item is missing") { model.draft.uncertain = false; _ = model.persist() }
        }
    }
    private var suggestedTags: [String] {
        let current = model.draft.tags.components(separatedBy: ",").last?.trimmingCharacters(in: .whitespaces).lowercased() ?? ""
        let selected = (try? Input.tags(model.draft.tags)) ?? []
        return model.tags.filter { !selected.contains($0) && (current.isEmpty || $0.lowercased().contains(current)) }
    }
    private func appendTag(_ tag: String) {
        var parts = model.draft.tags.components(separatedBy: ",")
        if parts.last?.trimmingCharacters(in: .whitespaces).isEmpty == false { parts.removeLast() }
        else if parts.last != nil { parts.removeLast() }
        parts.append(tag); model.draft.tags = parts.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.joined(separator: ", ") + ", "
    }
    private func openCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else { model.message = "A camera is unavailable on this device."; return }
        guard model.photo == nil || model.screen == "review" else { model.screen = "review"; return }
        Task {
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if granted { camera = true }
            else { model.message = "Allow camera access for QM Intake in iOS Settings." }
        }
    }
}

struct SettingsView: View {
    @ObservedObject var model: IntakeModel
    @State private var origin = "https://quartermaster.chateaulore.net"
    @State private var device = ""
    @State private var secret = ""
    var body: some View {
        Form {
            Section("Device registration") {
                TextField("HTTPS server", text: $origin).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                TextField("Device ID", text: $device).textInputAutocapitalization(.never).autocorrectionDisabled()
                SecureField("Device secret", text: $secret).textInputAutocapitalization(.never).autocorrectionDisabled()
                Text("Enter the credentials issued privately for this phone. Leave the secret blank to retain the saved credential for the same server and device.").font(.caption)
            }
            Section {
                Button("Save and test connection") {
                    model.perform {
                        let normalized = try Input.origin(origin)
                        let deviceID = device.trimmingCharacters(in: .whitespacesAndNewlines)
                        let previous = model.connection
                        let token = secret.isEmpty && previous?.origin == normalized && previous?.device == deviceID ? previous?.secret ?? "" : secret
                        guard !deviceID.isEmpty, !token.isEmpty else { throw IntakeError(message: "Device ID and secret are required.") }
                        let next = Connection(origin: normalized, device: deviceID, secret: token)
                        _ = try await API(next).request("/health")
                        try CredentialStore.save(next); model.connection = next; secret = ""
                        model.screen = model.photo == nil ? "home" : "review"; model.message = "Connected to Quartermaster."
                    }
                }
                if model.connection != nil { Button("Back") { model.screen = model.photo == nil ? "home" : "review" } }
            }
        }.onAppear { origin = model.connection?.origin ?? origin; device = model.connection?.device ?? "" }
    }
}

struct CameraView: UIViewControllerRepresentable {
    let completion: (UIImage?) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(completion) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController(); picker.sourceType = .camera; picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator; return picker
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let completion: (UIImage?) -> Void
        init(_ completion: @escaping (UIImage?) -> Void) { self.completion = completion }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { completion(nil) }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) { completion(info[.originalImage] as? UIImage) }
    }
}
