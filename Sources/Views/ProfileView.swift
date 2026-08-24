import SwiftUI

/// Bring your own key. The app talks to the API from the device, so the key
/// belongs to whoever is holding it — this is where they put it, replace it, or
/// take it back out.
///
/// Saving verifies by asking for a real (tiny) myth, because the alternative is
/// what this screen exists to end: a key that looks accepted and then produces
/// "The Unnamed" for reasons nobody can see.
struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var typed = ""
    @State private var status = Status.idle
    /// Re-read after every change so the summary is never stale.
    @State private var source = Namer.source

    enum Status: Equatable {
        case idle
        case checking
        /// Carries the name it came back with — proof it really worked.
        case ok(String)
        case failed(String)
    }

    var body: some View {
        NavigationStack {
            Form {
                keySection
                if source != .none { installedSection }
                aboutSection
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(
                LinearGradient(colors: [Palette.nightTop, Palette.nightBottom],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            )
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Entering a key

    private var keySection: some View {
        Section {
            SecureField("sk-ant-…", text: $typed)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(size: 15, design: .monospaced))
                .accessibilityLabel("Anthropic API key")

            Button {
                Task { await saveAndVerify() }
            } label: {
                HStack(spacing: 8) {
                    if status == .checking {
                        ProgressView().controlSize(.small)
                    }
                    Text(status == .checking ? "Checking…" : "Save and check")
                        .font(.system(size: 15, weight: .semibold))
                }
            }
            .disabled(typed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                      || status == .checking)

            if let message = statusMessage {
                Label {
                    Text(message)
                        .font(.system(size: 13))
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: statusIcon)
                }
                .foregroundStyle(statusColour)
                .accessibilityLabel(message)
            }
        } header: {
            Text("Your key")
        } footer: {
            Text("Paste a key from console.anthropic.com. Checking it asks for one short myth, "
                 + "so it costs a few tokens.")
        }
        .listRowBackground(Color.white.opacity(0.05))
    }

    private var statusMessage: String? {
        switch status {
        case .idle, .checking: return nil
        case .ok(let name): return "Working — it named a test constellation \u{201C}\(name)\u{201D}."
        case .failed(let why): return why
        }
    }

    private var statusIcon: String {
        if case .ok = status { return "checkmark.circle.fill" }
        return "exclamationmark.triangle.fill"
    }

    private var statusColour: Color {
        if case .ok = status { return Palette.aqua }
        return Palette.rose
    }

    private func saveAndVerify() async {
        let candidate = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty else { return }
        status = .checking

        // Checked before storing, so a rejected key never displaces a good one.
        switch await Namer.verify(candidate) {
        case .success(let myth):
            do {
                try KeyStore.save(candidate)
                typed = ""
                source = Namer.source
                status = .ok(myth.name)
            } catch {
                status = .failed("The key works, but saving it failed: \(error.localizedDescription)")
            }
        case .failure(let error):
            status = .failed(Namer.describe(error))
        }
    }

    // MARK: - The key already here

    private var installedSection: some View {
        Section {
            HStack {
                Text(source == .keychain ? "Saved on this device" : "Built into this copy")
                    .font(.system(size: 15))
                Spacer()
                Text(Namer.apiKey.map(KeyStore.fingerprint) ?? "")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(Palette.ink.opacity(0.55))
            }
            .accessibilityElement(children: .combine)

            if source == .keychain {
                Button("Remove this key", role: .destructive) { remove() }
                    .font(.system(size: 15))
            }
        } header: {
            Text("In use")
        } footer: {
            // Worth saying plainly: pulling the saved key can reveal a build-time
            // one underneath rather than leaving naming switched off.
            Text(source == .keychain
                 ? "Removing it falls back to a key built into this copy, if there is one."
                 : "Comes from Config/Secrets.xcconfig at build time. Saving a key above "
                   + "overrides it.")
        }
        .listRowBackground(Color.white.opacity(0.05))
    }

    private func remove() {
        do {
            try KeyStore.remove()
            source = Namer.source
            status = .idle
        } catch {
            status = .failed("Could not remove the key: \(error.localizedDescription)")
        }
    }

    // MARK: - What happens to it

    private var aboutSection: some View {
        Section {
            Text("Your key is kept in the device Keychain and sent only to Anthropic, straight "
                 + "from this device. It is never written to the sky log or a shared "
                 + "constellation.")
                .font(.system(size: 13))
                .foregroundStyle(Palette.ink.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)

            Text("Without a key, \u{201C}Name it\u{201D} still works — it just tells you the sky "
                 + "kept its story to itself.")
                .font(.system(size: 13))
                .foregroundStyle(Palette.ink.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
        } header: {
            Text("Where it goes")
        }
        .listRowBackground(Color.white.opacity(0.05))
    }
}

#Preview {
    ProfileView()
}
