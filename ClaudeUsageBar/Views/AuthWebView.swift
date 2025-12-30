//
//  AuthWebView.swift
//  ClaudeUsageBar
//
//  Browser-based authentication with automatic session extraction
//

import SwiftUI
import WebKit

struct AuthWindowView: View {
    @Environment(\.dismiss) private var dismiss
    let onAuthenticated: (String, String) -> Void

    @State private var showManualEntry = false
    @State private var sessionKey: String = ""
    @State private var organizationId: String = ""
    @State private var authStatus: AuthStatus = .waiting
    @State private var statusMessage: String = "Sign in to Claude"

    private let anthropicOrange = Color(red: 0.83, green: 0.53, blue: 0.30)

    enum AuthStatus {
        case waiting
        case authenticating
        case extracting
        case success
        case failed
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 4) {
                    Text("✳︎")
                        .foregroundColor(anthropicOrange)
                    Text("Sign in to Claude")
                        .font(.system(size: 13, weight: .medium))
                }
                Spacer()
                Button("×") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                    .font(.system(size: 16))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))

            // Status bar
            HStack(spacing: 6) {
                switch authStatus {
                case .waiting:
                    Circle().fill(Color.gray).frame(width: 6, height: 6)
                case .authenticating:
                    ProgressView().scaleEffect(0.5)
                case .extracting:
                    ProgressView().scaleEffect(0.5)
                case .success:
                    Circle().fill(Color.green).frame(width: 6, height: 6)
                case .failed:
                    Circle().fill(Color.red).frame(width: 6, height: 6)
                }
                Text(statusMessage)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Spacer()

                Button(showManualEntry ? "Browser" : "Manual") {
                    showManualEntry.toggle()
                }
                .font(.system(size: 9))
                .foregroundColor(.secondary)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor))

            if showManualEntry {
                // Manual entry form
                manualEntryView
            } else {
                // Embedded browser
                ClaudeWebView(
                    onSessionExtracted: { session, org in
                        sessionKey = session
                        organizationId = org
                        authStatus = .success
                        statusMessage = "Authenticated!"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            onAuthenticated(session, org)
                            dismiss()
                        }
                    },
                    onStatusChange: { status in
                        statusMessage = status
                        if status.contains("Extracting") {
                            authStatus = .extracting
                        } else if status.contains("Signed in") {
                            authStatus = .authenticating
                        }
                    }
                )
            }
        }
        .frame(width: 480, height: 600)
    }

    private var manualEntryView: some View {
        VStack(spacing: 16) {
            Spacer()

            VStack(alignment: .leading, spacing: 12) {
                Text("Manual Credential Entry")
                    .font(.system(size: 12, weight: .medium))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Session Key")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    SecureField("sk-ant-sid01-...", text: $sessionKey)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Organization ID")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    TextField("UUID from URL", text: $organizationId)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11))
                }

                Button("Save & Connect") {
                    onAuthenticated(sessionKey, organizationId)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(anthropicOrange)
                .disabled(sessionKey.isEmpty || organizationId.isEmpty)
            }
            .padding(20)
            .frame(maxWidth: 300)

            Spacer()

            Text("Get credentials from claude.ai → DevTools → Application → Cookies")
                .font(.system(size: 9))
                .foregroundColor(.secondary.opacity(0.6))
                .padding(.bottom, 12)
        }
    }
}

// MARK: - WKWebView Wrapper

struct ClaudeWebView: NSViewRepresentable {
    let onSessionExtracted: (String, String) -> Void
    let onStatusChange: (String) -> Void

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent() // Fresh session each time

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

