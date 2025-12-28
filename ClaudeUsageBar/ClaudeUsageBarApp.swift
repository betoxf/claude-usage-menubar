//
//  ClaudeUsageBarApp.swift
//  ClaudeUsageBar
//

import SwiftUI

@main
struct ClaudeUsageBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(viewModel: UsageViewModel.shared)
        }
    }
}
