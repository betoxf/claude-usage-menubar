# ClaudeUsageBar

A lightweight macOS menu bar app that displays your Claude.ai usage (5-hour rolling window and 7-day limits).

![Menu Bar](https://img.shields.io/badge/macOS-Menu%20Bar-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)

## Installation

### Download (Easiest)
1. Download `ClaudeUsageBar.dmg` from [Releases](https://github.com/betoxf/claude-usage-menubar/releases)
2. Open the DMG and drag ClaudeUsageBar to Applications
3. First launch: Right-click > Open (to bypass Gatekeeper)

### Build from Source
```bash
git clone https://github.com/betoxf/claude-usage-menubar.git
cd claude-usage-menubar
xcodebuild -scheme ClaudeUsageBar -configuration Release build
```
Or open `ClaudeUsageBar.xcodeproj` in Xcode and press Cmd+R.

## Setup

1. Click the menu bar icon > "Setup Claude Usage"
2. Click "Open Claude.ai" to sign in
3. Get your credentials:
   - **Organization ID**: In Safari, press ⌥⌘I → Network tab → find "usage" request → copy UUID from URL
   - **Session Key**: ⌘F search "sessionKey" in cookies → copy value until the `;`
4. Paste credentials and click Save

## Features

- Shows 5-hour and 7-day usage percentages in menu bar
- Click menu bar for detailed usage info and reset times
- Display modes: Both, 5h only, or Weekly only
- Optional "Claude" icon label
- Credentials stored securely in macOS Keychain
- Minimal resource usage (~0% CPU when idle)

## Privacy

- Your credentials are stored locally in macOS Keychain
- No data is sent to any server other than claude.ai
- Not affiliated with Anthropic

## License

MIT
