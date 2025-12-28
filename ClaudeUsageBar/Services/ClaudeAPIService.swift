//
//  ClaudeAPIService.swift
//  ClaudeUsageBar
//

import Foundation

enum APIError: Error, LocalizedError {
    case noCredentials
    case invalidURL
    case unauthorized
    case networkError(Error)
    case decodingError(Error)
    case unknown(Int)

    var errorDescription: String? {
        switch self {
        case .noCredentials:
            return "No credentials configured"
        case .invalidURL:
            return "Invalid API URL"
        case .unauthorized:
            return "Session expired - please update your session key"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to parse response: \(error.localizedDescription)"
        case .unknown(let code):
            return "Unknown error (status: \(code))"
        }
    }
}

final class ClaudeAPIService {
    static let shared = ClaudeAPIService()

    private let baseURL = "https://claude.ai/api/organizations"
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: config)
    }

    // MARK: - Fetch Usage

    func fetchUsage() async throws -> UsageData {
        guard let sessionKey = KeychainService.shared.sessionKey,
              let orgId = KeychainService.shared.organizationId else {
            throw APIError.noCredentials
        }

        // Claude API usage endpoint
        let urlString = "\(baseURL)/\(orgId)/usage"
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        // Set all required headers to mimic browser request
        request.setValue("*/*", forHTTPHeaderField: "accept")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "accept-language")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("web_claude_ai", forHTTPHeaderField: "anthropic-client-platform")
        request.setValue("1.0.0", forHTTPHeaderField: "anthropic-client-version")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36", forHTTPHeaderField: "user-agent")
        request.setValue("https://claude.ai", forHTTPHeaderField: "origin")
        request.setValue("https://claude.ai/settings/usage", forHTTPHeaderField: "referer")
        request.setValue("empty", forHTTPHeaderField: "sec-fetch-dest")
        request.setValue("cors", forHTTPHeaderField: "sec-fetch-mode")
        request.setValue("same-origin", forHTTPHeaderField: "sec-fetch-site")
        request.setValue("sessionKey=\(sessionKey)", forHTTPHeaderField: "Cookie")

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.unknown(0)
            }

            // Debug: print response
            if let jsonString = String(data: data, encoding: .utf8) {
                print("API Response (\(httpResponse.statusCode)): \(jsonString.prefix(500))")
            }

            switch httpResponse.statusCode {
            case 200:
                return try parseUsageResponse(data)
            case 401, 403:
                throw APIError.unauthorized
            default:
                throw APIError.unknown(httpResponse.statusCode)
            }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }

    // MARK: - Parse Response

    private func parseUsageResponse(_ data: Data) throws -> UsageData {
        var usageData = UsageData()

        // Try to decode as dictionary for flexible parsing
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            // If not JSON, try to extract from text
            if let text = String(data: data, encoding: .utf8) {
                return try parseTextResponse(text)
            }
            throw APIError.decodingError(NSError(domain: "JSON", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON"]))
        }

        // Parse Claude's actual API format:
        // {"five_hour":{"utilization":28.0,"resets_at":"..."},"seven_day":{"utilization":9.0,"resets_at":"..."}}

        // Parse 5-hour rolling window
        if let fiveHour = json["five_hour"] as? [String: Any] {
            if let utilization = fiveHour["utilization"] as? Double {
                usageData.fiveHourUsed = Int(utilization)
                usageData.fiveHourLimit = 100
            }
            if let resetsAt = fiveHour["resets_at"] as? String {
                usageData.fiveHourResetAt = parseDate(resetsAt)
            }
        }

        // Parse 7-day (weekly) limit
        if let sevenDay = json["seven_day"] as? [String: Any] {
            if let utilization = sevenDay["utilization"] as? Double {
                usageData.weeklyUsed = Int(utilization)
                usageData.weeklyLimit = 100
            }
            if let resetsAt = sevenDay["resets_at"] as? String {
                usageData.weeklyResetAt = parseDate(resetsAt)
            }
        }

        return usageData
    }

    private func parseTextResponse(_ text: String) throws -> UsageData {
        var usageData = UsageData()

        // Try to extract percentage from text (e.g., "27% used")
        let percentPattern = #"(\d+)%\s*used"#
        if let regex = try? NSRegularExpression(pattern: percentPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range(at: 1), in: text) {
            if let percentage = Int(text[range]) {
                usageData.fiveHourUsed = percentage
                usageData.fiveHourLimit = 100
            }
        }

        return usageData
    }

    private func parseDate(_ string: String) -> Date? {
        // Try ISO8601 first
        let iso8601 = ISO8601DateFormatter()
        iso8601.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso8601.date(from: string) {
            return date
        }

        // Try without fractional seconds
        iso8601.formatOptions = [.withInternetDateTime]
        if let date = iso8601.date(from: string) {
            return date
        }

        // Try common formats
        let dateFormatter = DateFormatter()
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd HH:mm:ss",
            "EEE MMM d HH:mm:ss yyyy"
        ]

        for format in formats {
            dateFormatter.dateFormat = format
            if let date = dateFormatter.date(from: string) {
                return date
            }
        }

        return nil
    }
}
