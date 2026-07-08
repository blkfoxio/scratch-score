import SwiftUI

/// Switches between the setup screen, sign-in, and the authenticated app based on
/// backend configuration and auth state.
struct RootView: View {
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        Group {
            if !env.isBackendConfigured {
                BackendSetupView()
            } else {
                switch env.auth.state {
                case .loading:
                    ProgressView("Loading…")
                case .signedOut:
                    SignInView()
                case let .signedIn(userId, _, _):
                    MainTabView(userId: userId)
                }
            }
        }
        .task {
            guard env.isBackendConfigured else { return }
            await env.auth.observeAuthState()
        }
    }
}

/// Shown when `Secrets.xcconfig` still holds placeholder values. Lets the app launch
/// (and the UI be inspected) before Supabase is wired up.
struct BackendSetupView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "flag.checkered.2.crossed")
                .font(.system(size: 56))
                .foregroundStyle(.ssFairway)
            Text("Scratch Score")
                .font(.largeTitle.bold())
            Text("Backend not configured")
                .font(.headline)
            Text("Add your Supabase URL and publishable key to\nScratchScore/App/Secrets.xcconfig, then rebuild.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
