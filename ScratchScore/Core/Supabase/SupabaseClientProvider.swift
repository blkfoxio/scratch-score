import Foundation
import Supabase

/// Builds and vends the shared `SupabaseClient`.
///
/// Uses the PKCE auth flow, which is required for the native Sign in with Apple
/// ID-token exchange and the Google OAuth redirect on iOS. The client persists the
/// session in the Keychain and refreshes tokens automatically.
enum SupabaseClientProvider {
    static func make() -> SupabaseClient {
        SupabaseClient(
            supabaseURL: AppConfig.supabaseURL,
            supabaseKey: AppConfig.supabaseAnonKey,
            options: SupabaseClientOptions(
                db: .init(schema: "public"),
                auth: .init(
                    redirectToURL: AppConfig.oauthRedirectURL,
                    flowType: .pkce
                )
            )
        )
    }
}
