import Foundation

/// Asks Claude to name the constellation you just drew and tell its story.
///
/// The key is read from `ANTHROPIC_API_KEY` in Info.plist, which is fed by
/// `Config/Secrets.xcconfig` (see the README). That is fine for a toy on your
/// own device — anything you ship should call your own server instead, so the
/// key never leaves it.
enum Namer {
    struct Myth: Decodable, Equatable {
        let name: String
        let myth: String
    }

    enum Failure: Error {
        case missingKey
        case http(status: Int)
        case refused(String)
        case malformedResponse
    }

    static let unnamed = Myth(
        name: "The Unnamed",
        myth: "Some constellations keep their stories to themselves. Play it again and listen closely."
    )

    private static let model = "claude-opus-5"
    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 45
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

    static var isConfigured: Bool { apiKey != nil }

    private static var apiKey: String? {
        let key = (Bundle.main.object(forInfoDictionaryKey: "ANTHROPIC_API_KEY") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let key, !key.isEmpty else { return nil }
        return key
    }

    /// Never throws: a sky that can't reach the network still gets a name.
    static func myth(for lines: [[Star]]) async -> Myth {
        do {
            return try await requestMyth(for: lines)
        } catch {
            return unnamed
        }
    }

    static func requestMyth(for lines: [[Star]]) async throws -> Myth {
        guard let apiKey else { throw Failure.missingKey }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        // Server-side fallback: if a safety classifier declines the turn, the
        // API re-routes to a capable fallback model instead of returning nothing.
        request.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")
        request.httpBody = try JSONSerialization.data(withJSONObject: body(for: lines))

        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw Failure.http(status: http.statusCode)
        }
        return try parse(data)
    }

    // MARK: - Request

    static func prompt(for lines: [[Star]]) -> String {
        let drawn = lines.filter { $0.count >= 2 }
        let strokes = drawn.enumerated().map { index, stars -> String in
            let points = stars
                .map { "(\(Int(($0.x * 100).rounded())),\(Int(($0.y * 100).rounded())))" }
                .joined(separator: " ")
            let pitches = stars
                .map { String(Int(Music.pitch(forY: $0.y).rounded())) }
                .joined(separator: ", ")
            let label = drawn.count > 1 ? "Line \(index + 1)" : "The line"
            return "\(label): \(stars.count) stars at \(points), played as \(pitches) Hz."
        }.joined(separator: "\n")

        let together = drawn.count > 1
            ? """

            The \(drawn.count) lines play at the same time, each looping at its own speed, so \
            they drift in and out of step with one another.
            """
            : ""

        return """
        Someone just drew a new constellation. Positions are x,y percentages of the sky with y \
        growing downward, in the order the stars were connected.

        \(strokes)\(together)

        Invent a name for this constellation — two to four words — and a warm, whimsical \
        two-sentence origin myth of the kind a parent might tell a child at bedtime. Let the \
        shape of the figure and the shape of the melody suggest the story.
        """
    }

    private static func body(for lines: [[Star]]) -> [String: Any] {
        [
            "model": model,
            "max_tokens": 4_096,
            "fallbacks": "default",
            "output_config": [
                // A short, creative answer: low effort keeps it quick without
                // turning adaptive thinking off entirely.
                "effort": "low",
                "format": [
                    "type": "json_schema",
                    "schema": [
                        "type": "object",
                        "properties": [
                            "name": ["type": "string"],
                            "myth": ["type": "string"]
                        ],
                        "required": ["name", "myth"],
                        "additionalProperties": false
                    ]
                ]
            ],
            "messages": [["role": "user", "content": prompt(for: lines)]]
        ]
    }

    // MARK: - Response

    /// Pulls the structured JSON out of the response's text blocks. Adaptive
    /// thinking means `content` can hold thinking blocks too, so filter by type.
    static func parse(_ data: Data) throws -> Myth {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw Failure.malformedResponse
        }
        if let stop = root["stop_reason"] as? String, stop == "refusal" {
            let explanation = (root["stop_details"] as? [String: Any])?["explanation"] as? String
            throw Failure.refused(explanation ?? "The sky declined to answer.")
        }
        let blocks = root["content"] as? [[String: Any]] ?? []
        let text = blocks
            .filter { $0["type"] as? String == "text" }
            .compactMap { $0["text"] as? String }
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty else { throw Failure.malformedResponse }
        do {
            return try JSONDecoder().decode(Myth.self, from: Data(text.utf8))
        } catch {
            throw Failure.malformedResponse
        }
    }
}
