import Foundation
#if os(macOS)
import AppKit
import Vision
#elseif os(iOS)
import UIKit
import Vision
#endif

// MARK: - AnalysisResult

struct AnalysisResult: Codable {
    let ocrText: String
    let description: String
    let category: String
    let tags: [String]
    let sourceApp: String?

    enum CodingKeys: String, CodingKey {
        case ocrText = "ocr_text"
        case description
        case category
        case tags
        case sourceApp = "source_app"
    }
}

// MARK: - AnalysisMode

enum AnalysisMode: String, CaseIterable, Identifiable {
    case aiVision = "AI Vision (Full Analysis)"
    case localOCR = "Local OCR Only (Offline)"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .aiVision: return "Uses a cloud AI model for rich descriptions, categorization, and OCR."
        case .localOCR: return "Uses Apple Vision on-device. No API key needed. Works offline."
        }
    }
}

// MARK: - APIProvider

struct APIProvider: Codable, Identifiable, Equatable, Hashable {
    var id: UUID
    var name: String
    var endpoint: String
    var apiKey: String
    var models: [String]

    static let builtInProviders: [APIProvider] = [
        APIProvider(
            id: UUID(uuidString: "00000001-0000-0000-0000-000000000001")!,
            name: "OpenAI",
            endpoint: "https://api.openai.com/v1/chat/completions",
            apiKey: "",
            models: ["gpt-4.1", "gpt-4.1-mini", "gpt-4o"]
        ),
        APIProvider(
            id: UUID(uuidString: "00000001-0000-0000-0000-000000000002")!,
            name: "OpenRouter",
            endpoint: "https://openrouter.ai/api/v1/chat/completions",
            apiKey: "",
            models: [
                "anthropic/claude-sonnet-4.6",
                "anthropic/claude-haiku-4.5",
                "anthropic/claude-opus-4.6",
                "openai/gpt-4.1",
                "google/gemini-3-pro-preview"
            ]
        ),
        APIProvider(
            id: UUID(uuidString: "00000001-0000-0000-0000-000000000003")!,
            name: "Ollama (Local)",
            endpoint: "http://localhost:11434/v1/chat/completions",
            apiKey: "ollama",
            models: ["llava", "llava:13b", "bakllava", "minicpm-v"]
        )
    ]
}

// MARK: - AIService

