//
//  UsageViewModel.swift
//  ClaudeUsageBar
//

import Foundation
import Combine
import SwiftUI
import ServiceManagement

@MainActor
final class UsageViewModel: ObservableObject {
    static let shared = UsageViewModel()

    // MARK: - Published Properties

    @Published var usageData: UsageData = .placeholder
    @Published var isLoading: Bool = false
    @Published var error: String?
    @Published var lastUpdated: Date?
    @Published var refreshInterval: TimeInterval = 60 // seconds

    // MARK: - Display Settings (persisted)

    @AppStorage("showIcon") var showIcon: Bool = true
    @AppStorage("showOnly5hr") var showOnly5hr: Bool = false
    @AppStorage("showOnlyWeekly") var showOnlyWeekly: Bool = false

    // Launch at login using SMAppService (macOS 13+)
    var launchAtStartup: Bool {
        get {
            if #available(macOS 13.0, *) {
                return SMAppService.mainApp.status == .enabled
            }
            return false
        }
        set {
            if #available(macOS 13.0, *) {
                do {
                    if newValue {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                } catch {
                    print("Failed to \(newValue ? "enable" : "disable") launch at login: \(error)")
                }
            }
        }
    }

    // MARK: - Private

    private var refreshTask: Task<Void, Never>?
    private var timer: Timer?

    private init() {
        startAutoRefresh()
    }

    // MARK: - Public Methods

    func refresh() async {
        guard !isLoading else { return }

        isLoading = true
        error = nil

        do {
            let data = try await ClaudeAPIService.shared.fetchUsage()
            usageData = data
            lastUpdated = Date()
            error = nil
            // Notify that usage data changed so status bar can update
            NotificationCenter.default.post(name: NSNotification.Name("UsageDataChanged"), object: nil)
        } catch let apiError as APIError {
            error = apiError.errorDescription
            print("API Error: \(apiError.errorDescription ?? "Unknown")")
        } catch {
            self.error = error.localizedDescription
            print("Error: \(error)")
        }

        isLoading = false
    }

    func startAutoRefresh() {
        stopAutoRefresh()

        // Initial fetch
        refreshTask = Task {
            await refresh()
        }

        // Set up timer for periodic refresh
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refresh()
            }
        }
    }

    func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
        timer?.invalidate()
        timer = nil
    }

    func updateRefreshInterval(_ interval: TimeInterval) {
        refreshInterval = max(30, min(600, interval)) // 30s to 10min
        startAutoRefresh()
    }

    // MARK: - Credentials

    var hasCredentials: Bool {
        CredentialStorage.shared.hasCredentials
    }

    func saveCredentials(sessionKey: String, organizationId: String) {
        CredentialStorage.shared.sessionKey = sessionKey.trimmingCharacters(in: .whitespacesAndNewlines)
        CredentialStorage.shared.organizationId = organizationId.trimmingCharacters(in: .whitespacesAndNewlines)

        // Refresh after saving
        Task {
            await refresh()
        }
    }

    func clearCredentials() {
        CredentialStorage.shared.clearAll()
        usageData = .placeholder
        error = "Credentials cleared"
    }

    // MARK: - Display Helpers

    var statusText: String {
        if !hasCredentials {
            return "Setup"
        }
        if isLoading && lastUpdated == nil {
            return "..."
        }
        return usageData.menuBarText
    }

    var statusColor: NSColor {
        guard hasCredentials else { return .secondaryLabelColor }

        let pct = usageData.fiveHourPercentage
        if pct < 50 {
            return .systemGreen
        } else if pct < 80 {
            return .systemYellow
        } else {
            return .systemRed
        }
    }
}
