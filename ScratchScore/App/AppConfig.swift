import Foundation

/// Reads build-time configuration injected into Info.plist from `Secrets.xcconfig`.
///
/// The publishable (anon) key is safe to ship — it is guarded by Row Level Security.
/// The service-role / secret key is NEVER present in the app; it lives only in the
/// Supabase Edge Function environment.
enum AppConfig {
    private static func infoString(_ key: String) -> String? {
        (Bundle.main.object(forInfoDictionaryKey: key) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The configured Supabase URL, or a harmless placeholder when unconfigured.
    /// When unconfigured, `isBackendConfigured` is false and the app shows a setup
    /// screen instead of making any network calls, so the placeholder is never hit.
    static var supabaseURL: URL {
        if let raw = infoString("SupabaseURL"), let url = URL(string: raw), url.scheme != nil {
            return url
        }
        return URL(string: "https://placeholder.supabase.co")!
    }

    static var supabaseAnonKey: String {
        infoString("SupabaseAnonKey") ?? "placeholder"
    }

    /// Custom URL scheme used for the Google OAuth redirect callback.
    static var oauthCallbackScheme: String {
        infoString("OAuthCallbackScheme") ?? "app.scratchscore"
    }

    /// The redirect URL Supabase sends the OAuth callback to. Must be allow-listed
    /// in Supabase → Auth → URL Configuration.
    static var oauthRedirectURL: URL {
        URL(string: "\(oauthCallbackScheme)://login-callback")!
    }

    /// `true` when the app has real Supabase secrets (not the committed placeholders).
    static var isBackendConfigured: Bool {
        guard let raw = infoString("SupabaseURL"), let key = infoString("SupabaseAnonKey") else {
            return false
        }
        return !raw.contains("YOUR-PROJECT-ref")
            && !raw.contains("placeholder")
            && key != "REPLACE_WITH_PUBLISHABLE_ANON_KEY"
            && key != "placeholder"
            && !key.isEmpty
    }
}
