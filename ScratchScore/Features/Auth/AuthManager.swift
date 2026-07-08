import Foundation
import Observation
import Supabase
import AuthenticationServices

@MainActor
@Observable
final class AuthManager {
    enum State: Equatable {
        case loading
        case signedOut
        case signedIn(userId: UUID, email: String?, fullName: String?)
    }

    private(set) var state: State = .loading
    var lastErrorMessage: String?
    var isWorking = false

    private let supabase: SupabaseClient
    private var rawAppleNonce: String?

    init(supabase: SupabaseClient) {
        self.supabase = supabase
    }

    var currentUserId: UUID? {
        if case let .signedIn(userId, _, _) = state { return userId }
        return nil
    }

    var isSignedIn: Bool { currentUserId != nil }

    // MARK: - Session observation

    /// Long-lived subscription to Supabase auth state. Drives the root view switch.
    func observeAuthState() async {
        for await change in supabase.auth.authStateChanges {
            switch change.event {
            case .initialSession, .signedIn, .signedOut, .tokenRefreshed, .userUpdated:
                apply(session: change.session)
            default:
                break
            }
        }
    }

    private func apply(session: Session?) {
        guard let session else {
            state = .signedOut
            return
        }
        let user = session.user
        let fullName = user.userMetadata["full_name"]?.stringValue
        state = .signedIn(userId: user.id, email: user.email, fullName: fullName)
    }

    // MARK: - Email / password

    func signIn(email: String, password: String) async {
        await run {
            try await self.supabase.auth.signIn(email: email, password: password)
        }
    }

    /// Returns `true` when a confirmation email is required (no active session yet).
    @discardableResult
    func signUp(email: String, password: String) async -> Bool {
        var needsConfirmation = false
        await run {
            let response = try await self.supabase.auth.signUp(email: email, password: password)
            needsConfirmation = response.session == nil
        }
        return needsConfirmation
    }

    func resetPassword(email: String) async {
        await run {
            try await self.supabase.auth.resetPasswordForEmail(
                email,
                redirectTo: AppConfig.oauthRedirectURL
            )
        }
    }

    // MARK: - Sign in with Apple

    /// Configure the `ASAuthorizationAppleIDRequest`: generate a fresh nonce, set its
    /// SHA256 hash, and request name + email (name arrives only on first authorization).
    func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = AppleNonce.random()
        rawAppleNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = AppleNonce.sha256(nonce)
    }

    func completeAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case let .failure(error):
            if (error as? ASAuthorizationError)?.code == .canceled { return }
            lastErrorMessage = error.localizedDescription
        case let .success(authorization):
            await handleAppleAuthorization(authorization)
        }
    }

    private func handleAppleAuthorization(_ authorization: ASAuthorization) async {
        guard
            let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
            let tokenData = credential.identityToken,
            let idToken = String(data: tokenData, encoding: .utf8),
            let nonce = rawAppleNonce
        else {
            lastErrorMessage = "Could not read Apple credentials."
            return
        }

        // Full name is only present on the first authorization — capture it now.
        let fullName = [credential.fullName?.givenName, credential.fullName?.familyName]
            .compactMap { $0 }
            .joined(separator: " ")

        await run {
            try await self.supabase.auth.signInWithIdToken(
                credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
            )
            if !fullName.isEmpty {
                _ = try? await self.supabase.auth.update(
                    user: UserAttributes(data: ["full_name": .string(fullName)])
                )
            }
        }
        rawAppleNonce = nil
    }

    // MARK: - Google

    func signInWithGoogle() async {
        await run {
            try await self.supabase.auth.signInWithOAuth(
                provider: .google,
                redirectTo: AppConfig.oauthRedirectURL
            )
        }
    }

    // MARK: - Sign out / delete

    func signOut() async {
        await run { try await self.supabase.auth.signOut() }
    }

    /// Invokes the `delete-account` Edge Function (which deletes the auth user, cascading
    /// all app data, and revokes the Apple token), then signs out locally.
    func deleteAccount() async throws {
        isWorking = true
        defer { isWorking = false }
        try await supabase.functions.invoke("delete-account")
        try? await supabase.auth.signOut()
    }

    // MARK: - Helpers

    private func run(_ operation: @escaping () async throws -> Void) async {
        isWorking = true
        lastErrorMessage = nil
        defer { isWorking = false }
        do {
            try await operation()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }
}
