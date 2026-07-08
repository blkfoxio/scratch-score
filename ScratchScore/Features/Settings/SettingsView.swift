import SwiftUI

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var env
    let userId: UUID

    @State private var showingDeleteConfirm = false
    @State private var deleteConfirmText = ""
    @State private var isDeleting = false
    @State private var deleteError: String?

    private var accountEmail: String? {
        if case let .signedIn(_, email, _) = env.auth.state { return email }
        return nil
    }
    private var accountName: String? {
        if case let .signedIn(_, _, name) = env.auth.state { return name }
        return nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    if let accountName, !accountName.isEmpty {
                        LabeledContent("Name", value: accountName)
                    }
                    LabeledContent("Email", value: accountEmail ?? "—")
                }

                Section("Sync") {
                    LabeledContent("Status") { syncStatusView }
                    Button {
                        Task { await env.sync.syncNow(userId: userId) }
                    } label: { Label("Sync now", systemImage: "arrow.triangle.2.circlepath") }
                }

                Section("About") {
                    Link(destination: LegalLinks.privacy) { Label("Privacy Policy", systemImage: "hand.raised") }
                    Link(destination: LegalLinks.terms) { Label("Terms of Service", systemImage: "doc.text") }
                    Link(destination: LegalLinks.support) { Label("Support", systemImage: "questionmark.circle") }
                    LabeledContent("Version", value: appVersion)
                }

                Section {
                    Button(role: .destructive) {
                        Task { await env.auth.signOut() }
                    } label: { Text("Sign Out") }
                }

                Section {
                    Button(role: .destructive) {
                        deleteConfirmText = ""
                        deleteError = nil
                        showingDeleteConfirm = true
                    } label: { Text("Delete Account") }
                } footer: {
                    Text("Permanently deletes your account and all rounds, courses, and stats. This cannot be undone.")
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingDeleteConfirm) {
                DeleteAccountSheet(
                    confirmText: $deleteConfirmText,
                    isDeleting: $isDeleting,
                    errorMessage: $deleteError,
                    onConfirm: performDelete
                )
            }
        }
    }

    @ViewBuilder private var syncStatusView: some View {
        switch env.sync.status {
        case .idle:
            if let last = env.sync.lastSyncedAt {
                Text("Synced \(last.formatted(date: .omitted, time: .shortened))").foregroundStyle(.secondary)
            } else {
                Text("Up to date").foregroundStyle(.secondary)
            }
        case .syncing:
            HStack(spacing: 6) { ProgressView().controlSize(.small); Text("Syncing…") }.foregroundStyle(.secondary)
        case let .error(message):
            Text(message).foregroundStyle(.ssBad).font(.caption)
        }
    }

    private var appVersion: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(v) (\(b))"
    }

    private func performDelete() async {
        isDeleting = true
        deleteError = nil
        defer { isDeleting = false }
        do {
            try await env.auth.deleteAccount()
            env.dataStore.wipeAll()
            SyncState(userId: userId).reset()
            showingDeleteConfirm = false
            // authStateChanges → signedOut will route back to SignInView.
        } catch {
            deleteError = error.localizedDescription
        }
    }
}

/// Type-to-confirm destructive deletion, matching Apple's account-deletion requirement.
private struct DeleteAccountSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var confirmText: String
    @Binding var isDeleting: Bool
    @Binding var errorMessage: String?
    let onConfirm: () async -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("This permanently deletes your account and all associated data. Type **DELETE** to confirm.")
                    .font(.subheadline)
                TextField("DELETE", text: $confirmText)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .padding()
                    .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))

                if let errorMessage {
                    Text(errorMessage).font(.caption).foregroundStyle(.ssBad)
                }

                Button(role: .destructive) {
                    Task { await onConfirm() }
                } label: {
                    HStack {
                        if isDeleting { ProgressView().tint(.white) }
                        Text("Delete My Account").frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.ssBad)
                .controlSize(.large)
                .disabled(confirmText != "DELETE" || isDeleting)

                Spacer()
            }
            .padding()
            .navigationTitle("Delete Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.disabled(isDeleting)
                }
            }
            .interactiveDismissDisabled(isDeleting)
        }
    }
}
