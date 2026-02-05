import Foundation

struct NonRecordingEventSmoke {
    struct SessionResponse: Decodable {
        let token: String
    }

    struct ScheduleResponse: Decodable {
        let status: String
    }

    static func run() async -> Int32 {
        do {
            let httpBase = URL(string: "http://127.0.0.1:4850/v1")!
            let wsURL = URL(string: "ws://127.0.0.1:4850/v1/events")!

            let token = try await createSession(base: httpBase)
            let ws = openWebSocket(url: wsURL, token: token)
            defer {
                ws.cancel(with: .normalClosure, reason: nil)
            }

            let targetPath = "sequencer.track1.step1.ratchets"
            _ = try await scheduleStepRatchetUpdate(base: httpBase, token: token, targetPath: targetPath)

            let verified = try await awaitExpectedEvents(
                webSocket: ws,
                targetPath: targetPath,
                maxEvents: 20,
                timeoutSeconds: 10
            )

            if verified {
                print("PASS: received non-recording event assertions for \(targetPath)")
                return 0
            }
            fputs("FAIL: did not observe expected non-recording events\n", stderr)
            return 1
        } catch {
            fputs("FAIL: \(error)\n", stderr)
            return 1
        }
    }

    static func createSession(base: URL) async throws -> String {
        var request = URLRequest(url: base.appending(path: "sessions"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = """
        {"client":{"name":"event-smoke","version":"0.1"},"requestedScopes":["state:read","control:write"]}
        """.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw NSError(domain: "smoke", code: 1, userInfo: [NSLocalizedDescriptionKey: "session create failed"])
        }
        let decoded = try JSONDecoder().decode(SessionResponse.self, from: data)
        return decoded.token
    }

    static func openWebSocket(url: URL, token: String) -> URLSessionWebSocketTask {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let task = URLSession.shared.webSocketTask(with: request)
        task.resume()
        return task
    }

    static func scheduleStepRatchetUpdate(base: URL, token: String, targetPath: String) async throws -> ScheduleResponse {
        let bundleId = "bundle_evt_smoke_" + UUID().uuidString.prefix(8)
        let idempotency = "evt-smoke-" + UUID().uuidString.prefix(8)

        let payload = """
        {
          "bundle": {
            "bundleId": "\(bundleId)",
            "intentId": "intent_event_smoke",
            "validationId": null,
            "preconditionStateVersion": null,
            "atomic": false,
            "requireConfirmation": false,
            "actions": [
              {"actionId":"evt_1","type":"set","target":"\(targetPath)","value":5}
            ]
          },
          "applyMode": "best_effort",
          "confirmationToken": null,
          "idempotencyKey": "\(idempotency)"
        }
        """

        var request = URLRequest(url: base.appending(path: "actions/schedule"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = payload.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw NSError(domain: "smoke", code: 2, userInfo: [NSLocalizedDescriptionKey: "schedule failed"])
        }
        return try JSONDecoder().decode(ScheduleResponse.self, from: data)
    }

    static func awaitExpectedEvents(
        webSocket: URLSessionWebSocketTask,
        targetPath: String,
        maxEvents: Int,
        timeoutSeconds: UInt64
    ) async throws -> Bool {
        var sawStepUpdate = false
        var sawStateChanged = false

        for _ in 0..<maxEvents {
            let message = try await withTimeout(seconds: timeoutSeconds) {
                try await webSocket.receive()
            }
            guard case .string(let text) = message,
                  let data = text.data(using: .utf8),
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = json["type"] as? String,
                  let payload = json["payload"] as? [String: Any] else {
                continue
            }

            if type == "sequencer.step_updated",
               let field = payload["field"] as? String,
               field == "ratchets" {
                sawStepUpdate = true
            }

            if type == "state.changed",
               let changedPaths = payload["changedPaths"] as? [String],
               changedPaths.contains(targetPath) {
                sawStateChanged = true
            }

            if sawStepUpdate && sawStateChanged {
                return true
            }
        }

        return false
    }

    static func withTimeout<T>(seconds: UInt64, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: seconds * 1_000_000_000)
                throw NSError(domain: "smoke", code: 3, userInfo: [NSLocalizedDescriptionKey: "timed out waiting for event"])
            }

            let first = try await group.next()!
            group.cancelAll()
            return first
        }
    }
}

Task {
    let code = await NonRecordingEventSmoke.run()
    Foundation.exit(code)
}

dispatchMain()
