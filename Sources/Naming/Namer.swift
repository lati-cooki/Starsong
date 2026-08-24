import Foundation

/// Asks Claude to name the constellation you just drew and tell its story.
///
/// The key is whatever the person brought: `KeyStore` first, falling back to
/// `ANTHROPIC_API_KEY` in Info.plist (fed by `Config/Secrets.xcconfig`) so a
/// checkout with a key in it still works without touching the Keychain.
///
/// Either way the key is on the device and the device talks to the API
/// directly, which is fine for something you run yourself. Anything you ship
/// to other people should call your own server instead, so no key travels.
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

    /// Where the key in use came from, so the profile can say so.
    enum Source: Equatable {
        case keychain, bundle, none
    }

    static var source: Source {
        if KeyStore.hasKey { return .keychain }
        return bundleKey != nil ? .bundle : .none
    }

    /// A key the person brought wins over one baked in at build time — they
    /// chose it more recently, and it is the one they can change.
    static var apiKey: String? { KeyStore.load() ?? bundleKey }

    private static var bundleKey: String? {
        let key = (Bundle.main.object(forInfoDictionaryKey: "ANTHROPIC_API_KEY") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let key, !key.isEmpty else { return nil }
        return key
    }

    /// Never throws: a sky that can't reach the network still gets a name.
    /// The reason is logged rather than dropped — every failure used to arrive
    /// as the same wordless fallback, which made a missing key and a rejected
    /// key indistinguishable.
    static func myth(for lines: [[Star]], voices: [Instrument] = []) async -> Myth {
        do {
            return try await requestMyth(for: lines, voices: voices)
        } catch {
            print("Starsong: naming failed — \(describe(error))")
            return unnamed
        }
    }

    /// Plain English for a failure, for logs and for the profile.
    static func describe(_ error: Error) -> String {
        switch error {
        case Failure.missingKey:
            return "no API key. Add one in Profile."
        case Failure.http(401), Failure.http(403):
            return "the key was rejected (HTTP 401). Check it in Profile."
        case Failure.http(429):
            return "rate limited (HTTP 429). Try again shortly."
        case let Failure.http(status) where status >= 500:
            return "the API is having trouble (HTTP \(status)). Try again shortly."
        case let Failure.http(status):
            return "the request was refused (HTTP \(status))."
        case let Failure.refused(why):
            return why
        case Failure.malformedResponse:
            return "the reply could not be read."
        default:
            return error.localizedDescription
        }
    }

    /// Checks a key by asking for a real (tiny) myth with it. Deliberately the
    /// same request shape the app actually sends, so this also catches a body
    /// the API has stopped accepting — not just a bad key.
    static func verify(_ key: String) async -> Result<Myth, Error> {
        let probe = [Star(x: 0.3, y: 0.6, radius: 1, phase: 0, isBright: false),
                     Star(x: 0.7, y: 0.35, radius: 1, phase: 0, isBright: false)]
        do {
            return .success(try await requestMyth(for: [probe], key: key))
        } catch {
            return .failure(error)
        }
    }

    static func requestMyth(for lines: [[Star]], voices: [Instrument] = [],
                            key: String? = nil) async throws -> Myth {
        guard let apiKey = key ?? apiKey else { throw Failure.missingKey }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        // Server-side fallback: if a safety classifier declines the turn, the
        // API re-routes to a capable fallback model instead of returning nothing.
        request.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")
        request.httpBody = try JSONSerialization.data(withJSONObject: body(for: lines, voices: voices))

        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw Failure.http(status: http.statusCode)
        }
        return try parse(data)
    }

    // MARK: - Request

    static func prompt(for lines: [[Star]], voices: [Instrument] = []) -> String {
        let drawn = lines.filter { $0.count >= 2 }
        let strokes = drawn.enumerated().map { index, stars -> String in
            let voice = index < voices.count ? " on a \(voices[index].name.lowercased())" : ""
            let points = stars
                .map { "(\(Int(($0.x * 100).rounded())),\(Int(($0.y * 100).rounded())))" }
                .joined(separator: " ")
            let pitches = stars
                .map { String(Int(Music.pitch(forY: $0.y).rounded())) }
                .joined(separator: ", ")
            let label = drawn.count > 1 ? "Line \(index + 1)" : "The line"
            return "\(label)\(voice): \(stars.count) stars at \(points), played as \(pitches) Hz."
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

    private static func body(for lines: [[Star]], voices: [Instrument]) -> [String: Any] {
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
            "messages": [["role": "user", "content": prompt(for: lines, voices: voices)]]
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