        // Load Claude login page
        if let url = URL(string: "https://claude.ai/login") {
            webView.load(URLRequest(url: url))
        }

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onSessionExtracted: onSessionExtracted, onStatusChange: onStatusChange)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        let onSessionExtracted: (String, String) -> Void
        let onStatusChange: (String) -> Void
        private var hasExtracted = false

        init(onSessionExtracted: @escaping (String, String) -> Void, onStatusChange: @escaping (String) -> Void) {
            self.onSessionExtracted = onSessionExtracted
            self.onStatusChange = onStatusChange
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard let url = webView.url else { return }
            let urlString = url.absoluteString

            print("Navigation finished: \(urlString)")

            // Check if we're on a logged-in page (not login/signup)
            if !urlString.contains("/login") && !urlString.contains("/signup") && urlString.contains("claude.ai") {
                // User appears to be logged in
                DispatchQueue.main.async {
                    self.onStatusChange("Signed in! Extracting credentials...")
                }
                extractCredentials(from: webView)
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url {
                print("Navigating to: \(url)")

                // Extract org ID from URL if present
                // URL format: https://claude.ai/chat/xxxx or https://claude.ai/project/org-id/...
                if url.absoluteString.contains("claude.ai") && !url.absoluteString.contains("/login") {
                    DispatchQueue.main.async {
                        self.onStatusChange("Loading Claude...")
                    }
                }
            }
            decisionHandler(.allow)
        }

        private func extractCredentials(from webView: WKWebView) {
            guard !hasExtracted else { return }

            // Get cookies from WKWebView
            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
                guard let self = self else { return }

                // Find sessionKey cookie
                let sessionCookie = cookies.first { $0.name == "sessionKey" && $0.domain.contains("claude.ai") }

                if let sessionKey = sessionCookie?.value {
                    print("Found session key: \(sessionKey.prefix(20))...")

                    DispatchQueue.main.async {
                        self.onStatusChange("Extracting organization ID...")
                    }

                    // Now fetch organization ID from API
                    self.fetchOrganizationId(sessionKey: sessionKey, webView: webView)
                } else {
                    print("Session cookie not found yet")
                    // Retry after a short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        self.extractCredentials(from: webView)
                    }
                }
            }
        }

        private func fetchOrganizationId(sessionKey: String, webView: WKWebView) {
            // Use JavaScript to fetch the organization list
            let script = """
            (async function() {
                try {
                    const response = await fetch('https://claude.ai/api/organizations', {
                        credentials: 'include'
                    });
                    const data = await response.json();
                    if (data && data.length > 0) {
                        return data[0].uuid;
                    }
                    return null;
                } catch (e) {
                    return null;
                }
            })()
            """

            webView.evaluateJavaScript(script) { [weak self] result, error in
                guard let self = self else { return }

                if let orgId = result as? String, !orgId.isEmpty {
                    print("Found org ID: \(orgId)")
                    self.hasExtracted = true

                    DispatchQueue.main.async {
                        self.onSessionExtracted(sessionKey, orgId)
                    }
                } else {
                    print("Could not get org ID from API, trying URL fallback")
                    // Try to extract from current URL or use fallback method
                    self.extractOrgFromURL(webView: webView, sessionKey: sessionKey)
                }
            }
        }

        private func extractOrgFromURL(webView: WKWebView, sessionKey: String) {
            // Try to navigate to settings to get org from URL
            if let url = URL(string: "https://claude.ai/settings") {
                webView.load(URLRequest(url: url))

                // Check URL after navigation
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                    guard let self = self, !self.hasExtracted else { return }

                    // Try the API call again
                    let script = """
                    (async function() {
                        const response = await fetch('https://claude.ai/api/organizations', { credentials: 'include' });
                        const data = await response.json();
                        return data[0]?.uuid || '';
                    })()
                    """

                    webView.evaluateJavaScript(script) { result, error in
                        if let orgId = result as? String, !orgId.isEmpty {
                            self.hasExtracted = true
                            DispatchQueue.main.async {
                                self.onSessionExtracted(sessionKey, orgId)
                            }
                        } else {
                            DispatchQueue.main.async {
                                self.onStatusChange("Could not extract org ID. Use manual entry.")
                            }
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    AuthWindowView { _, _ in }
}