@Observable
final class AIService {

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let selectedModel = "ai_selected_model"
        static let selectedProviderID = "ai_selected_provider_id"
        static let analysisMode = "ai_analysis_mode"
        static let providers = "ai_providers_v3"
        static let hasCompletedSetup = "has_completed_setup"
    }

    private static let analysisPrompt = """
        Analyze this screenshot. Respond in JSON only, no markdown fences: \
        {"ocr_text": "all visible text extracted verbatim", \
        "description": "2-3 sentence description of what the screenshot shows", \
        "category": "one of: Code, Error, Design, Social Media, Conversation, Article, Receipt, Photo, Other", \
        "tags": ["tag1", "tag2", "tag3"], \
        "source_app": "detected app name or null"}
        """

    // MARK: - State

    private(set) var isProcessing: Bool = false
    private(set) var lastError: Error?

    // MARK: - Setup State

    var hasCompletedSetup: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.hasCompletedSetup) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.hasCompletedSetup) }
    }

    // MARK: - Configuration

    var analysisMode: AnalysisMode {
        get {
            let raw = UserDefaults.standard.string(forKey: Keys.analysisMode) ?? ""
            return AnalysisMode(rawValue: raw) ?? .aiVision
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: Keys.analysisMode) }
    }

    var selectedModel: String {
        get { UserDefaults.standard.string(forKey: Keys.selectedModel) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: Keys.selectedModel) }
    }

    var selectedProviderID: String {
        get { UserDefaults.standard.string(forKey: Keys.selectedProviderID) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: Keys.selectedProviderID) }
    }

    var providers: [APIProvider] {
        get {
            guard let data = UserDefaults.standard.data(forKey: Keys.providers),
                  let decoded = try? JSONDecoder().decode([APIProvider].self, from: data) else {
                return APIProvider.builtInProviders
            }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: Keys.providers)
            }
        }
    }

    var activeProvider: APIProvider? {
        providers.first { $0.id.uuidString == selectedProviderID }
    }

    var isConfigured: Bool {
        if analysisMode == .localOCR { return true }
        guard let provider = activeProvider else { return false }
        return !provider.apiKey.isEmpty && !selectedModel.isEmpty
    }

    // MARK: - Analysis

    func analyzeScreenshot(imageData: Data) async throws -> AnalysisResult {
        switch analysisMode {
        case .aiVision:
            return try await analyzeWithAI(imageData: imageData)
        case .localOCR:
            return try await analyzeWithLocalOCR(imageData: imageData)
        }
    }

    // MARK: - AI Vision Analysis

    private func analyzeWithAI(imageData: Data) async throws -> AnalysisResult {
        guard let provider = activeProvider else {
            throw AIServiceError.noProviderSelected
        }
        guard !provider.apiKey.isEmpty else {
            throw AIServiceError.missingAPIKey
        }
        guard !selectedModel.isEmpty else {
            throw AIServiceError.noModelSelected
        }

        isProcessing = true
        defer { isProcessing = false }

        let base64Image = imageData.base64EncodedString()
        let mimeType = imageData.detectMimeType

        let requestBody: [String: Any] = [
            "model": selectedModel,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "image_url",
                            "image_url": ["url": "data:\(mimeType);base64,\(base64Image)"]
                        ],
                        [
                            "type": "text",
                            "text": Self.analysisPrompt
                        ]
                    ]
                ]
            ],
            "max_tokens": 1024,
            "temperature": 0.2
        ]

        let bodyData = try JSONSerialization.data(withJSONObject: requestBody)

        var request = URLRequest(url: URL(string: provider.endpoint)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(provider.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData
        request.timeoutInterval = 60

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw AIServiceError.httpError(statusCode: httpResponse.statusCode, body: body)
        }

        let completion = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)

        guard let content = completion.choices.first?.message.content, !content.isEmpty else {
            throw AIServiceError.emptyResponse
        }

        let jsonString = extractJSON(from: content)
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw AIServiceError.jsonParsingFailed(detail: "Could not encode as UTF-8")
        }

        let result = try JSONDecoder().decode(AnalysisResult.self, from: jsonData)
        lastError = nil
        return result
    }

    // MARK: - Local OCR Analysis (Apple Vision)

    private func analyzeWithLocalOCR(imageData: Data) async throws -> AnalysisResult {
        isProcessing = true
        defer { isProcessing = false }

        let ocrText = try await performOCR(on: imageData)
        let category = classifyFromText(ocrText)
        let tags = extractTags(from: ocrText)
        let description = ocrText.isEmpty
            ? "Screenshot (no text detected)"
            : String(ocrText.prefix(200)).replacingOccurrences(of: "\n", with: " ")

        lastError = nil
        return AnalysisResult(
            ocrText: ocrText,
            description: description,
            category: category,
            tags: tags,
            sourceApp: nil
        )
    }

    private func performOCR(on imageData: Data) async throws -> String {
        #if os(macOS)
        guard let nsImage = NSImage(data: imageData),
              let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw AIServiceError.invalidResponse
        }
        #elseif os(iOS)
        guard let uiImage = UIImage(data: imageData),
              let cgImage = uiImage.cgImage else {
            throw AIServiceError.invalidResponse
        }
        #endif

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let text = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                continuation.resume(returning: text)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func classifyFromText(_ text: String) -> String {
        let lower = text.lowercased()
        if lower.contains("error") || lower.contains("exception") || lower.contains("crash")
            || lower.contains("failed") || lower.contains("stack trace") { return "Error" }
        if lower.contains("func ") || lower.contains("class ") || lower.contains("import ")
            || lower.contains("def ") || lower.contains("const ") || lower.contains("var ")
            || lower.contains("return ") { return "Code" }
        if lower.contains("@") && (lower.contains("follow") || lower.contains("like")
            || lower.contains("retweet")) { return "Social Media" }
        if lower.contains("total") && (lower.contains("$") || lower.contains("tax")
            || lower.contains("subtotal")) { return "Receipt" }
        if (lower.contains("sent") || lower.contains("delivered")) && lower.contains("message") {
            return "Conversation"
        }
        if text.count > 500 { return "Article" }
        if text.count < 20 { return "Photo" }
        return "Other"
    }

    private func extractTags(from text: String) -> [String] {
        let words = text.lowercased()
            .components(separatedBy: .alphanumerics.inverted)
            .filter { $0.count > 4 }
        var freq: [String: Int] = [:]
        for w in words { freq[w, default: 0] += 1 }
        return Array(freq.sorted { $0.value > $1.value }.prefix(5).map(\.key))
    }

    // MARK: - Helpers

    private func extractJSON(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("```") {
            let lines = trimmed.components(separatedBy: "\n")
            let inner = lines.dropFirst().dropLast()
            return inner.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let start = trimmed.firstIndex(of: "{"),
           let end = trimmed.lastIndex(of: "}") {
            return String(trimmed[start...end])
        }
        return trimmed
    }
}

// MARK: - Response Models

private struct ChatCompletionResponse: Decodable {
    let choices: [Choice]
    struct Choice: Decodable { let message: Message }
    struct Message: Decodable { let content: String? }
}

// MARK: - Errors

enum AIServiceError: LocalizedError {
    case missingAPIKey
    case noProviderSelected
    case noModelSelected
    case invalidResponse
    case httpError(statusCode: Int, body: String)
    case emptyResponse
    case jsonParsingFailed(detail: String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "No API key configured. Add your key in Settings."
        case .noProviderSelected: return "No API provider selected. Choose one in Settings."
        case .noModelSelected: return "No AI model selected. Choose one in Settings."
        case .invalidResponse: return "Unexpected response from server."
        case .httpError(let code, let body): return "HTTP \(code): \(body.prefix(200))"
        case .emptyResponse: return "The AI model returned an empty response."
        case .jsonParsingFailed(let detail): return "Failed to parse response: \(detail)"
        }
    }
}

// MARK: - Data Extension

extension Data {
    var detectMimeType: String {
        var byte: UInt8 = 0
        copyBytes(to: &byte, count: 1)
        switch byte {
        case 0xFF: return "image/jpeg"
        case 0x89: return "image/png"
        case 0x47: return "image/gif"
        default: return "image/jpeg"
        }
    }
}
