//
//  ConversationalControlBridge.swift
//  Grainulator
//
//  Minimal localhost HTTP bridge for conversational control.
//  Implements the first API slice: sessions, capabilities, state, and recording control.
//

import Foundation
import Network
import CryptoKit

final class ConversationalControlBridge: ObservableObject, @unchecked Sendable {
    @Published private(set) var isRunning: Bool = false
    @Published private(set) var listenPort: UInt16 = 4850

    private struct SessionInfo {
        let sessionId: String
        let token: String
        let expiresAt: Date
        let scopes: Set<String>
    }

    private struct IdempotencyRecord {
        let signature: String
        let statusCode: Int
        let responseBody: Data
    }

    private struct HTTPRequest {
        let method: String
        let rawTarget: String
        let path: String
        let queryItems: [String: String]
        let headers: [String: String]
        let body: Data
    }

    private struct HTTPResponse {
        let statusCode: Int
        let reason: String
        let headers: [String: String]
        let body: Data

        static func json(statusCode: Int, reason: String = "OK", payload: Any) -> HTTPResponse {
            let data = (try? JSONSerialization.data(withJSONObject: payload, options: [])) ?? Data("{}".utf8)
            return HTTPResponse(
                statusCode: statusCode,
                reason: reason,
                headers: ["Content-Type": "application/json"],
                body: data
            )
        }
    }

    private struct TimeSpecRequest: Codable {
        let anchor: String?
        let quantization: String?
        let durationMs: Int?
        let durationBeats: Double?
        let durationBars: Double?
    }

    private struct RecordingStartRequest: Decodable {
        let mode: String
        let feedback: Double?
        let sourceType: String?
        let sourceChannel: Int?
        let time: TimeSpecRequest?
        let idempotencyKey: String
    }

    private struct RecordingStopRequest: Decodable {
        let time: TimeSpecRequest?
        let idempotencyKey: String
    }

    private struct RecordingFeedbackRequest: Decodable {
        let value: Double
        let time: TimeSpecRequest?
        let idempotencyKey: String
    }

    private struct RecordingModeRequest: Decodable {
        let mode: String
        let time: TimeSpecRequest?
        let idempotencyKey: String
    }

    private struct SessionCreateRequest: Decodable {
        struct Client: Decodable {
            let name: String
            let version: String
        }

        let client: Client
        let requestedScopes: [String]
        let userLabel: String?
    }

    private struct StateQueryRequest: Decodable {
        let paths: [String]
    }

    private enum JSONValue: Codable {
        case string(String)
        case number(Double)
        case bool(Bool)
        case null

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if container.decodeNil() {
                self = .null
            } else if let value = try? container.decode(Bool.self) {
                self = .bool(value)
            } else if let value = try? container.decode(Double.self) {
                self = .number(value)
            } else if let value = try? container.decode(String.self) {
                self = .string(value)
            } else {
                throw DecodingError.typeMismatch(
                    JSONValue.self,
                    DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported JSON value")
                )
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .string(let value):
                try container.encode(value)
            case .number(let value):
                try container.encode(value)
            case .bool(let value):
                try container.encode(value)
            case .null:
                try container.encodeNil()
            }
        }
    }

    private struct ActionRequest: Codable {
        let actionId: String?
        let type: String
        let target: String?
        let value: JSONValue?
        let from: Double?
        let to: Double?
        let curve: String?
        let time: TimeSpecRequest?
        let reason: String?
    }

    private struct ActionBundleRequest: Codable {
        let bundleId: String
        let intentId: String?
        let validationId: String?
        let preconditionStateVersion: Int?
        let atomic: Bool
        let requireConfirmation: Bool?
        let actions: [ActionRequest]
    }

    private struct PolicyRequest: Decodable {
        let maxRisk: String?
        let lockModules: [String]?
        let allowFileLoads: Bool?
        let allowRecording: Bool?
        let requireDiffForRiskAtLeast: String?
    }

    private struct ValidateActionsRequest: Decodable {
        let bundle: ActionBundleRequest
        let policy: PolicyRequest?
    }

    private struct ScheduleActionsRequest: Decodable {
        let bundle: ActionBundleRequest
        let applyMode: String
        let confirmationToken: String?
        let idempotencyKey: String
    }

    private struct VoiceTarget {
        let module: String
        let id: String
        let reelIndex: Int
        let defaultFeedback: Float
        let defaultMode: AudioEngineWrapper.RecordMode
    }

    private struct ValidationRecord {
        let validationId: String
        let bundleSignature: String
        let isValid: Bool
        let risk: String
        let requiresConfirmation: Bool
        let confirmationToken: String?
        let confirmationTokenExpiresAt: Date?
        let expiresAt: Date
    }

    private struct ScheduledBundleState {
        let bundleId: String
        let intentId: String?
        let scheduledBar: Int
        let scheduledBeat: Double
        var status: String
        var stateVersion: Int
        var errorCodes: [String]
        let createdAt: Date
    }

    private struct WebSocketClient {
        let id: String
        let connection: NWConnection
        var receiveBuffer: Data
    }

    private struct ScheduledTime {
        let executeAt: Date
        let bar: Int
        let beat: Double
    }

    private enum BridgeErrorCode: String {
        case unauthorized = "TOKEN_EXPIRED"
        case notFound = "ACTION_PATH_UNKNOWN"
        case badRequest = "DEPENDENCY_VIOLATION"
        case idempotencyConflict = "IDEMPOTENCY_KEY_CONFLICT"
        case recordingAlreadyActive = "RECORDING_ALREADY_ACTIVE"
        case recordingNotActive = "RECORDING_NOT_ACTIVE"
        case recordingModeUnsupported = "RECORDING_MODE_UNSUPPORTED"
        case recordingFeedbackUnsupported = "RECORDING_FEEDBACK_UNSUPPORTED"
        case actionOutOfRange = "ACTION_OUT_OF_RANGE"
        case actionTypeUnsupported = "ACTION_TYPE_UNSUPPORTED"
        case riskExceedsPolicy = "RISK_EXCEEDS_POLICY"
        case staleStateVersion = "STALE_STATE_VERSION"
        case confirmationTokenExpired = "CONFIRMATION_TOKEN_EXPIRED"
    }

    private let queue = DispatchQueue(label: "com.grainulator.conversational-bridge")
    private let jsonDecoder = JSONDecoder()

    private weak var audioEngine: AudioEngineWrapper?
    private weak var masterClock: MasterClock?
    private weak var sequencer: StepSequencer?
    private weak var drumSequencer: DrumSequencer?
    private weak var chordSequencer: ChordSequencer?
    /// Cached C++ engine handle for thread-safe reads (e.g. IsRecording atomic checks)
    private var cachedEngineHandle: OpaquePointer?
    private var cachedSampleRate: Double = 48000.0

    private var listener: NWListener?
    private var sessionsByToken: [String: SessionInfo] = [:]
    private var sessionsById: [String: SessionInfo] = [:]
    private var idempotency: [String: IdempotencyRecord] = [:]
    private var validationsById: [String: ValidationRecord] = [:]
    private var scheduledBundles: [String: ScheduledBundleState] = [:]
    private var scheduledWorkItems: [String: DispatchWorkItem] = [:]
    private var webSocketClients: [String: WebSocketClient] = [:]
    private var eventHistory: [[String: Any]] = []
    private var nextEventSeq: Int = 0
    private var stateVersion: Int = 1

    private let voiceTargets: [VoiceTarget] = [
        VoiceTarget(module: "granular", id: "granular.voiceA", reelIndex: 0, defaultFeedback: 0.0, defaultMode: .oneShot),
        VoiceTarget(module: "loop", id: "loop.voiceA", reelIndex: 1, defaultFeedback: 0.5, defaultMode: .liveLoop),
        VoiceTarget(module: "loop", id: "loop.voiceB", reelIndex: 2, defaultFeedback: 0.5, defaultMode: .liveLoop),
        VoiceTarget(module: "granular", id: "granular.voiceB", reelIndex: 3, defaultFeedback: 0.0, defaultMode: .oneShot),
    ]

    @MainActor
    func start(audioEngine: AudioEngineWrapper, masterClock: MasterClock, sequencer: StepSequencer? = nil, drumSequencer: DrumSequencer? = nil, chordSequencer: ChordSequencer? = nil, port: UInt16 = 4850) {
        self.audioEngine = audioEngine
        self.masterClock = masterClock
        self.sequencer = sequencer
        self.drumSequencer = drumSequencer
        self.chordSequencer = chordSequencer
        self.listenPort = port
        self.cachedEngineHandle = audioEngine.cppEngineHandle
        self.cachedSampleRate = audioEngine.sampleRate

        queue.async { [weak self] in
            guard let self else { return }
            self.startListenerIfNeeded()
        }
    }

    @MainActor
    func stop() {
        queue.async { [weak self] in
            guard let self else { return }
            self.listener?.cancel()
            self.listener = nil
            self.sessionsById.removeAll()
            self.sessionsByToken.removeAll()
            self.idempotency.removeAll()
            DispatchQueue.main.async {
                self.isRunning = false
            }
        }
    }

    private func startListenerIfNeeded() {
        guard listener == nil else { return }

        do {
            let nwPort = NWEndpoint.Port(rawValue: listenPort) ?? .init(integerLiteral: 4850)
            let listener = try NWListener(using: .tcp, on: nwPort)
            self.listener = listener

            listener.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }

            listener.stateUpdateHandler = { [weak self] state in
                guard let self else { return }
                switch state {
                case .ready:
                    DispatchQueue.main.async {
                        self.isRunning = true
                    }
                    print("Conversational bridge listening on 127.0.0.1:\(self.listenPort)")
                case .failed(let error):
                    DispatchQueue.main.async {
                        self.isRunning = false
                    }
                    print("Conversational bridge failed: \(error)")
                case .cancelled:
                    DispatchQueue.main.async {
                        self.isRunning = false
                    }
                default:
                    break
                }
            }

            listener.start(queue: queue)
        } catch {
            print("Failed to start conversational bridge: \(error)")
        }
    }

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: queue)
        receiveRequest(on: connection, accumulated: Data())
    }

    private func receiveRequest(on connection: NWConnection, accumulated: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1024 * 1024) { [weak self] content, _, isComplete, error in
            guard let self else { return }
            if let error {
                print("Bridge receive error: \(error)")
                connection.cancel()
                return
            }

            var buffer = accumulated
            if let content {
                buffer.append(content)
            }

            if let request = self.parseRequest(from: buffer) {
                if self.isWebSocketUpgradeRequest(request) {
                    self.handleWebSocketUpgrade(request: request, connection: connection)
                    return
                }
                let response = self.route(request)
                self.send(response, on: connection)
                return
            }

            if isComplete {
                self.send(self.errorResponse(statusCode: 400, reason: "Bad Request", code: .badRequest, message: "Incomplete HTTP request"), on: connection)
                return
            }

            self.receiveRequest(on: connection, accumulated: buffer)
        }
    }

    private func parseRequest(from data: Data) -> HTTPRequest? {
        let separator = Data("\r\n\r\n".utf8)
        guard let headerRange = data.range(of: separator) else { return nil }

        let headerData = data.subdata(in: 0..<headerRange.lowerBound)
        guard let headerString = String(data: headerData, encoding: .utf8) else { return nil }

        let lines = headerString.split(separator: "\r\n", omittingEmptySubsequences: false)
        guard let requestLine = lines.first else { return nil }

        let parts = requestLine.split(separator: " ", omittingEmptySubsequences: true)
        guard parts.count >= 2 else { return nil }

        let method = String(parts[0]).uppercased()
        let rawTarget = String(parts[1])

        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let colonIndex = line.firstIndex(of: ":") else { continue }
            let key = line[..<colonIndex].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let value = line[line.index(after: colonIndex)...].trimmingCharacters(in: .whitespacesAndNewlines)
            headers[key] = value
        }

        let bodyStart = headerRange.upperBound
        let contentLength = Int(headers["content-length"] ?? "0") ?? 0
        guard data.count >= bodyStart + contentLength else { return nil }
        let body = contentLength > 0 ? data.subdata(in: bodyStart..<(bodyStart + contentLength)) : Data()

        let (path, queryItems) = parseTarget(rawTarget)

        return HTTPRequest(
            method: method,
            rawTarget: rawTarget,
            path: path,
            queryItems: queryItems,
            headers: headers,
            body: body
        )
    }

    private func parseTarget(_ target: String) -> (String, [String: String]) {
        let parts = target.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        let path = String(parts[0])
        guard parts.count > 1 else { return (path, [:]) }

        var items: [String: String] = [:]
        for pair in parts[1].split(separator: "&", omittingEmptySubsequences: true) {
            let kv = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            let key = String(kv[0]).removingPercentEncoding ?? String(kv[0])
            let value: String
            if kv.count == 2 {
                value = String(kv[1]).removingPercentEncoding ?? String(kv[1])
            } else {
                value = ""
            }
            items[key] = value
        }
        return (path, items)
    }

    private func isWebSocketUpgradeRequest(_ request: HTTPRequest) -> Bool {
        guard request.path == "/v1/events" else { return false }
        let upgrade = request.headers["upgrade"]?.lowercased() ?? ""
        let connection = request.headers["connection"]?.lowercased() ?? ""
        return upgrade == "websocket" && connection.contains("upgrade")
    }

    private func handleWebSocketUpgrade(request: HTTPRequest, connection: NWConnection) {
        guard validateAuthorization(request) else {
            send(errorResponse(statusCode: 401, reason: "Unauthorized", code: .unauthorized, message: "Missing or invalid bearer token"), on: connection)
            return
        }
        guard let key = request.headers["sec-websocket-key"], !key.isEmpty else {
            send(errorResponse(statusCode: 400, reason: "Bad Request", code: .badRequest, message: "Missing Sec-WebSocket-Key"), on: connection)
            return
        }

        let accept = websocketAccept(for: key)
        var head = "HTTP/1.1 101 Switching Protocols\r\n"
        head += "Upgrade: websocket\r\n"
        head += "Connection: Upgrade\r\n"
        head += "Sec-WebSocket-Accept: \(accept)\r\n"
        head += "\r\n"
        let data = Data(head.utf8)

        connection.send(content: data, completion: .contentProcessed { [weak self] error in
            guard let self else { return }
            if error != nil {
                connection.cancel()
                return
            }
            self.registerWebSocketClient(connection: connection, request: request)
        })
    }

    private func websocketAccept(for key: String) -> String {
        let magic = key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
        let digest = Insecure.SHA1.hash(data: Data(magic.utf8))
        return Data(digest).base64EncodedString()
    }

    private func registerWebSocketClient(connection: NWConnection, request: HTTPRequest) {
        let clientId = UUID().uuidString
        webSocketClients[clientId] = WebSocketClient(id: clientId, connection: connection, receiveBuffer: Data())

        if let afterSeqText = request.queryItems["afterSeq"], let afterSeq = Int(afterSeqText) {
            replayEvents(afterSeq: afterSeq, to: clientId)
        }

        receiveWebSocketData(clientId: clientId)
    }

    private func receiveWebSocketData(clientId: String) {
        guard let client = webSocketClients[clientId] else { return }
        client.connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] content, _, isComplete, error in
            guard let self else { return }
            if error != nil || isComplete {
                self.removeWebSocketClient(clientId)
                return
            }
            guard let content, !content.isEmpty else {
                self.receiveWebSocketData(clientId: clientId)
                return
            }

            var updated = self.webSocketClients[clientId]
            updated?.receiveBuffer.append(content)
            if let updated {
                self.webSocketClients[clientId] = updated
                self.processWebSocketBuffer(clientId: clientId)
            }
            self.receiveWebSocketData(clientId: clientId)
        }
    }

    private func processWebSocketBuffer(clientId: String) {
        guard var client = webSocketClients[clientId] else { return }
        while true {
            guard let frame = parseWebSocketFrame(from: client.receiveBuffer) else { break }
            client.receiveBuffer = frame.remaining
            switch frame.opcode {
            case 0x8: // close
                sendWebSocketFrame(opcode: 0x8, payload: Data(), to: client.connection) { [weak self] in
                    self?.removeWebSocketClient(clientId)
                }
                return
            case 0x9: // ping
                sendWebSocketFrame(opcode: 0xA, payload: frame.payload, to: client.connection)
            default:
                break
            }
        }
        webSocketClients[clientId] = client
    }

    private func removeWebSocketClient(_ clientId: String) {
        guard let client = webSocketClients.removeValue(forKey: clientId) else { return }
        client.connection.cancel()
    }

    private func parseWebSocketFrame(from data: Data) -> (opcode: UInt8, payload: Data, remaining: Data)? {
        guard data.count >= 2 else { return nil }
        let b0 = data[data.startIndex]
        let b1 = data[data.startIndex + 1]

        let opcode = b0 & 0x0F
        let masked = (b1 & 0x80) != 0
        var length = Int(b1 & 0x7F)
        var offset = 2

        if length == 126 {
            guard data.count >= offset + 2 else { return nil }
            let high = Int(data[data.startIndex + offset]) << 8
            let low = Int(data[data.startIndex + offset + 1])
            length = high | low
            offset += 2
        } else if length == 127 {
            guard data.count >= offset + 8 else { return nil }
            var value: UInt64 = 0
            for i in 0..<8 {
                value = (value << 8) | UInt64(data[data.startIndex + offset + i])
            }
            guard value <= UInt64(Int.max) else { return nil }
            length = Int(value)
            offset += 8
        }

        var maskKey: [UInt8] = [0, 0, 0, 0]
        if masked {
            guard data.count >= offset + 4 else { return nil }
            for i in 0..<4 {
                maskKey[i] = data[data.startIndex + offset + i]
            }
            offset += 4
        }

        guard data.count >= offset + length else { return nil }
        let payloadRange = (data.startIndex + offset)..<(data.startIndex + offset + length)
        var payload = Data(data[payloadRange])
        if masked {
            payload = Data(payload.enumerated().map { byteIndex, byte in
                byte ^ maskKey[byteIndex % 4]
            })
        }

        let remaining = Data(data[(data.startIndex + offset + length)...])
        return (opcode, payload, remaining)
    }

    private func sendWebSocketFrame(opcode: UInt8, payload: Data, to connection: NWConnection, completion: (@Sendable () -> Void)? = nil) {
        var frame = Data()
        frame.append(0x80 | opcode)

        let payloadCount = payload.count
        if payloadCount <= 125 {
            frame.append(UInt8(payloadCount))
        } else if payloadCount <= 65535 {
            frame.append(126)
            frame.append(UInt8((payloadCount >> 8) & 0xFF))
            frame.append(UInt8(payloadCount & 0xFF))
        } else {
            frame.append(127)
            let length = UInt64(payloadCount)
            for shift in stride(from: 56, through: 0, by: -8) {
                frame.append(UInt8((length >> UInt64(shift)) & 0xFF))
            }
        }

        frame.append(payload)
        connection.send(content: frame, completion: .contentProcessed { _ in
            completion?()
        })
    }

    private func sendWebSocketJSON(_ object: [String: Any], to connection: NWConnection) {
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: []) else { return }
        sendWebSocketFrame(opcode: 0x1, payload: data, to: connection)
    }

    private func emitEvent(type: String, payload: [String: Any], sessionId: String? = nil) {
        nextEventSeq += 1
        let event: [String: Any] = [
            "eventId": "evt_" + String(nextEventSeq),
            "seq": nextEventSeq,
            "type": type,
            "ts": iso8601(Date()),
            "sessionId": sessionId ?? NSNull(),
            "stateVersion": stateVersion,
            "payload": payload,
        ]

        eventHistory.append(event)
        if eventHistory.count > 2000 {
            eventHistory.removeFirst(eventHistory.count - 2000)
        }

        for (_, client) in webSocketClients {
            sendWebSocketJSON(event, to: client.connection)
        }
    }

    private func replayEvents(afterSeq: Int, to clientId: String) {
        guard let client = webSocketClients[clientId] else { return }
        if let firstSeq = (eventHistory.first?["seq"] as? Int), afterSeq < (firstSeq - 1) {
            let gapEvent: [String: Any] = [
                "eventId": "evt_gap_\(firstSeq)",
                "seq": firstSeq,
                "type": "events.gap_detected",
                "ts": iso8601(Date()),
                "sessionId": NSNull(),
                "stateVersion": stateVersion,
                "payload": [
                    "expectedSeq": afterSeq + 1,
                    "actualSeq": firstSeq,
                    "recoveryHint": "Call GET /v1/state to resync",
                ],
            ]
            sendWebSocketJSON(gapEvent, to: client.connection)
        }
        let filtered = eventHistory.filter { event in
            guard let seq = event["seq"] as? Int else { return false }
            return seq > afterSeq
        }
        for event in filtered {
            sendWebSocketJSON(event, to: client.connection)
        }
    }

    private func recordMutation(changedPaths: [String], additionalEvents: [(type: String, payload: [String: Any])] = []) {
        stateVersion += 1
        for event in additionalEvents {
            emitEvent(type: event.type, payload: event.payload)
        }
        emitEvent(
            type: "state.changed",
            payload: [
                "changedPaths": changedPaths,
                "stateVersion": stateVersion,
            ]
        )
    }

    private func route(_ request: HTTPRequest) -> HTTPResponse {
        if request.method == "POST", request.path == "/v1/sessions" {
            return handleCreateSession(request)
        }

        // Debug endpoint: read sample time directly (no auth required)
        if request.method == "GET", request.path == "/v1/debug/sampletime" {
            let handle = cachedEngineHandle
            let sampleTime: UInt64 = handle != nil ? AudioEngine_GetCurrentSampleTime(handle!) : 0
            let clockRunning = handle != nil ? AudioEngine_IsClockRunning(handle!) : false
            let bpm = handle != nil ? AudioEngine_GetClockBPM(handle!) : 0.0
            return .json(statusCode: 200, reason: "OK", payload: [
                "sampleTime": sampleTime,
                "clockRunning": clockRunning,
                "bpm": bpm,
                "handlePresent": handle != nil,
            ])
        }

        guard validateAuthorization(request) else {
            return errorResponse(statusCode: 401, reason: "Unauthorized", code: .unauthorized, message: "Missing or invalid bearer token")
        }

        if request.method == "DELETE", request.path.hasPrefix("/v1/sessions/") {
            return handleDeleteSession(request)
        }
        if request.method == "GET", request.path == "/v1/capabilities" {
            return handleCapabilities()
        }
        if request.method == "GET", request.path == "/v1/parameters" {
            return handleParameters(request)
        }
        if request.method == "GET", request.path == "/v1/state" {
            return handleState()
        }
        if request.method == "POST", request.path == "/v1/state/query" {
            return handleStateQuery(request)
        }
        if request.method == "GET", request.path == "/v1/history" {
            return handleHistory(request)
        }
        if request.method == "POST", request.path == "/v1/actions/validate" {
            return handleValidateActions(request)
        }
        if request.method == "POST", request.path == "/v1/actions/schedule" {
            return handleScheduleActions(request)
        }
        if request.method == "GET", request.path == "/v1/actions/scheduled" {
            return handleListScheduledActions()
        }
        if request.method == "POST", request.path.hasPrefix("/v1/actions/"), request.path.hasSuffix("/cancel") {
            return handleCancelScheduledAction(request)
        }
        if request.method == "GET", request.path == "/v1/recording/voices" {
            return handleListRecordingVoices()
        }
        if request.method == "POST", request.path.hasPrefix("/v1/recording/voices/"), request.path.hasSuffix("/start") {
            return handleStartRecording(request)
        }
        if request.method == "POST", request.path.hasPrefix("/v1/recording/voices/"), request.path.hasSuffix("/stop") {
            return handleStopRecording(request)
        }
        if request.method == "POST", request.path.hasPrefix("/v1/recording/voices/"), request.path.hasSuffix("/feedback") {
            return handleSetRecordingFeedback(request)
        }
        if request.method == "POST", request.path.hasPrefix("/v1/recording/voices/"), request.path.hasSuffix("/mode") {
            return handleSetRecordingMode(request)
        }

        return errorResponse(statusCode: 404, reason: "Not Found", code: .notFound, message: "Endpoint not implemented")
    }

    private func activeSession(for request: HTTPRequest) -> SessionInfo? {
        guard let auth = request.headers["authorization"] else { return nil }
        let prefix = "bearer "
        guard auth.lowercased().hasPrefix(prefix) else { return nil }
        let token = String(auth.dropFirst(prefix.count))
        guard let session = sessionsByToken[token] else { return nil }
        if session.expiresAt < Date() {
            sessionsByToken[token] = nil
            sessionsById[session.sessionId] = nil
            return nil
        }
        return session
    }

    private func validateAuthorization(_ request: HTTPRequest) -> Bool {
        activeSession(for: request) != nil
    }

    private func handleCreateSession(_ request: HTTPRequest) -> HTTPResponse {
        guard let createRequest = tryDecode(SessionCreateRequest.self, from: request.body) else {
            return errorResponse(statusCode: 400, reason: "Bad Request", code: .badRequest, message: "Invalid session request payload")
        }

        let sessionId = "sess_" + UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(8)
        let token = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let expiresAt = Date().addingTimeInterval(60 * 60)
        let scopes = Set(createRequest.requestedScopes)

        let session = SessionInfo(
            sessionId: String(sessionId),
            token: token,
            expiresAt: expiresAt,
            scopes: scopes
        )

        sessionsByToken[token] = session
        sessionsById[session.sessionId] = session

        let payload: [String: Any] = [
            "sessionId": session.sessionId,
            "token": token,
            "expiresAt": iso8601(expiresAt),
            "capabilities": capabilitiesPayload(scopes: scopes),
        ]
        return .json(statusCode: 201, reason: "Created", payload: payload)
    }

    private func handleDeleteSession(_ request: HTTPRequest) -> HTTPResponse {
        let sessionId = request.path.replacingOccurrences(of: "/v1/sessions/", with: "")
        guard !sessionId.isEmpty, let session = sessionsById.removeValue(forKey: sessionId) else {
            return errorResponse(statusCode: 404, reason: "Not Found", code: .notFound, message: "Session not found")
        }
        sessionsByToken.removeValue(forKey: session.token)
        return HTTPResponse(statusCode: 204, reason: "No Content", headers: [:], body: Data())
    }

    private func handleCapabilities() -> HTTPResponse {
        return .json(statusCode: 200, payload: capabilitiesPayload(scopes: nil))
    }

    private func capabilitiesPayload(scopes: Set<String>?) -> [[String: Any]] {
        let canRecord = scopes?.contains("recording:write") ?? true
        let granularActions: [String] = canRecord
            ? ["set", "ramp", "toggle", "loadFile", "startRecording", "stopRecording", "setRecordingFeedback", "setRecordingMode"]
            : ["set", "ramp", "toggle", "loadFile"]
        let loopActions: [String] = canRecord
            ? ["set", "ramp", "toggle", "loadFile", "startRecording", "stopRecording", "setRecordingFeedback", "setRecordingMode"]
            : ["set", "ramp", "toggle", "loadFile"]

        return [
            [
                "module": "granular",
                "actions": granularActions,
                "paths": [
                    "granular.density",
                    "granular.size",
                    "granular.position",
                    "granular.voiceA.playing",
                    "granular.voiceA.speedRatio",
                    "granular.voiceA.sizeMs",
                    "granular.voiceA.pitchSemitones",
                    "granular.voiceA.envelope",
                    "granular.voiceB.playing",
                    "granular.voiceB.speedRatio",
                    "granular.voiceB.sizeMs",
                    "granular.voiceB.pitchSemitones",
                    "granular.voiceB.envelope",
                    "granular.<voiceId>.filterCutoff",
                    "granular.<voiceId>.filterResonance",
                    "granular.<voiceId>.morph",
                    "granular.<voiceId>.recording.active",
                    "granular.<voiceId>.recording.mode",
                    "granular.<voiceId>.recording.feedback",
                ],
                "recordingSources": recordingSourcesList(),
            ],
            [
                "module": "loop",
                "actions": loopActions,
                "paths": [
                    "loop.rate",
                    "loop.reverse",
                    "loop.<voiceId>.recording.active",
                    "loop.<voiceId>.recording.mode",
                    "loop.<voiceId>.recording.feedback",
                ],
                "recordingSources": recordingSourcesList(),
            ],
            [
                "module": "transport",
                "actions": ["set", "toggle"],
                "paths": ["transport.playing", "transport.bar", "transport.beat", "session.tempoBpm"],
            ],
            [
                "module": "sequencer",
                "actions": ["set", "toggle"],
                "paths": [
                    "session.key",
                    "sequencer.track1.enabled",
                    "sequencer.track1.pattern",
                    "sequencer.track1.rateMultiplier",
                    "sequencer.track1.clockDivision",
                    "sequencer.track1.output",
                    "sequencer.track2.enabled",
                    "sequencer.track2.pattern",
                    "sequencer.track2.rateMultiplier",
                    "sequencer.track2.clockDivision",
                    "sequencer.track2.output",
                    "sequencer.track2.stepGroupA.note",
                    "sequencer.track2.stepGroupB.note",
                    "sequencer.track<1|2>.step<1-8>.note",
                    "sequencer.track<1|2>.step<1-8>.probability",
                    "sequencer.track<1|2>.step<1-8>.ratchets",
                    "sequencer.track<1|2>.step<1-8>.gateMode",
                    "sequencer.track<1|2>.step<1-8>.gateLength",
                    "sequencer.track<1|2>.step<1-8>.stepType",
                ],
            ],
            [
                "module": "chords",
                "description": "8-step chord progression sequencer feeding intervals into the step sequencer scale system",
                "actions": ["set", "toggle"],
                "paths": [
                    "sequencer.chords.enabled",
                    "sequencer.chords.clockDivision",
                    "sequencer.chords.preset",
                    "sequencer.chords.step<1-8>.degree",
                    "sequencer.chords.step<1-8>.quality",
                    "sequencer.chords.step<1-8>.active",
                    "sequencer.chords.step<1-8>.clear",
                ],
            ],
            [
                "module": "synth",
                "actions": ["set"],
                "paths": [
                    "synth.plaits.mode",
                    "synth.plaits.harmonics",
                    "synth.plaits.timbre",
                    "synth.plaits.morph",
                    "synth.plaits.level",
                    "synth.plaits.lpgColor",
                    "synth.plaits.lpgDecay",
                    "synth.plaits.lpgAttack",
                    "synth.plaits.lpgBypass",
                    "synth.rings.mode",
                    "synth.rings.structure",
                    "synth.rings.brightness",
                    "synth.rings.damping",
                    "synth.rings.position",
                    "synth.rings.level",
                    "synth.daisydrum.mode",
                    "synth.daisydrum.harmonics",
                    "synth.daisydrum.timbre",
                    "synth.daisydrum.morph",
                    "synth.sampler.mode",
                    "synth.sampler.preset",
                    "synth.sampler.attack",
                    "synth.sampler.decay",
                    "synth.sampler.sustain",
                    "synth.sampler.release",
                    "synth.sampler.filterCutoff",
                    "synth.sampler.filterResonance",
                    "synth.sampler.tuning",
                    "synth.sampler.level",
                ],
            ],
            [
                "module": "drums",
                "description": "4-lane x 16-step drum trigger sequencer (Analog Kick, Synth Kick, Analog Snare, Hi-Hat)",
                "actions": ["set", "toggle"],
                "paths": [
                    "drums.playing",
                    "drums.syncToTransport",
                    "drums.clockDivision",
                    "drums.lane<1-4>.enabled",
                    "drums.lane<1-4>.level",
                    "drums.lane<1-4>.harmonics",
                    "drums.lane<1-4>.timbre",
                    "drums.lane<1-4>.morph",
                    "drums.lane<1-4>.note",
                    "drums.lane<1-4>.step<1-16>.active",
                    "drums.lane<1-4>.step<1-16>.velocity",
                    "drums.lane<1-4>.pattern",
                ],
                "laneNames": ["analogKick", "synthKick", "analogSnare", "hiHat"],
                "rhythmHints": [
                    "Steps are 16th notes at x4 division (default). 16 steps = 1 bar at 4/4.",
                    "Common kick patterns: steps 1,5,9,13 (four-on-the-floor), steps 1,9 (half-time).",
                    "Common snare patterns: steps 5,13 (backbeat).",
                    "Common hi-hat patterns: all 16 steps (straight 16ths), odd steps (8th notes).",
                    "Use lane pattern 'fourOnTheFloor', 'backbeat', 'straight16ths', 'straight8ths', or 'offbeats' for presets.",
                ],
            ],
        ]
    }

    private func handleParameters(_ request: HTTPRequest) -> HTTPResponse {
        let module = request.queryItems["module"]
        let parameters: [[String: Any]] = [
            [
                "path": "granular.<voiceId>.recording.feedback",
                "type": "float",
                "min": 0.0,
                "max": 1.0,
                "default": 0.5,
                "unit": "ratio",
                "safeUpdateMode": "smoothed",
                "smoothingMinMs": 30,
                "quantizable": true,
                "riskClass": "medium",
                "musicalTags": ["recording", "blend", "continuity"],
            ],
            [
                "path": "loop.<voiceId>.recording.feedback",
                "type": "float",
                "min": 0.0,
                "max": 1.0,
                "default": 0.5,
                "unit": "ratio",
                "safeUpdateMode": "smoothed",
                "smoothingMinMs": 30,
                "quantizable": true,
                "riskClass": "medium",
                "musicalTags": ["recording", "blend", "continuity"],
            ],
        ]

        if let module, module != "granular", module != "loop" {
            return .json(statusCode: 200, payload: [])
        }

        let filtered = parameters.filter { item in
            guard let module else { return true }
            guard let path = item["path"] as? String else { return false }
            return path.hasPrefix(module + ".")
        }
        return .json(statusCode: 200, payload: filtered)
    }

    private func handleState() -> HTTPResponse {
        let state = canonicalStatePayload()
        return .json(statusCode: 200, payload: state)
    }

    private func canonicalStatePayload() -> [String: Any] {
        let transport = currentTransport()
        let tempo = readMasterClockBPM()
        var granularRecording: [String: Any] = [:]
        var loopRecording: [String: Any] = [:]

        for voice in voiceTargets {
            let state = recordingState(for: voice)
            let entry: [String: Any] = [
                "active": state.active,
                "mode": state.mode,
                "feedback": state.feedback,
            ]
            if voice.module == "granular" {
                granularRecording[voice.id] = entry
            } else {
                loopRecording[voice.id] = entry
            }
        }

        return [
            "stateVersion": stateVersion,
            "schemaVersion": "0.1.0",
            "session": [
                "tempoBpm": tempo,
                "timeSignature": readTimeSignatureString(),
                "key": readSessionKeyText(),
            ],
            "transport": [
                "playing": transport.playing,
                "bar": transport.bar,
                "beat": transport.beat,
            ],
            "sequencer": [
                "track1": canonicalTrackStatePayload(trackIndex: 0) ?? [:],
                "track2": canonicalTrackStatePayload(trackIndex: 1) ?? [:],
                "chords": canonicalChordSequencerPayload(),
            ],
            "synth": [
                "macro_osc": [
                    "mode": readSynthModeName(parameter: .plaitsModel),
                    "harmonics": readGlobalParameter(id: .plaitsHarmonics),
                    "timbre": readGlobalParameter(id: .plaitsTimbre),
                    "morph": readGlobalParameter(id: .plaitsMorph),
                    "level": readGlobalParameter(id: .plaitsLevel),
                    "lpgColor": readGlobalParameter(id: .plaitsLPGColor),
                    "lpgDecay": readGlobalParameter(id: .plaitsLPGDecay),
                    "lpgAttack": readGlobalParameter(id: .plaitsLPGAttack),
                    "lpgBypass": readGlobalParameter(id: .plaitsLPGBypass),
                ] as [String: Any],
                "resonator": [
                    "mode": readSynthModeName(parameter: .ringsModel),
                    "structure": readGlobalParameter(id: .ringsStructure),
                    "brightness": readGlobalParameter(id: .ringsBrightness),
                    "damping": readGlobalParameter(id: .ringsDamping),
                    "position": readGlobalParameter(id: .ringsPosition),
                    "level": readGlobalParameter(id: .ringsLevel),
                ] as [String: Any],
                "daisydrum": [
                    "mode": readSynthModeName(parameter: .daisyDrumEngine),
                    "harmonics": readGlobalParameter(id: .daisyDrumHarmonics),
                    "timbre": readGlobalParameter(id: .daisyDrumTimbre),
                    "morph": readGlobalParameter(id: .daisyDrumMorph),
                ] as [String: Any],
                "sampler": canonicalSamplerStatePayload(),
            ],
            "granular": [
                "recording": granularRecording,
            ],
            "loop": [
                "recording": loopRecording,
            ],
            "drums": canonicalDrumSequencerStatePayload(),
            "fx": [:],
            "files": [:],
            "scenes": [],
        ]
    }

    private func canonicalDrumSequencerStatePayload() -> [String: Any] {
        return DispatchQueue.main.sync {
            MainActor.assumeIsolated {
                guard let drumSeq = self.drumSequencer else { return [:] as [String: Any] }
                var lanesPayload: [[String: Any]] = []
                for lane in drumSeq.lanes {
                    var steps: [[String: Any]] = []
                    for step in lane.steps {
                        steps.append([
                            "index": step.id + 1,
                            "active": step.isActive,
                            "velocity": step.velocity,
                        ])
                    }
                    let lanePayload: [String: Any] = [
                        "name": lane.lane.name,
                        "shortName": lane.lane.shortName,
                        "enabled": !lane.isMuted,
                        "level": lane.level,
                        "harmonics": lane.harmonics,
                        "timbre": lane.timbre,
                        "morph": lane.morph,
                        "note": Int(lane.note),
                        "steps": steps,
                    ]
                    lanesPayload.append(lanePayload)
                }
                return [
                    "playing": drumSeq.isPlaying,
                    "currentStep": drumSeq.currentStep + 1,
                    "syncToTransport": drumSeq.syncToTransport,
                    "clockDivision": drumSeq.stepDivision.rawValue,
                    "lanes": lanesPayload,
                ] as [String: Any]
            }
        }
    }

    private func canonicalSamplerStatePayload() -> [String: Any] {
        var result: [String: Any] = [
            "mode": "soundfont",
            "loaded": false,
            "preset": 0,
            "presetName": "",
            "wavSamplerLoaded": false,
            "wavInstrumentName": "",
            "attack": readGlobalParameter(id: .samplerAttack),
            "decay": readGlobalParameter(id: .samplerDecay),
            "sustain": readGlobalParameter(id: .samplerSustain),
            "release": readGlobalParameter(id: .samplerRelease),
            "filterCutoff": readGlobalParameter(id: .samplerFilterCutoff),
            "filterResonance": readGlobalParameter(id: .samplerFilterResonance),
            "tuning": readGlobalParameter(id: .samplerTuning),
            "level": readGlobalParameter(id: .samplerLevel),
        ]
        // Read loaded state from audioEngine on main thread
        if Thread.isMainThread {
            MainActor.assumeIsolated { [weak self] in
                guard let self, let engine = self.audioEngine else { return }
                result["mode"] = engine.activeSamplerMode == .wavSampler ? "wavsampler" : engine.activeSamplerMode == .sfz ? "sfz" : "soundfont"
                result["loaded"] = engine.soundFontLoaded
                result["preset"] = engine.soundFontCurrentPreset
                result["wavSamplerLoaded"] = engine.wavSamplerLoaded
                result["wavInstrumentName"] = engine.wavSamplerInstrumentName
                result["sfzLoaded"] = engine.sfzLoaded
                result["sfzInstrumentName"] = engine.sfzInstrumentName
                if engine.soundFontLoaded {
                    let names = engine.soundFontPresetNames
                    let idx = engine.soundFontCurrentPreset
                    result["presetName"] = idx < names.count ? names[idx] : ""
                    result["presetCount"] = names.count
                    result["filePath"] = engine.soundFontFilePath ?? ""
                }
            }
        } else {
            DispatchQueue.main.sync {
                MainActor.assumeIsolated { [weak self] in
                    guard let self, let engine = self.audioEngine else { return }
                    result["mode"] = engine.activeSamplerMode == .wavSampler ? "wavsampler" : engine.activeSamplerMode == .sfz ? "sfz" : "soundfont"
                    result["loaded"] = engine.soundFontLoaded
                    result["preset"] = engine.soundFontCurrentPreset
                    result["wavSamplerLoaded"] = engine.wavSamplerLoaded
                    result["wavInstrumentName"] = engine.wavSamplerInstrumentName
                    if engine.soundFontLoaded {
                        let names = engine.soundFontPresetNames
                        let idx = engine.soundFontCurrentPreset
                        result["presetName"] = idx < names.count ? names[idx] : ""
                        result["presetCount"] = names.count
                        result["filePath"] = engine.soundFontFilePath ?? ""
                    }
                }
            }
        }
        return result
    }

    private func canonicalTrackStatePayload(trackIndex: Int) -> [String: Any]? {
        guard let track = readTrack(trackIndex: trackIndex) else { return nil }
        var steps: [[String: Any]] = []
        for stageIndex in 0..<min(track.stages.count, 8) {
            guard let stage = readTrackStage(trackIndex: trackIndex, stage: stageIndex) else { continue }
            steps.append([
                "index": stageIndex + 1,
                "note": noteName(forNoteSlot: stage.noteSlot),
                "probability": stage.probability,
                "ratchets": stage.ratchets,
                "gateMode": stage.gateMode.rawValue.lowercased(),
                "gateLength": stage.gateLength,
                "stepType": stage.stepType.rawValue.lowercased(),
            ])
        }
        return [
            "enabled": !track.muted,
            "pattern": trackPatternName(trackIndex: trackIndex) ?? "custom",
            "rateMultiplier": track.division.multiplier,
            "clockDivision": track.division.rawValue,
            "output": track.output.rawValue.lowercased(),
            "stepGroupA": ["note": jsonOptional(readStepNoteName(trackIndex: trackIndex, stage: 0))],
            "stepGroupB": ["note": jsonOptional(readStepNoteName(trackIndex: trackIndex, stage: 4))],
            "steps": steps,
        ]
    }

    private func canonicalChordSequencerPayload() -> [String: Any] {
        let readBlock: () -> [String: Any] = { [weak self] in
            MainActor.assumeIsolated {
                guard let chordSeq = self?.chordSequencer else {
                    return ["enabled": false, "steps": [] as [[String: Any]]]
                }
                var steps: [[String: Any]] = []
                for step in chordSeq.steps {
                    var stepDict: [String: Any] = [
                        "index": step.id + 1,
                        "active": step.active,
                    ]
                    if let degId = step.degreeId {
                        stepDict["degree"] = degId
                    }
                    if let qualId = step.qualityId {
                        stepDict["quality"] = qualId
                    }
                    if !step.isEmpty {
                        stepDict["chord"] = chordSeq.chordDisplayName(for: step)
                    }
                    steps.append(stepDict)
                }
                return [
                    "enabled": chordSeq.isEnabled,
                    "clockDivision": chordSeq.division.rawValue,
                    "steps": steps,
                ] as [String: Any]
            }
        }
        if Thread.isMainThread {
            return readBlock()
        }
        var result: [String: Any] = [:]
        DispatchQueue.main.sync { result = readBlock() }
        return result
    }

    private func handleStateQuery(_ request: HTTPRequest) -> HTTPResponse {
        guard let query = tryDecode(StateQueryRequest.self, from: request.body) else {
            return errorResponse(statusCode: 400, reason: "Bad Request", code: .badRequest, message: "Invalid state query payload")
        }

        var values: [String: Any] = [:]
        for path in query.paths {
            values[path] = value(forStatePath: path) ?? NSNull()
        }

        return .json(
            statusCode: 200,
            payload: [
                "values": values,
                "stateVersion": stateVersion,
            ]
        )
    }

    private func handleHistory(_ request: HTTPRequest) -> HTTPResponse {
        guard let session = activeSession(for: request) else {
            return errorResponse(statusCode: 401, reason: "Unauthorized", code: .unauthorized, message: "Missing or invalid bearer token")
        }

        let limit = min(max(Int(request.queryItems["limit"] ?? "") ?? 100, 1), 500)
        let afterSeq = Int(request.queryItems["afterSeq"] ?? "")
        let beforeSeq = Int(request.queryItems["beforeSeq"] ?? "")
        if let afterSeq, let beforeSeq, afterSeq >= beforeSeq {
            return errorResponse(statusCode: 400, reason: "Bad Request", code: .badRequest, message: "afterSeq must be less than beforeSeq")
        }

        let includeStateChanged = boolFromQuery(request.queryItems["includeStateChanged"]) ?? true
        let requestedTypes = Set(
            (request.queryItems["types"] ?? "")
                .split(separator: ",", omittingEmptySubsequences: true)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )

        var filtered = eventHistory.filter { event in
            guard let seq = event["seq"] as? Int, let type = event["type"] as? String else {
                return false
            }
            if let afterSeq, seq <= afterSeq { return false }
            if let beforeSeq, seq >= beforeSeq { return false }
            if !includeStateChanged, type == "state.changed" { return false }
            if !requestedTypes.isEmpty, !requestedTypes.contains(type) { return false }
            if let eventSessionId = event["sessionId"] as? String, eventSessionId != session.sessionId {
                return false
            }
            return true
        }

        filtered.sort { lhs, rhs in
            let lseq = lhs["seq"] as? Int ?? 0
            let rseq = rhs["seq"] as? Int ?? 0
            return lseq > rseq
        }

        let hasMore = filtered.count > limit
        if hasMore {
            filtered.removeSubrange(limit..<filtered.count)
        }

        let activities = filtered.map(activityFromEvent)
        let newestSeq = filtered.first?["seq"] as? Int
        let oldestSeq = filtered.last?["seq"] as? Int

        return .json(
            statusCode: 200,
            payload: [
                "sessionId": session.sessionId,
                "stateVersion": stateVersion,
                "activities": activities,
                "paging": [
                    "limit": limit,
                    "returned": activities.count,
                    "hasMore": hasMore,
                    "nextBeforeSeq": hasMore ? jsonOptional(oldestSeq) : NSNull(),
                    "newestSeq": jsonOptional(newestSeq),
                    "oldestSeq": jsonOptional(oldestSeq),
                ],
                "filters": [
                    "afterSeq": jsonOptional(afterSeq),
                    "beforeSeq": jsonOptional(beforeSeq),
                    "types": Array(requestedTypes).sorted(),
                    "includeStateChanged": includeStateChanged,
                ],
            ]
        )
    }

    private func activityFromEvent(_ event: [String: Any]) -> [String: Any] {
        let type = event["type"] as? String ?? "unknown"
        let payload = event["payload"] as? [String: Any] ?? [:]
        let sessionId = event["sessionId"] as? String
        return [
            "eventId": event["eventId"] ?? NSNull(),
            "seq": event["seq"] ?? NSNull(),
            "type": type,
            "ts": event["ts"] ?? NSNull(),
            "sessionId": jsonOptional(sessionId),
            "scope": sessionId == nil ? "global" : "session",
            "stateVersion": event["stateVersion"] ?? NSNull(),
            "summary": historySummary(type: type, payload: payload),
            "payload": payload,
        ]
    }

    private func historySummary(type: String, payload: [String: Any]) -> String {
        switch type {
        case "actions.bundle_scheduled":
            let bundleId = payload["bundleId"] as? String ?? "bundle"
            return "Scheduled \(bundleId)"
        case "actions.bundle_started":
            let bundleId = payload["bundleId"] as? String ?? "bundle"
            return "Started \(bundleId)"
        case "actions.bundle_applied":
            let bundleId = payload["bundleId"] as? String ?? "bundle"
            return "Applied \(bundleId)"
        case "actions.bundle_rejected":
            let bundleId = payload["bundleId"] as? String ?? "bundle"
            return "Rejected \(bundleId)"
        case "actions.bundle_canceled":
            let bundleId = payload["bundleId"] as? String ?? "bundle"
            return "Canceled \(bundleId)"
        case "recording.started":
            let voiceId = payload["voiceId"] as? String ?? "voice"
            return "Recording started on \(voiceId)"
        case "recording.stopped":
            let voiceId = payload["voiceId"] as? String ?? "voice"
            return "Recording stopped on \(voiceId)"
        case "recording.mode_changed":
            let voiceId = payload["voiceId"] as? String ?? "voice"
            return "Recording mode changed on \(voiceId)"
        case "recording.feedback_changed":
            let voiceId = payload["voiceId"] as? String ?? "voice"
            return "Recording feedback changed on \(voiceId)"
        case "session.key_changed":
            return "Session key changed"
        case "sequencer.track_updated":
            let track = payload["track"] as? Int ?? 0
            let field = payload["field"] as? String ?? "field"
            return "Track \(track) \(field) updated"
        case "sequencer.step_updated":
            let track = payload["track"] as? Int ?? 0
            let step = payload["step"] as? Int ?? 0
            let field = payload["field"] as? String ?? "field"
            return "Track \(track) step \(step) \(field) updated"
        case "synth.mode_changed":
            let synth = payload["synth"] as? String ?? "synth"
            return "\(synth) mode changed"
        case "granular.param_changed":
            let path = payload["path"] as? String ?? "param"
            return "\(path) updated"
        case "transport.playing_changed":
            let playing = payload["playing"] as? Bool ?? false
            return playing ? "Transport started" : "Transport stopped"
        case "state.changed":
            if let changedPaths = payload["changedPaths"] as? [String], !changedPaths.isEmpty {
                return "State updated (\(changedPaths.count) path\(changedPaths.count == 1 ? "" : "s"))"
            }
            return "State updated"
        default:
            return type
        }
    }

    private func boolFromQuery(_ text: String?) -> Bool? {
        guard let text else { return nil }
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "true", "1", "yes", "on":
            return true
        case "false", "0", "no", "off":
            return false
        default:
            return nil
        }
    }

    private struct ActionFailure {
        let actionId: String?
        let code: BridgeErrorCode
        let message: String
    }

    private struct BundleExecutionResult {
        let appliedCount: Int
        let failures: [ActionFailure]
        let risk: String
        let finalStatus: String
    }

    private struct SimulatedRecordingState {
        var active: Bool
        var mode: AudioEngineWrapper.RecordMode
        var feedback: Float
    }

    private func handleValidateActions(_ request: HTTPRequest) -> HTTPResponse {
        guard let payload = tryDecode(ValidateActionsRequest.self, from: request.body) else {
            return errorResponse(statusCode: 400, reason: "Bad Request", code: .badRequest, message: "Invalid validate actions payload")
        }

        purgeExpiredValidationRecords()
        let validation = validateBundle(payload.bundle, policy: payload.policy)
        let valid = validation.failures.isEmpty
        let validationId = "val_" + UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(8)
        let confirmationToken: String? = validation.requiresConfirmation ? UUID().uuidString.replacingOccurrences(of: "-", with: "") : nil
        let confirmationExpiry = confirmationToken == nil ? nil : Date().addingTimeInterval(120)

        let record = ValidationRecord(
            validationId: String(validationId),
            bundleSignature: bundleSignatureForValidation(payload.bundle),
            isValid: valid,
            risk: validation.risk,
            requiresConfirmation: validation.requiresConfirmation,
            confirmationToken: confirmationToken,
            confirmationTokenExpiresAt: confirmationExpiry,
            expiresAt: Date().addingTimeInterval(300)
        )
        validationsById[record.validationId] = record

        let responsePayload: [String: Any] = [
            "valid": valid,
            "validationId": record.validationId,
            "risk": validation.risk,
            "requiresConfirmation": validation.requiresConfirmation,
            "confirmationToken": jsonOptional(confirmationToken),
            "confirmationTokenExpiresAt": jsonOptional(confirmationExpiry.map(iso8601)),
            "normalizedBundle": bundleToJSONObject(payload.bundle),
            "musicalDiff": musicalDiff(bundle: payload.bundle, risk: validation.risk),
            "errors": validation.failures.map { failure in
                [
                    "actionId": jsonOptional(failure.actionId),
                    "code": failure.code.rawValue,
                    "message": failure.message,
                ]
            },
        ]

        return .json(statusCode: 200, payload: responsePayload)
    }

    private func handleScheduleActions(_ request: HTTPRequest) -> HTTPResponse {
        guard let payload = tryDecode(ScheduleActionsRequest.self, from: request.body) else {
            return errorResponse(statusCode: 400, reason: "Bad Request", code: .badRequest, message: "Invalid schedule actions payload")
        }

        purgeExpiredValidationRecords()
        if let replay = idempotencyReplayIfPresent(key: payload.idempotencyKey, request: request, setReplayFlag: true) {
            return replay
        }

        if let preconditionStateVersion = payload.bundle.preconditionStateVersion, preconditionStateVersion != stateVersion {
            return errorResponse(
                statusCode: 409,
                reason: "Conflict",
                code: .staleStateVersion,
                message: "preconditionStateVersion does not match current state",
                details: [
                    "provided": preconditionStateVersion,
                    "current": stateVersion,
                ]
            )
        }

        if payload.applyMode == "validated_only" {
            guard let validationId = payload.bundle.validationId, let validationRecord = validationsById[validationId] else {
                return errorResponse(statusCode: 422, reason: "Unprocessable Entity", code: .badRequest, message: "validationId is required for validated_only applyMode")
            }
            if validationRecord.bundleSignature != bundleSignatureForValidation(payload.bundle) {
                return errorResponse(statusCode: 422, reason: "Unprocessable Entity", code: .badRequest, message: "Validation record does not match bundle payload")
            }
            if !validationRecord.isValid {
                return errorResponse(statusCode: 422, reason: "Unprocessable Entity", code: .badRequest, message: "Bundle must be revalidated after validation errors")
            }
            if validationRecord.expiresAt < Date() {
                validationsById[validationId] = nil
                return errorResponse(statusCode: 422, reason: "Unprocessable Entity", code: .badRequest, message: "Validation record expired")
            }
            if validationRecord.requiresConfirmation {
                guard let suppliedToken = payload.confirmationToken,
                      let recordToken = validationRecord.confirmationToken,
                      suppliedToken == recordToken,
                      let tokenExpiry = validationRecord.confirmationTokenExpiresAt,
                      tokenExpiry >= Date() else {
                    return errorResponse(statusCode: 422, reason: "Unprocessable Entity", code: .confirmationTokenExpired, message: "Missing or expired confirmationToken")
                }
            }
        }

        let bestEffort = payload.applyMode == "best_effort"
        let scheduledTime = resolveScheduledTime(timeSpec: bundlePrimaryTimeSpec(payload.bundle))

        let stored = ScheduledBundleState(
            bundleId: payload.bundle.bundleId,
            intentId: payload.bundle.intentId,
            scheduledBar: scheduledTime.bar,
            scheduledBeat: scheduledTime.beat,
            status: "scheduled",
            stateVersion: stateVersion,
            errorCodes: [],
            createdAt: Date()
        )
        scheduledBundles[payload.bundle.bundleId] = stored

        emitEvent(
            type: "actions.bundle_scheduled",
            payload: [
                "bundleId": payload.bundle.bundleId,
                "status": "scheduled",
                "scheduledAtTransport": [
                    "bar": scheduledTime.bar,
                    "beat": scheduledTime.beat,
                ],
            ]
        )

        let bundleId = payload.bundle.bundleId
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard var current = self.scheduledBundles[bundleId], current.status != "canceled" else {
                self.scheduledWorkItems[bundleId] = nil
                return
            }

            current.status = "in_progress"
            self.scheduledBundles[bundleId] = current
            self.emitEvent(type: "actions.bundle_started", payload: ["bundleId": bundleId, "status": "in_progress"])

            let execution = self.executeBundle(payload.bundle, bestEffort: bestEffort)
            let finalStatus: String
            switch execution.finalStatus {
            case "rejected":
                finalStatus = "rejected"
            case "partially_applied":
                finalStatus = "partially_applied"
            default:
                finalStatus = "applied"
            }

            current.status = finalStatus
            current.stateVersion = self.stateVersion
            current.errorCodes = execution.failures.map(\.code.rawValue)
            self.scheduledBundles[bundleId] = current

            let eventType = finalStatus == "rejected" ? "actions.bundle_rejected" : "actions.bundle_applied"
            self.emitEvent(
                type: eventType,
                payload: [
                    "bundleId": bundleId,
                    "status": finalStatus,
                    "risk": execution.risk,
                    "errors": execution.failures.map { failure in
                        [
                            "actionId": self.jsonOptional(failure.actionId),
                            "code": failure.code.rawValue,
                            "message": failure.message,
                        ]
                    },
                ]
            )
            self.scheduledWorkItems[bundleId] = nil
        }
        scheduledWorkItems[bundleId] = workItem

        let delay = max(0.0, scheduledTime.executeAt.timeIntervalSinceNow)
        if delay <= 0.005 {
            queue.async(execute: workItem)
        } else {
            queue.asyncAfter(deadline: .now() + delay, execute: workItem)
        }

        let responsePayload: [String: Any] = [
            "bundleId": payload.bundle.bundleId,
            "status": "scheduled",
            "idempotentReplay": false,
            "scheduledAtTransport": [
                "bar": scheduledTime.bar,
                "beat": scheduledTime.beat,
            ],
            "stateVersion": stateVersion,
            "resultStatus": "scheduled",
            "errors": [],
        ]
        let response = HTTPResponse.json(statusCode: 202, reason: "Accepted", payload: responsePayload)
        recordIdempotency(key: payload.idempotencyKey, request: request, response: response)
        return response
    }

    private func handleListScheduledActions() -> HTTPResponse {
        let bundles = scheduledBundles.values.sorted { $0.createdAt < $1.createdAt }
        let payload: [[String: Any]] = bundles.map { bundle in
            [
                "bundleId": bundle.bundleId,
                "intentId": jsonOptional(bundle.intentId),
                "status": bundle.status,
                "scheduledAtTransport": [
                    "bar": bundle.scheduledBar,
                    "beat": bundle.scheduledBeat,
                ],
                "stateVersion": bundle.stateVersion,
                "errors": bundle.errorCodes,
            ]
        }
        return .json(statusCode: 200, payload: payload)
    }

    private func handleCancelScheduledAction(_ request: HTTPRequest) -> HTTPResponse {
        let prefix = "/v1/actions/"
        let suffix = "/cancel"
        guard request.path.hasPrefix(prefix), request.path.hasSuffix(suffix) else {
            return errorResponse(statusCode: 404, reason: "Not Found", code: .notFound, message: "Unknown bundle path")
        }
        let bundleId = String(request.path.dropFirst(prefix.count).dropLast(suffix.count))
        guard var existing = scheduledBundles[bundleId] else {
            return errorResponse(statusCode: 404, reason: "Not Found", code: .notFound, message: "Bundle not found")
        }
        existing.status = "canceled"
        scheduledBundles[bundleId] = existing
        if let workItem = scheduledWorkItems.removeValue(forKey: bundleId) {
            workItem.cancel()
        }
        emitEvent(type: "actions.bundle_canceled", payload: ["bundleId": bundleId, "status": "canceled"])
        return .json(statusCode: 200, payload: ["bundleId": bundleId, "status": "canceled"])
    }

    private func validateBundle(_ bundle: ActionBundleRequest, policy: PolicyRequest?) -> (failures: [ActionFailure], risk: String, requiresConfirmation: Bool) {
        var simState = simulatedVoiceState()
        var failures: [ActionFailure] = []
        var risk = "low"

        if bundle.actions.isEmpty {
            failures.append(ActionFailure(actionId: nil, code: .badRequest, message: "Bundle actions cannot be empty"))
        }

        for action in bundle.actions {
            let actionRisk = riskForActionType(normalizedActionType(action))
            if riskRank(actionRisk) > riskRank(risk) {
                risk = actionRisk
            }
            if let failure = validateAction(action, simState: &simState, allowRecording: policy?.allowRecording ?? true) {
                failures.append(failure)
            }
        }

        if let maxRisk = policy?.maxRisk, riskRank(risk) > riskRank(maxRisk) {
            failures.append(ActionFailure(actionId: nil, code: .riskExceedsPolicy, message: "Bundle risk exceeds policy maxRisk"))
        }

        let requiresConfirmation = risk == "high"
        return (failures, risk, requiresConfirmation)
    }

    private func executeBundle(_ bundle: ActionBundleRequest, bestEffort: Bool) -> BundleExecutionResult {
        var simState = simulatedVoiceState()
        var failures: [ActionFailure] = []
        var risk = "low"
        var appliedCount = 0

        if bundle.atomic {
            var precheckFailures: [ActionFailure] = []
            for action in bundle.actions {
                let actionRisk = riskForActionType(normalizedActionType(action))
                if riskRank(actionRisk) > riskRank(risk) {
                    risk = actionRisk
                }
                if let failure = validateAction(action, simState: &simState, allowRecording: true) {
                    precheckFailures.append(failure)
                }
            }
            if !precheckFailures.isEmpty {
                return BundleExecutionResult(appliedCount: 0, failures: precheckFailures, risk: risk, finalStatus: "rejected")
            }
        }

        simState = simulatedVoiceState()
        for action in bundle.actions {
            let actionRisk = riskForActionType(normalizedActionType(action))
            if riskRank(actionRisk) > riskRank(risk) {
                risk = actionRisk
            }
            if let failure = applyAction(action, simState: &simState) {
                failures.append(failure)
                if bundle.atomic || !bestEffort {
                    return BundleExecutionResult(appliedCount: appliedCount, failures: failures, risk: risk, finalStatus: "rejected")
                }
                continue
            }
            appliedCount += 1
        }

        if failures.isEmpty {
            return BundleExecutionResult(appliedCount: appliedCount, failures: [], risk: risk, finalStatus: "applied")
        }
        return BundleExecutionResult(appliedCount: appliedCount, failures: failures, risk: risk, finalStatus: "partially_applied")
    }

    private func validateAction(_ action: ActionRequest, simState: inout [String: SimulatedRecordingState], allowRecording: Bool) -> ActionFailure? {
        let actionType = normalizedActionType(action)
        if !isRecordingActionType(actionType) {
            let nonRecording = validateNonRecordingAction(action)
            if nonRecording.handled {
                return nonRecording.failure
            }
            return ActionFailure(actionId: action.actionId, code: .badRequest, message: "Unknown or missing action target")
        }

        guard let voice = resolveVoiceTarget(fromActionTarget: action.target) else {
            return ActionFailure(actionId: action.actionId, code: .badRequest, message: "Unknown or missing action target")
        }

        if !allowRecording, isRecordingActionType(actionType) {
            return ActionFailure(actionId: action.actionId, code: .badRequest, message: "Recording actions are not allowed by policy")
        }

        var current = simState[voice.id] ?? simulatedStateForVoice(voice)
        switch actionType {
        case "startRecording":
            guard !current.active else {
                return ActionFailure(actionId: action.actionId, code: .recordingAlreadyActive, message: "Voice is already recording")
            }
            if let modeText = modeTextFromAction(action), mapRecordMode(apiMode: modeText) == nil {
                return ActionFailure(actionId: action.actionId, code: .recordingModeUnsupported, message: "Unsupported recording mode")
            }
            current.active = true
            if let modeText = modeTextFromAction(action), let mode = mapRecordMode(apiMode: modeText) {
                current.mode = mode
            }
            simState[voice.id] = current
            return nil
        case "stopRecording":
            guard current.active else {
                return ActionFailure(actionId: action.actionId, code: .recordingNotActive, message: "Voice is not recording")
            }
            current.active = false
            simState[voice.id] = current
            return nil
        case "setRecordingFeedback":
            guard let value = feedbackValueFromAction(action) else {
                return ActionFailure(actionId: action.actionId, code: .badRequest, message: "Missing feedback value")
            }
            guard value >= 0.0, value <= 1.0 else {
                return ActionFailure(actionId: action.actionId, code: .actionOutOfRange, message: "Feedback must be within [0.0, 1.0]")
            }
            guard current.mode == .liveLoop else {
                return ActionFailure(actionId: action.actionId, code: .recordingFeedbackUnsupported, message: "Feedback is only supported in overdub/live modes")
            }
            current.feedback = Float(value)
            simState[voice.id] = current
            return nil
        case "setRecordingMode":
            guard let modeText = modeTextFromAction(action), let mode = mapRecordMode(apiMode: modeText) else {
                return ActionFailure(actionId: action.actionId, code: .recordingModeUnsupported, message: "Unsupported recording mode")
            }
            current.mode = mode
            simState[voice.id] = current
            return nil
        default:
            return ActionFailure(actionId: action.actionId, code: .actionTypeUnsupported, message: "Action type is not implemented")
        }
    }

    private func applyAction(_ action: ActionRequest, simState: inout [String: SimulatedRecordingState]) -> ActionFailure? {
        if let validationFailure = validateAction(action, simState: &simState, allowRecording: true) {
            return validationFailure
        }

        let actionType = normalizedActionType(action)
        if !isRecordingActionType(actionType) {
            let nonRecording = applyNonRecordingAction(action)
            if nonRecording.handled {
                return nonRecording.failure
            }
            return ActionFailure(actionId: action.actionId, code: .badRequest, message: "Unknown or missing action target")
        }

        guard let voice = resolveVoiceTarget(fromActionTarget: action.target) else {
            return ActionFailure(actionId: action.actionId, code: .badRequest, message: "Unknown or missing action target")
        }

        switch actionType {
        case "startRecording":
            let mode = simState[voice.id]?.mode ?? voice.defaultMode
            let feedback = simState[voice.id]?.feedback
            writeStartRecording(
                reelIndex: voice.reelIndex,
                mode: mode,
                sourceType: .external,
                sourceChannel: 0,
                feedback: feedback.map(Double.init)
            )
            recordMutation(
                changedPaths: [
                    "\(voice.id).recording.active",
                    "\(voice.id).recording.mode",
                    "\(voice.id).recording.feedback",
                ],
                additionalEvents: [
                    (
                        type: "recording.started",
                        payload: [
                            "voiceId": voice.id,
                            "mode": apiMode(from: mode),
                            "feedback": feedback ?? voice.defaultFeedback,
                        ]
                    ),
                ]
            )
            return nil
        case "stopRecording":
            writeStopRecording(reelIndex: voice.reelIndex)
            recordMutation(
                changedPaths: ["\(voice.id).recording.active"],
                additionalEvents: [
                    (
                        type: "recording.stopped",
                        payload: [
                            "voiceId": voice.id,
                            "recordedDurationMs": NSNull(),
                        ]
                    ),
                ]
            )
            return nil
        case "setRecordingFeedback":
            let value = simState[voice.id]?.feedback ?? voice.defaultFeedback
            let before = readRecordingModeAndFeedback(
                reelIndex: voice.reelIndex,
                defaultMode: voice.defaultMode,
                defaultFeedback: voice.defaultFeedback
            ).feedback
            writeSetRecordingFeedback(reelIndex: voice.reelIndex, feedback: value)
            recordMutation(
                changedPaths: ["\(voice.id).recording.feedback"],
                additionalEvents: [
                    (
                        type: "recording.feedback_changed",
                        payload: [
                            "voiceId": voice.id,
                            "previous": before,
                            "current": value,
                        ]
                    ),
                ]
            )
            return nil
        case "setRecordingMode":
            let mode = simState[voice.id]?.mode ?? voice.defaultMode
            let before = currentRecordMode(for: voice)
            guard before != mode else {
                return nil
            }
            writeSetRecordingMode(reelIndex: voice.reelIndex, mode: mode)
            recordMutation(
                changedPaths: ["\(voice.id).recording.mode"],
                additionalEvents: [
                    (
                        type: "recording.mode_changed",
                        payload: [
                            "voiceId": voice.id,
                            "previous": apiMode(from: before),
                            "current": apiMode(from: mode),
                        ]
                    ),
                ]
            )
            return nil
        default:
            return ActionFailure(actionId: action.actionId, code: .actionTypeUnsupported, message: "Action type is not implemented")
        }
    }

    private func validateNonRecordingAction(_ action: ActionRequest) -> (handled: Bool, failure: ActionFailure?) {
        guard let target = action.target else {
            return (false, nil)
        }
        guard action.type == "set" || action.type == "toggle" else {
            return (true, ActionFailure(actionId: action.actionId, code: .actionTypeUnsupported, message: "Only set/toggle are supported for this target"))
        }

        if let granular = parseGranularVoiceTarget(target) {
            switch granular.property {
            case "playing":
                if action.type == "toggle" || boolValueFromAction(action) != nil {
                    return (true, nil)
                }
                return (true, ActionFailure(actionId: action.actionId, code: .badRequest, message: "granular playing requires boolean value"))
            case "speedRatio":
                guard let ratio = feedbackValueFromAction(action), ratio >= 0.0 else {
                    return (true, ActionFailure(actionId: action.actionId, code: .badRequest, message: "granular speedRatio requires non-negative number"))
                }
                return (true, nil)
            case "sizeMs":
                guard let ms = feedbackValueFromAction(action), ms > 0, ms <= 2500.0 else {
                    return (true, ActionFailure(actionId: action.actionId, code: .badRequest, message: "granular sizeMs must be > 0 and <= 2500"))
                }
                return (true, nil)
            case "pitchSemitones":
                guard let semitones = feedbackValueFromAction(action), semitones >= -24.0, semitones <= 24.0 else {
                    return (true, ActionFailure(actionId: action.actionId, code: .actionOutOfRange, message: "granular pitchSemitones must be within [-24, 24]"))
                }
                return (true, nil)
            case "envelope":
                guard envelopeIndexFromAction(action) != nil else {
                    return (true, ActionFailure(actionId: action.actionId, code: .badRequest, message: "Unsupported granular envelope"))
                }
                return (true, nil)
            case "filterCutoff":
                guard let cutoff = feedbackValueFromAction(action), cutoff >= 0.0, cutoff <= 1.0 else {
                    return (true, ActionFailure(actionId: action.actionId, code: .actionOutOfRange, message: "granular filterCutoff must be within [0, 1]"))
                }
                return (true, nil)
            case "filterResonance":
                guard let resonance = feedbackValueFromAction(action), resonance >= 0.0, resonance <= 1.0 else {
                    return (true, ActionFailure(actionId: action.actionId, code: .actionOutOfRange, message: "granular filterResonance must be within [0, 1]"))
                }
                return (true, nil)
            case "morph":
                guard let morph = feedbackValueFromAction(action), morph >= 0.0, morph <= 1.0 else {
                    return (true, ActionFailure(actionId: action.actionId, code: .actionOutOfRange, message: "granular morph must be within [0, 1]"))
                }
                return (true, nil)
            default:
                return (true, ActionFailure(actionId: action.actionId, code: .notFound, message: "Unsupported granular target"))
            }
        }

        if target == "transport.playing" {
            if action.type == "toggle" || boolValueFromAction(action) != nil {
                return (true, nil)
            }
            return (true, ActionFailure(actionId: action.actionId, code: .badRequest, message: "transport.playing requires a boolean value"))
        }

        if target == "session.key" {
            guard let keyText = modeTextFromAction(action), parseSessionKeyDescriptor(keyText) != nil else {
                return (true, ActionFailure(actionId: action.actionId, code: .badRequest, message: "session.key requires value like 'F minor pentatonic'"))
            }
            return (true, nil)
        }

        if target == "session.tempoBpm" {
            guard let bpm = feedbackValueFromAction(action), bpm >= 20.0, bpm <= 300.0 else {
                return (true, ActionFailure(actionId: action.actionId, code: .actionOutOfRange, message: "session.tempoBpm must be a number between 20 and 300"))
            }
            return (true, nil)
        }

        if target == "synth.plaits.mode" || target == "synth.macro_osc.mode" {
            guard let mode = modeTextFromAction(action), plaitsModelNormalized(modeText: mode) != nil else {
                return (true, ActionFailure(actionId: action.actionId, code: .badRequest, message: "Unsupported plaits mode"))
            }
            return (true, nil)
        }

        if target == "synth.rings.mode" || target == "synth.resonator.mode" {
            guard let mode = modeTextFromAction(action), ringsModelNormalized(modeText: mode) != nil else {
                return (true, ActionFailure(actionId: action.actionId, code: .badRequest, message: "Unsupported rings mode"))
            }
            return (true, nil)
        }

        // Macro Osc / Plaits continuous parameters (accept both path prefixes)
        let plaitsContParams: Set<String> = [
            "synth.macro_osc.harmonics", "synth.macro_osc.timbre", "synth.macro_osc.morph", "synth.macro_osc.level",
            "synth.macro_osc.lpgColor", "synth.macro_osc.lpgDecay", "synth.macro_osc.lpgAttack", "synth.macro_osc.lpgBypass",
            "synth.plaits.harmonics", "synth.plaits.timbre", "synth.plaits.morph", "synth.plaits.level",
            "synth.plaits.lpgColor", "synth.plaits.lpgDecay", "synth.plaits.lpgAttack", "synth.plaits.lpgBypass",
        ]
        if plaitsContParams.contains(target) {
            guard let value = feedbackValueFromAction(action), value >= 0.0, value <= 1.0 else {
                return (true, ActionFailure(actionId: action.actionId, code: .actionOutOfRange, message: "Macro Osc \(target.split(separator: ".").last ?? "") must be within [0.0, 1.0]"))
            }
            return (true, nil)
        }

        // Resonator / Rings continuous parameters (accept both path prefixes)
        let ringsContParams: Set<String> = [
            "synth.resonator.structure", "synth.resonator.brightness", "synth.resonator.damping", "synth.resonator.position", "synth.resonator.level",
            "synth.rings.structure", "synth.rings.brightness", "synth.rings.damping", "synth.rings.position", "synth.rings.level",
        ]
        if ringsContParams.contains(target) {
            guard let value = feedbackValueFromAction(action), value >= 0.0, value <= 1.0 else {
                return (true, ActionFailure(actionId: action.actionId, code: .actionOutOfRange, message: "Resonator \(target.split(separator: ".").last ?? "") must be within [0.0, 1.0]"))
            }
            return (true, nil)
        }

        if target == "synth.daisydrum.mode" {
            guard let mode = modeTextFromAction(action), daisyDrumModelNormalized(modeText: mode) != nil else {
                return (true, ActionFailure(actionId: action.actionId, code: .badRequest, message: "Unsupported daisydrum mode"))
            }
            return (true, nil)
        }

        if target == "synth.daisydrum.harmonics" || target == "synth.daisydrum.timbre" || target == "synth.daisydrum.morph" {
            guard let value = feedbackValueFromAction(action), value >= 0.0, value <= 1.0 else {
                return (true, ActionFailure(actionId: action.actionId, code: .actionOutOfRange, message: "DaisyDrum parameter must be within [0.0, 1.0]"))
            }
            return (true, nil)
        }

        // Sampler targets
        if target == "synth.sampler.mode" {
            guard let value = modeTextFromAction(action),
                  value == "soundfont" || value == "sfz" || value == "wavsampler" else {
                return (true, ActionFailure(actionId: action.actionId, code: .actionOutOfRange, message: "Sampler mode must be \"soundfont\", \"sfz\", or \"wavsampler\""))
            }
            return (true, nil)
        }

        if target == "synth.sampler.preset" {
            guard let value = feedbackValueFromAction(action), value >= 0.0, value <= 1.0 else {
                return (true, ActionFailure(actionId: action.actionId, code: .actionOutOfRange, message: "Sampler preset must be within [0.0, 1.0] (normalized)"))
            }
            return (true, nil)
        }

        if target == "synth.sampler.attack" || target == "synth.sampler.decay" ||
           target == "synth.sampler.sustain" || target == "synth.sampler.release" ||
           target == "synth.sampler.filterCutoff" || target == "synth.sampler.filterResonance" ||
           target == "synth.sampler.level" {
            guard let value = feedbackValueFromAction(action), value >= 0.0, value <= 1.0 else {
                return (true, ActionFailure(actionId: action.actionId, code: .actionOutOfRange, message: "Sampler parameter must be within [0.0, 1.0]"))
            }
            return (true, nil)
        }

        if target == "synth.sampler.tuning" {
            guard let value = feedbackValueFromAction(action), value >= 0.0, value <= 1.0 else {
                return (true, ActionFailure(actionId: action.actionId, code: .actionOutOfRange, message: "Sampler tuning must be within [0.0, 1.0] (0.5 = center)"))
            }
            return (true, nil)
        }

        // Chord sequencer targets — allow through validation; applyChordSequencerAction handles details
        if target.hasPrefix("sequencer.chords") {
            return (true, nil)
        }

        // Drum sequencer targets
        if let drumTarget = parseDrumSequencerTarget(target) {
            return validateDrumSequencerAction(action, target: drumTarget)
        }

        guard let trackTarget = parseSequencerTrackTarget(target) else {
            return (false, nil)
        }
        if trackTarget.trackIndex < 0 || trackTarget.trackIndex > 1 {
            return (true, ActionFailure(actionId: action.actionId, code: .badRequest, message: "Track index out of range"))
        }

        if let stepProperty = parseSequencerStepProperty(trackTarget.property) {
            switch stepProperty.field {
            case "note":
                guard let noteText = modeTextFromAction(action), parsePitchClass(noteText) != nil else {
                    return (true, ActionFailure(actionId: action.actionId, code: .badRequest, message: "Invalid step note"))
                }
                return (true, nil)
            case "probability":
                guard let probability = feedbackValueFromAction(action), probability >= 0.0, probability <= 1.0 else {
                    return (true, ActionFailure(actionId: action.actionId, code: .actionOutOfRange, message: "Step probability must be within [0.0, 1.0]"))
                }
                return (true, nil)
            case "ratchets":
                guard let ratchets = feedbackValueFromAction(action) else {
                    return (true, ActionFailure(actionId: action.actionId, code: .badRequest, message: "Step ratchets requires numeric value"))
                }
                let rounded = Int(ratchets.rounded())
                guard (1...8).contains(rounded) else {
                    return (true, ActionFailure(actionId: action.actionId, code: .actionOutOfRange, message: "Step ratchets must be within [1, 8]"))
                }
                return (true, nil)
            case "gateMode":
                guard let text = modeTextFromAction(action), gateModeFromText(text) != nil else {
                    return (true, ActionFailure(actionId: action.actionId, code: .badRequest, message: "Unsupported step gateMode"))
                }
                return (true, nil)
            case "gateLength":
                guard let gl = feedbackValueFromAction(action), gl >= 0.01, gl <= 1.0 else {
                    return (true, ActionFailure(actionId: action.actionId, code: .actionOutOfRange, message: "Step gateLength must be within [0.01, 1.0]"))
                }
                return (true, nil)
            case "stepType":
                guard let text = modeTextFromAction(action), stepTypeFromText(text) != nil else {
                    return (true, ActionFailure(actionId: action.actionId, code: .badRequest, message: "Unsupported step stepType"))
                }
                return (true, nil)
            default:
                return (true, ActionFailure(actionId: action.actionId, code: .notFound, message: "Unsupported step target field"))
            }
        }

        switch trackTarget.property {
        case "enabled":
            if action.type == "toggle" || boolValueFromAction(action) != nil {
                return (true, nil)
            }
            return (true, ActionFailure(actionId: action.actionId, code: .badRequest, message: "track enabled requires boolean value"))
        case "pattern":
            guard let pattern = modeTextFromAction(action), pattern.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "ascending" else {
                return (true, ActionFailure(actionId: action.actionId, code: .badRequest, message: "Only 'ascending' pattern is currently supported"))
            }
            return (true, nil)
        case "rateMultiplier":
            guard let multiplier = feedbackValueFromAction(action), divisionForRateMultiplier(multiplier) != nil else {
                return (true, ActionFailure(actionId: action.actionId, code: .badRequest, message: "Unsupported rateMultiplier"))
            }
            return (true, nil)
        case "clockDivision":
            guard let division = modeTextFromAction(action), divisionFromText(division) != nil else {
                return (true, ActionFailure(actionId: action.actionId, code: .badRequest, message: "Unsupported clockDivision"))
            }
            return (true, nil)
        case "output":
            guard let output = modeTextFromAction(action), trackOutputFromText(output) != nil else {
                return (true, ActionFailure(actionId: action.actionId, code: .badRequest, message: "Unsupported track output"))
            }
            return (true, nil)
        case "stepGroupA.note", "stepGroupB.note":
            guard let noteText = modeTextFromAction(action), parsePitchClass(noteText) != nil else {
                return (true, ActionFailure(actionId: action.actionId, code: .badRequest, message: "Invalid note name"))
            }
            return (true, nil)
        default:
            return (true, ActionFailure(actionId: action.actionId, code: .notFound, message: "Unsupported sequencer target"))
        }
    }

    private func applyNonRecordingAction(_ action: ActionRequest) -> (handled: Bool, failure: ActionFailure?) {
        guard let target = action.target else {
            return (false, nil)
        }

        if let granular = parseGranularVoiceTarget(target) {
            switch granular.property {
            case "playing":
                let current = false
                guard let desired = desiredBoolValue(for: action, current: current) else {
                    return (true, ActionFailure(actionId: action.actionId, code: .badRequest, message: "granular playing requires boolean value"))
                }
                writeGranularPlaying(voiceIndex: granular.voice.reelIndex, playing: desired)
                recordMutation(
                    changedPaths: ["\(granular.voice.id).playing"],
                    additionalEvents: [
                        (
                            type: "granular.param_changed",
                            payload: [
                                "voiceId": granular.voice.id,
                                "path": "\(granular.voice.id).playing",
                                "value": desired,
                            ]
                        ),
                    ]
                )
                return (true, nil)
            case "speedRatio":
                guard let ratio = feedbackValueFromAction(action), ratio >= 0.0 else {
                    return (true, ActionFailure(actionId: action.actionId, code: .badRequest, message: "granular speedRatio requires non-negative number"))
                }
                let normalized = clamp01(0.5 + (ratio / 4.0))
                writeGranularParameter(id: .granularSpeed, value: Float(normalized), voiceIndex: granular.voice.reelIndex)
                recordMutation(
                    changedPaths: ["\(granular.voice.id).speedRatio"],
                    additionalEvents: [
                        (
                            type: "granular.param_changed",
                            payload: [
                                "voiceId": granular.voice.id,
                                "path": "\(granular.voice.id).speedRatio",
                                "value": ratio,
                            ]
                        ),
                    ]
                )
                return (true, nil)
            case "sizeMs":
                guard let ms = feedbackValueFromAction(action), ms > 0, ms <= 2500.0 else {
                    return (true, ActionFailure(actionId: action.actionId, code: .badRequest, message: "granular sizeMs must be > 0 and <= 2500"))
                }
                let normalized = clamp01(ms / 2500.0)  // Linear: 0-2500ms
                writeGranularParameter(id: .granularSize, value: Float(normalized), voiceIndex: granular.voice.reelIndex)
                recordMutation(
                    changedPaths: ["\(granular.voice.id).sizeMs"],
                    additionalEvents: [
                        (
                            type: "granular.param_changed",
                            payload: [
                                "voiceId": granular.voice.id,
                                "path": "\(granular.voice.id).sizeMs",
                                "value": ms,
                            ]
                        ),
                    ]
                )
                return (true, nil)
            case "pitchSemitones":
                guard let semitones = feedbackValueFromAction(action), semitones >= -24.0, semitones <= 24.0 else {
                    return (true, ActionFailure(actionId: action.actionId, code: .actionOutOfRange, message: "granular pitchSemitones must be within [-24, 24]"))
                }
                let normalized = clamp01((semitones + 24.0) / 48.0)
                writeGranularParameter(id: .granularPitch, value: Float(normalized), voiceIndex: granular.voice.reelIndex)
                recordMutation(
                    changedPaths: ["\(granular.voice.id).pitchSemitones"],
                    additionalEvents: [
                        (
                            type: "granular.param_changed",
                            payload: [
                                "voiceId": granular.voice.id,
                                "path": "\(granular.voice.id).pitchSemitones",
                                "value": semitones,
                            ]
                        ),
                    ]
                )
                return (true, nil)
            case "envelope":
                guard let envelopeIndex = envelopeIndexFromAction(action) else {
                    return (true, ActionFailure(actionId: action.actionId, code: .badRequest, message: "Unsupported granular envelope"))
                }
                writeGranularParameter(id: .granularEnvelope, value: Float(envelopeIndex) / 7.0, voiceIndex: granular.voice.reelIndex)
                recordMutation(
                    changedPaths: ["\(granular.voice.id).envelope"],
                    additionalEvents: [
                        (
                            type: "granular.param_changed",
                            payload: [
                                "voiceId": granular.voice.id,
                                "path": "\(granular.voice.id).envelope",
                                "value": granularEnvelopeName(from: Float(envelopeIndex) / 7.0),
                            ]
                        ),
                    ]
                )
                return (true, nil)
            case "filterCutoff":
                guard let cutoff = feedbackValueFromAction(action), cutoff >= 0.0, cutoff <= 1.0 else {
                    return (true, ActionFailure(actionId: action.actionId, code: .actionOutOfRange, message: "granular filterCutoff must be within [0, 1]"))
                }
                writeGranularParameter(id: .granularFilterCutoff, value: Float(cutoff), voiceIndex: granular.voice.reelIndex)
                recordMutation(
                    changedPaths: ["\(granular.voice.id).filterCutoff"],
                    additionalEvents: [
                        (
                            type: "granular.param_changed",
                            payload: [
                                "voiceId": granular.voice.id,
                                "path": "\(granular.voice.id).filterCutoff",
                                "value": cutoff,
                            ]
                        ),
                    ]
                )
                return (true, nil)
            case "filterResonance":
                guard let resonance = feedbackValueFromAction(action), resonance >= 0.0, resonance <= 1.0 else {
                    return (true, ActionFailure(actionId: action.actionId, code: .actionOutOfRange, message: "granular filterResonance must be within [0, 1]"))
                }
                writeGranularParameter(id: .granularFilterResonance, value: Float(resonance), voiceIndex: granular.voice.reelIndex)
                recordMutation(
                    changedPaths: ["\(granular.voice.id).filterResonance"],
                    additionalEvents: [
                        (
                            type: "granular.param_changed",
                            payload: [
                                "voiceId": granular.voice.id,
                                "path": "\(granular.voice.id).filterResonance",
                                "value": resonance,
                            ]
                        ),
                    ]
                )
                return (true, nil)
            case "morph":
                guard let morph = feedbackValueFromAction(action), morph >= 0.0, morph <= 1.0 else {
                    return (true, ActionFailure(actionId: action.actionId, code: .actionOutOfRange, message: "granular morph must be within [0, 1]"))
                }
                writeGranularParameter(id: .granularMorph, value: Float(morph), voiceIndex: granular.voice.reelIndex)
                recordMutation(
                    changedPaths: ["\(granular.voice.id).morph"],
                    additionalEvents: [
                        (
                            type: "granular.param_changed",
                            payload: [
                                "voiceId": granular.voice.id,
                                "path": "\(granular.voice.id).morph",
                                "value": morph,
                            ]
                        ),
                    ]
                )
                return (true, nil)
            default:
                return (true, ActionFailure(actionId: action.actionId, code: .notFound, message: "Unsupported granular target"))
            }
        }

        if target == "transport.playing" {
            guard let desired = desiredBoolValue(for: action, current: readTransportRunning()) else {
                return (true, ActionFailure(actionId: action.actionId, code: .badRequest, message: "transport.playing requires boolean value"))
            }
            writeTransportRunning(desired)
            recordMutation(
                changedPaths: ["transport.playing"],
                additionalEvents: [
                    (
                        type: "transport.playing_changed",
                        payload: ["playing": desired]
                    ),
                ]
            )
            return (true, nil)
        }

        if target == "session.key" {
            guard let keyText = modeTextFromAction(action),
                  let descriptor = parseSessionKeyDescriptor(keyText) else {
                return (true, ActionFailure(actionId: action.actionId, code: .badRequest, message: "session.key requires value like 'F minor pentatonic'"))
            }
            writeSequencerRootAndScale(rootNote: descriptor.rootNote, scaleIndex: descriptor.scaleIndex)
            recordMutation(
                changedPaths: ["session.key"],
                additionalEvents: [
                    (
                        type: "session.key_changed",
                        payload: [
                            "rootNote": descriptor.rootNote,
                            "scaleIndex": descriptor.scaleIndex,
                        ]
                    ),
                ]
            )
            return (true, nil)
        }

        if target == "session.tempoBpm" {
            guard let bpm = feedbackValueFromAction(action), bpm >= 20.0, bpm <= 300.0 else {
                return (true, ActionFailure(actionId: action.actionId, code: .actionOutOfRange, message: "session.tempoBpm must be a number between 20 and 300"))
            }
            writeMasterClockBPM(bpm)
            recordMutation(
                changedPaths: ["session.tempoBpm"],
                additionalEvents: [
                    (
                        type: "session.tempoBpm_changed",
                        payload: ["tempoBpm": bpm]
                    ),
                ]
            )
            return (true, nil)
        }

        if target == "synth.macro_osc.mode" || target == "synth.plaits.mode" {
            guard let mode = modeTextFromAction(action),
                  let normalized = plaitsModelNormalized(modeText: mode) else {
                return (true, ActionFailure(actionId: action.actionId, code: .badRequest, message: "Unsupported macro_osc mode"))
            }
            writeSynthMode(parameter: .plaitsModel, normalizedValue: normalized)
            recordMutation(
                changedPaths: ["synth.macro_osc.mode"],
                additionalEvents: [
                    (
                        type: "synth.mode_changed",
                        payload: [
                            "synth": "macro_osc",
                            "mode": mode,
                        ]
                    ),
                ]
            )
            return (true, nil)
        }

        // Macro Osc continuous parameters (accept both new and old path prefixes)
        let macroOscParamMap: [String: ParameterID] = [
            "synth.macro_osc.harmonics": .plaitsHarmonics,
            "synth.macro_osc.timbre": .plaitsTimbre,
            "synth.macro_osc.morph": .plaitsMorph,
            "synth.macro_osc.level": .plaitsLevel,
            "synth.macro_osc.lpgColor": .plaitsLPGColor,
            "synth.macro_osc.lpgDecay": .plaitsLPGDecay,
            "synth.macro_osc.lpgAttack": .plaitsLPGAttack,
            "synth.macro_osc.lpgBypass": .plaitsLPGBypass,
            // Backward compat: old paths
            "synth.plaits.harmonics": .plaitsHarmonics,
            "synth.plaits.timbre": .plaitsTimbre,
            "synth.plaits.morph": .plaitsMorph,
            "synth.plaits.level": .plaitsLevel,
            "synth.plaits.lpgColor": .plaitsLPGColor,
            "synth.plaits.lpgDecay": .plaitsLPGDecay,
            "synth.plaits.lpgAttack": .plaitsLPGAttack,
            "synth.plaits.lpgBypass": .plaitsLPGBypass,
        ]
        if let paramId = macroOscParamMap[target] {
            guard let value = feedbackValueFromAction(action), value >= 0.0, value <= 1.0 else {
                return (true, ActionFailure(actionId: action.actionId, code: .actionOutOfRange, message: "Macro Osc \(target.split(separator: ".").last ?? "") must be within [0.0, 1.0]"))
            }
            writeSynthMode(parameter: paramId, normalizedValue: Float(value))
            recordMutation(
                changedPaths: [target],
                additionalEvents: [
                    (type: "synth.param_changed", payload: ["synth": "macro_osc", "param": String(target.split(separator: ".").last ?? ""), "value": value]),
                ]
            )
            return (true, nil)
        }

        if target == "synth.resonator.mode" || target == "synth.rings.mode" {
            guard let mode = modeTextFromAction(action),
                  let normalized = ringsModelNormalized(modeText: mode) else {
                return (true, ActionFailure(actionId: action.actionId, code: .badRequest, message: "Unsupported resonator mode"))
            }
            writeSynthMode(parameter: .ringsModel, normalizedValue: normalized)
            recordMutation(
                changedPaths: ["synth.resonator.mode"],
                additionalEvents: [
                    (
                        type: "synth.mode_changed",
                        payload: [
                            "synth": "resonator",
                            "mode": mode,
                        ]
                    ),
                ]
            )
            return (true, nil)
        }

        // Resonator continuous parameters (accept both new and old path prefixes)
        let resonatorParamMap: [String: ParameterID] = [
            "synth.resonator.structure": .ringsStructure,
            "synth.resonator.brightness": .ringsBrightness,
            "synth.resonator.damping": .ringsDamping,
            "synth.resonator.position": .ringsPosition,
            "synth.resonator.level": .ringsLevel,
            // Backward compat: old paths
            "synth.rings.structure": .ringsStructure,
            "synth.rings.brightness": .ringsBrightness,
            "synth.rings.damping": .ringsDamping,
            "synth.rings.position": .ringsPosition,
            "synth.rings.level": .ringsLevel,
        ]
        if let paramId = resonatorParamMap[target] {
            guard let value = feedbackValueFromAction(action), value >= 0.0, value <= 1.0 else {
                return (true, ActionFailure(actionId: action.actionId, code: .actionOutOfRange, message: "Resonator \(target.split(separator: ".").last ?? "") must be within [0.0, 1.0]"))
            }
            writeSynthMode(parameter: paramId, normalizedValue: Float(value))
            recordMutation(
                changedPaths: [target],
                additionalEvents: [
                    (type: "synth.param_changed", payload: ["synth": "resonator", "param": String(target.split(separator: ".").last ?? ""), "value": value]),
                ]
            )
            return (true, nil)
        }

        if target == "synth.daisydrum.mode" {
            guard let mode = modeTextFromAction(action),
                  let normalized = daisyDrumModelNormalized(modeText: mode) else {
                return (true, ActionFailure(actionId: action.actionId, code: .badRequest, message: "Unsupported daisydrum mode"))
            }
            writeSynthMode(parameter: .daisyDrumEngine, normalizedValue: normalized)
            recordMutation(
                changedPaths: ["synth.daisydrum.mode"],
                additionalEvents: [
                    (
                        type: "synth.mode_changed",
                        payload: [
                            "synth": "daisydrum",
                            "mode": mode,
                        ]
                    ),
                ]
            )
            return (true, nil)
        }

        if target == "synth.daisydrum.harmonics" {
            guard let value = feedbackValueFromAction(action), value >= 0.0, value <= 1.0 else {
                return (true, ActionFailure(actionId: action.actionId, code: .actionOutOfRange, message: "DaisyDrum harmonics must be within [0.0, 1.0]"))
            }
            writeSynthMode(parameter: .daisyDrumHarmonics, normalizedValue: Float(value))
            recordMutation(
                changedPaths: ["synth.daisydrum.harmonics"],
                additionalEvents: [
                    (type: "synth.param_changed", payload: ["synth": "daisydrum", "param": "harmonics", "value": value]),
                ]
            )
            return (true, nil)
        }

        if target == "synth.daisydrum.timbre" {
            guard let value = feedbackValueFromAction(action), value >= 0.0, value <= 1.0 else {
                return (true, ActionFailure(actionId: action.actionId, code: .actionOutOfRange, message: "DaisyDrum timbre must be within [0.0, 1.0]"))
            }
            writeSynthMode(parameter: .daisyDrumTimbre, normalizedValue: Float(value))
            recordMutation(
                changedPaths: ["synth.daisydrum.timbre"],
                additionalEvents: [
                    (type: "synth.param_changed", payload: ["synth": "daisydrum", "param": "timbre", "value": value]),
                ]
            )
            return (true, nil)
        }

        if target == "synth.daisydrum.morph" {
            guard let value = feedbackValueFromAction(action), value >= 0.0, value <= 1.0 else {
                return (true, ActionFailure(actionId: action.actionId, code: .actionOutOfRange, message: "DaisyDrum morph must be within [0.0, 1.0]"))
            }
            writeSynthMode(parameter: .daisyDrumMorph, normalizedValue: Float(value))
            recordMutation(
                changedPaths: ["synth.daisydrum.morph"],
                additionalEvents: [
                    (type: "synth.param_changed", payload: ["synth": "daisydrum", "param": "morph", "value": value]),
                ]
            )
            return (true, nil)
        }

        // Sampler mode apply
        if target == "synth.sampler.mode" {
            guard let modeStr = modeTextFromAction(action) else {
                return (true, ActionFailure(actionId: action.actionId, code: .actionOutOfRange, message: "Missing mode value"))
            }
            let mode: AudioEngineWrapper.SamplerMode
            switch modeStr {
            case "sfz": mode = .sfz
            case "wavsampler": mode = .wavSampler
            default: mode = .soundFont
            }
            DispatchQueue.main.sync {
                MainActor.assumeIsolated { [weak self] in
                    self?.audioEngine?.setSamplerMode(mode)
                }
            }
            recordMutation(
                changedPaths: [target],
                additionalEvents: [
                    (type: "synth.sampler_mode_changed", payload: ["mode": modeStr]),
                ]
            )
            return (true, nil)
        }

        // Sampler apply
        let samplerParamMap: [String: ParameterID] = [
            "synth.sampler.preset": .samplerPreset,
            "synth.sampler.attack": .samplerAttack,
            "synth.sampler.decay": .samplerDecay,
            "synth.sampler.sustain": .samplerSustain,
            "synth.sampler.release": .samplerRelease,
            "synth.sampler.filterCutoff": .samplerFilterCutoff,
            "synth.sampler.filterResonance": .samplerFilterResonance,
            "synth.sampler.tuning": .samplerTuning,
            "synth.sampler.level": .samplerLevel,
        ]
        if let paramId = samplerParamMap[target] {
            guard let value = feedbackValueFromAction(action), value >= 0.0, value <= 1.0 else {
                let paramName = String(target.split(separator: ".").last ?? "")
                return (true, ActionFailure(actionId: action.actionId, code: .actionOutOfRange, message: "Sampler \(paramName) must be within [0.0, 1.0]"))
            }
            writeSynthMode(parameter: paramId, normalizedValue: Float(value))
            let paramName = String(target.split(separator: ".").last ?? "")
            recordMutation(
                changedPaths: [target],
                additionalEvents: [
                    (type: "synth.param_changed", payload: ["synth": "sampler", "param": paramName, "value": value]),
                ]
            )
            return (true, nil)
        }

        // Chord sequencer apply
        if target.hasPrefix("sequencer.chords") {
            return applyChordSequencerAction(action, target: target)
        }

        // Drum sequencer apply
        if let drumTarget = parseDrumSequencerTarget(target) {
            return applyDrumSequencerAction(action, target: drumTarget)
        }

        guard let trackTarget = parseSequencerTrackTarget(target) else {
            return (false, nil)
        }
        let trackIndex = trackTarget.trackIndex
        let trackPathPrefix = "sequencer.track\(trackIndex + 1)"

        if let stepProperty = parseSequencerStepProperty(trackTarget.property) {
            switch stepProperty.field {
            case "note":
                guard let noteText = modeTextFromAction(action),
                      let note = parsePitchClass(noteText),
                      let noteSlot = noteSlotForPitchClass(note) else {
                    return (true, ActionFailure(actionId: action.actionId, code: .badRequest, message: "Invalid step note"))
                }
                writeTrackStageNoteSlot(trackIndex: trackIndex, stage: stepProperty.stageIndex, noteSlot: noteSlot)
                recordMutation(
                    changedPaths: ["\(trackPathPrefix).step\(stepProperty.stageIndex + 1).note"],
                    additionalEvents: [
                        (
                            type: "sequencer.step_updated",
                            payload: [
                                "track": trackIndex + 1,
                                "step": stepProperty.stageIndex + 1,
                                "field": "note",
                                "value": noteText,
                            ]
                        ),
                    ]
                )
                return (true, nil)
            case "probability":
                guard let probability = feedbackValueFromAction(action), probability >= 0.0, probability <= 1.0 else {
                    return (true, ActionFailure(actionId: action.actionId, code: .actionOutOfRange, message: "Step probability must be within [0.0, 1.0]"))
                }
                writeTrackStageProbability(trackIndex: trackIndex, stage: stepProperty.stageIndex, probability: probability)
                recordMutation(
                    changedPaths: ["\(trackPathPrefix).step\(stepProperty.stageIndex + 1).probability"],
                    additionalEvents: [
                        (
                            type: "sequencer.step_updated",
                            payload: [
                                "track": trackIndex + 1,
                                "step": stepProperty.stageIndex + 1,
                                "field": "probability",
                                "value": probability,
                            ]
                        ),
                    ]
                )
                return (true, nil)
            case "ratchets":
                guard let ratchets = feedbackValueFromAction(action) else {
                    return (true, ActionFailure(actionId: action.actionId, code: .badRequest, message: "Step ratchets requires numeric value"))
                }
                let rounded = Int(ratchets.rounded())
                guard (1...8).contains(rounded) else {
                    return (true, ActionFailure(actionId: action.actionId, code: .actionOutOfRange, message: "Step ratchets must be within [1, 8]"))
                }
                writeTrackStageRatchets(trackIndex: trackIndex, stage: stepProperty.stageIndex, ratchets: rounded)
                recordMutation(
                    changedPaths: ["\(trackPathPrefix).step\(stepProperty.stageIndex + 1).ratchets"],
                    additionalEvents: [
                        (
                            type: "sequencer.step_updated",
                            payload: [
                                "track": trackIndex + 1,
                                "step": stepProperty.stageIndex + 1,
                                "field": "ratchets",
                                "value": rounded,
                            ]
                        ),
                    ]
                )
                return (true, nil)
            case "gateMode":
                guard let text = modeTextFromAction(action), let mode = gateModeFromText(text) else {
                    return (true, ActionFailure(actionId: action.actionId, code: .badRequest, message: "Unsupported step gateMode"))
                }
                writeTrackStageGateMode(trackIndex: trackIndex, stage: stepProperty.stageIndex, gateMode: mode)
                recordMutation(
                    changedPaths: ["\(trackPathPrefix).step\(stepProperty.stageIndex + 1).gateMode"],
                    additionalEvents: [
                        (
                            type: "sequencer.step_updated",
                            payload: [
                                "track": trackIndex + 1,
                                "step": stepProperty.stageIndex + 1,
                                "field": "gateMode",
                                "value": mode.rawValue,
                            ]
                        ),
                    ]
                )
                return (true, nil)
            case "stepType":
                guard let text = modeTextFromAction(action), let stepType = stepTypeFromText(text) else {
                    return (true, ActionFailure(actionId: action.actionId, code: .badRequest, message: "Unsupported step stepType"))
                }
                writeTrackStageStepType(trackIndex: trackIndex, stage: stepProperty.stageIndex, stepType: stepType)
                recordMutation(
                    changedPaths: ["\(trackPathPrefix).step\(stepProperty.stageIndex + 1).stepType"],
                    additionalEvents: [
                        (
                            type: "sequencer.step_updated",
                            payload: [
                                "track": trackIndex + 1,
                                "step": stepProperty.stageIndex + 1,
                                "field": "stepType",
                                "value": stepType.rawValue,
                            ]
                        ),
                    ]
                )
                return (true, nil)
            case "gateLength":
                guard let gl = feedbackValueFromAction(action), gl >= 0.01, gl <= 1.0 else {
                    return (true, ActionFailure(actionId: action.actionId, code: .actionOutOfRange, message: "Step gateLength must be within [0.01, 1.0]"))
                }
                writeTrackStageGateLength(trackIndex: trackIndex, stage: stepProperty.stageIndex, gateLength: gl)
                recordMutation(
                    changedPaths: ["\(trackPathPrefix).step\(stepProperty.stageIndex + 1).gateLength"],
                    additionalEvents: [
                        (
                            type: "sequencer.step_updated",
                            payload: [
                                "track": trackIndex + 1,
                                "step": stepProperty.stageIndex + 1,
                                "field": "gateLength",
                                "value": gl,
                            ]
                        ),
                    ]
                )
                return (true, nil)
            default:
                return (true, ActionFailure(actionId: action.actionId, code: .notFound, message: "Unsupported step target field"))
            }
        }

        switch trackTarget.property {
        case "enabled":
            guard let desired = desiredBoolValue(for: action, current: readTrackEnabled(trackIndex: trackIndex)) else {
                return (true, ActionFailure(actionId: action.actionId, code: .badRequest, message: "track enabled requires boolean value"))
            }
            writeTrackEnabled(trackIndex: trackIndex, enabled: desired)
            recordMutation(
                changedPaths: ["\(trackPathPrefix).enabled"],
                additionalEvents: [
                    (
                        type: "sequencer.track_updated",
                        payload: ["track": trackIndex + 1, "field": "enabled", "value": desired]
                    ),
                ]
            )
            return (true, nil)
        case "pattern":
            guard let pattern = modeTextFromAction(action),
                  pattern.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "ascending" else {
                return (true, ActionFailure(actionId: action.actionId, code: .badRequest, message: "Only 'ascending' pattern is currently supported"))
            }
            writeAscendingPattern(trackIndex: trackIndex)
            recordMutation(
                changedPaths: ["\(trackPathPrefix).pattern"],
                additionalEvents: [
                    (
                        type: "sequencer.track_updated",
                        payload: ["track": trackIndex + 1, "field": "pattern", "value": "ascending"]
                    ),
                ]
            )
            return (true, nil)
        case "rateMultiplier":
            guard let multiplier = feedbackValueFromAction(action),
                  let division = divisionForRateMultiplier(multiplier) else {
                return (true, ActionFailure(actionId: action.actionId, code: .badRequest, message: "Unsupported rateMultiplier"))
            }
            writeTrackDivision(trackIndex: trackIndex, division: division)
            recordMutation(
                changedPaths: ["\(trackPathPrefix).rateMultiplier", "\(trackPathPrefix).clockDivision"],
                additionalEvents: [
                    (
                        type: "sequencer.track_updated",
                        payload: ["track": trackIndex + 1, "field": "clockDivision", "value": division.rawValue]
                    ),
                ]
            )
            return (true, nil)
        case "clockDivision":
            guard let divisionText = modeTextFromAction(action),
                  let division = divisionFromText(divisionText) else {
                return (true, ActionFailure(actionId: action.actionId, code: .badRequest, message: "Unsupported clockDivision"))
            }
            writeTrackDivision(trackIndex: trackIndex, division: division)
            recordMutation(
                changedPaths: ["\(trackPathPrefix).clockDivision"],
                additionalEvents: [
                    (
                        type: "sequencer.track_updated",
                        payload: ["track": trackIndex + 1, "field": "clockDivision", "value": division.rawValue]
                    ),
                ]
            )
            return (true, nil)
        case "output":
            guard let outputText = modeTextFromAction(action),
                  let output = trackOutputFromText(outputText) else {
                return (true, ActionFailure(actionId: action.actionId, code: .badRequest, message: "Unsupported track output"))
            }
            writeTrackOutput(trackIndex: trackIndex, output: output)
            recordMutation(
                changedPaths: ["\(trackPathPrefix).output"],
                additionalEvents: [
                    (
                        type: "sequencer.track_updated",
                        payload: ["track": trackIndex + 1, "field": "output", "value": output.rawValue]
                    ),
                ]
            )
            return (true, nil)
        case "stepGroupA.note":
            guard let noteText = modeTextFromAction(action),
                  let note = parsePitchClass(noteText),
                  let noteSlot = noteSlotForPitchClass(note) else {
                return (true, ActionFailure(actionId: action.actionId, code: .badRequest, message: "Invalid note for stepGroupA"))
            }
            writeTrackStepGroup(trackIndex: trackIndex, stageRange: 0...3, noteSlot: noteSlot)
            recordMutation(
                changedPaths: ["\(trackPathPrefix).stepGroupA.note"],
                additionalEvents: [
                    (
                        type: "sequencer.track_updated",
                        payload: ["track": trackIndex + 1, "field": "stepGroupA.note", "value": noteText]
                    ),
                ]
            )
            return (true, nil)
        case "stepGroupB.note":
            guard let noteText = modeTextFromAction(action),
                  let note = parsePitchClass(noteText),
                  let noteSlot = noteSlotForPitchClass(note) else {
                return (true, ActionFailure(actionId: action.actionId, code: .badRequest, message: "Invalid note for stepGroupB"))
            }
            writeTrackStepGroup(trackIndex: trackIndex, stageRange: 4...7, noteSlot: noteSlot)
            recordMutation(
                changedPaths: ["\(trackPathPrefix).stepGroupB.note"],
                additionalEvents: [
                    (
                        type: "sequencer.track_updated",
                        payload: ["track": trackIndex + 1, "field": "stepGroupB.note", "value": noteText]
                    ),
                ]
            )
            return (true, nil)
        default:
            return (true, ActionFailure(actionId: action.actionId, code: .notFound, message: "Unsupported sequencer target"))
        }
    }

    private func simulatedVoiceState() -> [String: SimulatedRecordingState] {
        var state: [String: SimulatedRecordingState] = [:]
        for voice in voiceTargets {
            state[voice.id] = simulatedStateForVoice(voice)
        }
        return state
    }

    private func simulatedStateForVoice(_ voice: VoiceTarget) -> SimulatedRecordingState {
        let snapshot = readRecordingModeAndFeedback(
            reelIndex: voice.reelIndex,
            defaultMode: voice.defaultMode,
            defaultFeedback: voice.defaultFeedback
        )
        let active = readIsReelRecording(voice.reelIndex)
        return SimulatedRecordingState(active: active, mode: snapshot.mode, feedback: snapshot.feedback)
    }

    private func normalizedActionType(_ action: ActionRequest) -> String {
        ConversationalRoutingCore.normalizeActionType(type: action.type, target: action.target)
    }

    private func isRecordingActionType(_ type: String) -> Bool {
        switch type {
        case "startRecording", "stopRecording", "setRecordingFeedback", "setRecordingMode":
            return true
        default:
            return false
        }
    }

    private func riskForActionType(_ type: String) -> String {
        switch type {
        case "setRecordingFeedback":
            return "low"
        case "startRecording", "stopRecording", "setRecordingMode":
            return "medium"
        default:
            return "medium"
        }
    }

    private func riskRank(_ risk: String) -> Int {
        ConversationalRoutingCore.riskRank(risk)
    }

    private func desiredBoolValue(for action: ActionRequest, current: Bool) -> Bool? {
        if action.type == "toggle" {
            return !current
        }
        return boolValueFromAction(action)
    }

    private func boolValueFromAction(_ action: ActionRequest) -> Bool? {
        if let value = action.value {
            switch value {
            case .bool(let bool):
                return bool
            case .number(let number):
                return number != 0
            case .string(let string):
                let normalized = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if normalized == "true" || normalized == "1" || normalized == "on" { return true }
                if normalized == "false" || normalized == "0" || normalized == "off" { return false }
                return nil
            case .null:
                return nil
            }
        }
        return nil
    }

    // MARK: - Chord Sequencer Actions

    private func applyChordSequencerAction(_ action: ActionRequest, target: String) -> (handled: Bool, failure: ActionFailure?) {
        let suffix = target.replacingOccurrences(of: "sequencer.chords.", with: "")

        // Top-level chord sequencer properties
        switch suffix {
        case "enabled":
            let current = readChordSequencerProperty { $0.isEnabled } ?? true
            guard let desired = desiredBoolValue(for: action, current: current) else {
                return (true, ActionFailure(actionId: action.actionId, code: .badRequest, message: "chords.enabled requires boolean value"))
            }
            writeChordSequencer { $0.isEnabled = desired }
            recordMutation(
                changedPaths: ["sequencer.chords.enabled"],
                additionalEvents: [(type: "chords.updated", payload: ["field": "enabled", "value": desired])]
            )
            return (true, nil)

        case "clockDivision":
            guard let text = modeTextFromAction(action),
                  let division = divisionFromText(text) else {
                return (true, ActionFailure(actionId: action.actionId, code: .badRequest, message: "Invalid clock division"))
            }
            writeChordSequencer { $0.division = division }
            recordMutation(
                changedPaths: ["sequencer.chords.clockDivision"],
                additionalEvents: [(type: "chords.updated", payload: ["field": "clockDivision", "value": division.rawValue])]
            )
            return (true, nil)

        case "preset":
            guard let text = modeTextFromAction(action) else {
                return (true, ActionFailure(actionId: action.actionId, code: .badRequest, message: "preset requires text value"))
            }
            let lower = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            guard let preset = ChordSequencer.presets.first(where: { $0.id.lowercased() == lower || $0.name.lowercased() == lower }) else {
                let available = ChordSequencer.presets.map { $0.id }.joined(separator: ", ")
                return (true, ActionFailure(actionId: action.actionId, code: .notFound, message: "Unknown preset '\(text)'. Available: \(available)"))
            }
            writeChordSequencer { $0.loadPreset(preset) }
            recordMutation(
                changedPaths: ["sequencer.chords"],
                additionalEvents: [(type: "chords.preset_loaded", payload: ["preset": preset.id, "name": preset.name])]
            )
            return (true, nil)

        default:
            break
        }

        // Step-level properties: step<1-8>.degree, step<1-8>.quality, step<1-8>.active, step<1-8>.clear
        guard suffix.hasPrefix("step") else {
            return (true, ActionFailure(actionId: action.actionId, code: .notFound, message: "Unknown chord sequencer target: \(target)"))
        }
        let stepTail = suffix.dropFirst("step".count)
        let numberText = String(stepTail.prefix { $0.isNumber })
        guard !numberText.isEmpty, let stepNumber = Int(numberText), (1...8).contains(stepNumber) else {
            return (true, ActionFailure(actionId: action.actionId, code: .badRequest, message: "Invalid step number"))
        }
        let stepIndex = stepNumber - 1
        let remainder = stepTail.dropFirst(numberText.count)
        guard remainder.first == "." else {
            return (true, ActionFailure(actionId: action.actionId, code: .badRequest, message: "Missing field after step number"))
        }
        let field = String(remainder.dropFirst())

        switch field {
        case "degree":
            guard let text = modeTextFromAction(action) else {
                return (true, ActionFailure(actionId: action.actionId, code: .badRequest, message: "degree requires text value"))
            }
            guard ChordSequencer.allDegrees.contains(where: { $0.id == text }) else {
                let available = ChordSequencer.allDegrees.map { $0.id }.joined(separator: ", ")
                return (true, ActionFailure(actionId: action.actionId, code: .notFound, message: "Unknown degree '\(text)'. Available: \(available)"))
            }
            writeChordSequencer { chordSeq in
                chordSeq.setDegree(stepIndex, text)
                // If quality is not set, default to major
                if chordSeq.steps[stepIndex].qualityId == nil {
                    chordSeq.setQuality(stepIndex, "maj")
                }
            }
            recordMutation(
                changedPaths: ["sequencer.chords.step\(stepNumber).degree"],
                additionalEvents: [(type: "chords.step_updated", payload: ["step": stepNumber, "field": "degree", "value": text])]
            )
            return (true, nil)

        case "quality":
            guard let text = modeTextFromAction(action) else {
                return (true, ActionFailure(actionId: action.actionId, code: .badRequest, message: "quality requires text value"))
            }
            guard ChordSequencer.allQualities.contains(where: { $0.id == text }) else {
                let available = ChordSequencer.allQualities.map { $0.id }.joined(separator: ", ")
                return (true, ActionFailure(actionId: action.actionId, code: .notFound, message: "Unknown quality '\(text)'. Available: \(available)"))
            }
            writeChordSequencer { $0.setQuality(stepIndex, text) }
            recordMutation(
                changedPaths: ["sequencer.chords.step\(stepNumber).quality"],
                additionalEvents: [(type: "chords.step_updated", payload: ["step": stepNumber, "field": "quality", "value": text])]
            )
            return (true, nil)

        case "active":
            let current = readChordSequencerProperty { $0.steps[stepIndex].active } ?? true
            guard let desired = desiredBoolValue(for: action, current: current) else {
                return (true, ActionFailure(actionId: action.actionId, code: .badRequest, message: "active requires boolean value"))
            }
            writeChordSequencer { $0.setStepActive(stepIndex, desired) }
            recordMutation(
                changedPaths: ["sequencer.chords.step\(stepNumber).active"],
                additionalEvents: [(type: "chords.step_updated", payload: ["step": stepNumber, "field": "active", "value": desired])]
            )
            return (true, nil)

        case "clear":
            writeChordSequencer { $0.clearStep(stepIndex) }
            recordMutation(
                changedPaths: ["sequencer.chords.step\(stepNumber)"],
                additionalEvents: [(type: "chords.step_cleared", payload: ["step": stepNumber])]
            )
            return (true, nil)

        default:
            return (true, ActionFailure(actionId: action.actionId, code: .notFound, message: "Unknown chord step field: \(field)"))
        }
    }

    // MARK: - Chord Sequencer Read/Write Helpers

    private func readChordSequencerProperty<T>(_ accessor: @escaping @MainActor (ChordSequencer) -> T) -> T? {
        if Thread.isMainThread {
            return MainActor.assumeIsolated { [weak self] in
                guard let chordSeq = self?.chordSequencer else { return nil }
                return accessor(chordSeq)
            }
        }
        return DispatchQueue.main.sync {
            MainActor.assumeIsolated { [weak self] in
                guard let chordSeq = self?.chordSequencer else { return nil as T? }
                return accessor(chordSeq)
            }
        }
    }

    private func writeChordSequencer(_ block: @escaping @MainActor (ChordSequencer) -> Void) {
        if Thread.isMainThread {
            MainActor.assumeIsolated { [weak self] in
                guard let chordSeq = self?.chordSequencer else { return }
                block(chordSeq)
            }
            return
        }
        DispatchQueue.main.sync {
            MainActor.assumeIsolated { [weak self] in
                guard let chordSeq = self?.chordSequencer else { return }
                block(chordSeq)
            }
        }
    }

    private func parseSequencerTrackTarget(_ target: String) -> (trackIndex: Int, property: String)? {
        let prefix = "sequencer.track"
        guard target.hasPrefix(prefix) else { return nil }
        let tail = target.dropFirst(prefix.count)
        let numberText = String(tail.prefix { $0.isNumber })
        guard !numberText.isEmpty, let trackNumber = Int(numberText), trackNumber >= 1 else {
            return nil
        }
        let remainder = tail.dropFirst(numberText.count)
        guard remainder.first == "." else { return nil }
        let property = String(remainder.dropFirst())
        guard !property.isEmpty else { return nil }
        return (trackNumber - 1, property)
    }

    private func parseSequencerStepProperty(_ property: String) -> (stageIndex: Int, field: String)? {
        guard property.hasPrefix("step") else { return nil }
        let tail = property.dropFirst("step".count)
        let numberText = String(tail.prefix { $0.isNumber })
        guard !numberText.isEmpty, let stepNumber = Int(numberText), (1...8).contains(stepNumber) else {
            return nil
        }
        let remainder = tail.dropFirst(numberText.count)
        guard remainder.first == "." else { return nil }
        let field = String(remainder.dropFirst())
        guard !field.isEmpty else { return nil }
        return (stepNumber - 1, field)
    }

    private func gateModeFromText(_ text: String) -> SequencerGateMode? {
        switch text.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() {
        case "EVERY":
            return .every
        case "FIRST":
            return .first
        case "LAST":
            return .last
        case "TIE":
            return .tie
        case "REST":
            return .rest
        default:
            return nil
        }
    }

    private func stepTypeFromText(_ text: String) -> SequencerStepType? {
        switch text.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() {
        case "PLAY":
            return .play
        case "SKIP":
            return .skip
        case "ELIDE":
            return .elide
        case "REST":
            return .rest
        case "TIE":
            return .tie
        default:
            return nil
        }
    }

    private func divisionForRateMultiplier(_ multiplier: Double) -> SequencerClockDivision? {
        let candidates: [(Double, SequencerClockDivision)] = [
            (1.0 / 16.0, .div16),
            (1.0 / 12.0, .div12),
            (1.0 / 8.0, .div8),
            (1.0 / 6.0, .div6),
            (1.0 / 4.0, .div4),
            (1.0 / 3.0, .div3),
            (1.0 / 2.0, .div2),
            (2.0 / 3.0, .div3Over2),
            (3.0 / 4.0, .div4Over3),
            (1.0, .x1),
            (4.0 / 3.0, .x4Over3),
            (3.0 / 2.0, .x3Over2),
            (2.0, .x2),
            (3.0, .x3),
            (4.0, .x4),
            (6.0, .x6),
            (8.0, .x8),
            (12.0, .x12),
            (16.0, .x16),
        ]
        let epsilon = 0.0001
        for candidate in candidates where abs(candidate.0 - multiplier) < epsilon {
            return candidate.1
        }
        return nil
    }

    private func divisionFromText(_ text: String) -> SequencerClockDivision? {
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
        switch normalized {
        case "/16", "1/16":
            return .div16
        case "/12", "1/12":
            return .div12
        case "/8", "1/8":
            return .div8
        case "/6", "1/6":
            return .div6
        case "/4", "1/4":
            return .div4
        case "/3", "1/3":
            return .div3
        case "/2", "1/2":
            return .div2
        case "2/3x":
            return .div3Over2
        case "3/4x":
            return .div4Over3
        case "x1", "1x":
            return .x1
        case "x4/3":
            return .x4Over3
        case "x3/2":
            return .x3Over2
        case "x2", "2x":
            return .x2
        case "x3", "3x":
            return .x3
        case "x4", "4x":
            return .x4
        case "x6", "6x":
            return .x6
        case "x8", "8x":
            return .x8
        case "x12", "12x":
            return .x12
        case "x16", "16x":
            return .x16
        default:
            return nil
        }
    }

    private func trackOutputFromText(_ text: String) -> SequencerTrackOutput? {
        switch text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "macro_osc", "macro osc", "plaits":
            return .plaits
        case "resonator", "rings":
            return .rings
        case "both":
            return .both
        case "drums", "daisydrum", "drum":
            return .daisyDrum
        case "sampler", "soundfont", "sf2":
            return .sampler
        default:
            return nil
        }
    }

    private func parseGranularVoiceTarget(_ target: String) -> (voice: VoiceTarget, property: String)? {
        for voice in voiceTargets where voice.module == "granular" {
            let prefix = voice.id + "."
            if target.hasPrefix(prefix) {
                let property = String(target.dropFirst(prefix.count))
                guard !property.isEmpty else { return nil }
                return (voice, property)
            }
        }
        return nil
    }

    private func envelopeIndexFromAction(_ action: ActionRequest) -> Int? {
        if let number = feedbackValueFromAction(action) {
            let rounded = Int(number.rounded())
            if rounded >= 0, rounded <= 7 {
                return rounded
            }
        }
        guard let text = modeTextFromAction(action) else { return nil }
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let map: [String: Int] = [
            "hann": 0,
            "gauss": 1,
            "gaussian": 1,
            "trap": 2,
            "trapezoid": 2,
            "tri": 3,
            "triangle": 3,
            "tukey": 4,
            "pluck": 5,
            "soft": 6,
            "decay": 7,
        ]
        return map[normalized]
    }

    private func plaitsModelNormalized(modeText: String) -> Float? {
        let normalized = modeText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().replacingOccurrences(of: "_", with: " ")
        let names: [(String, Int)] = [
            ("va vcf", 0), ("virtual analog vcf", 0),
            ("phase dist", 1), ("phase distortion", 1),
            ("six op fm a", 2), ("six-op fm a", 2), ("dx7 a", 2),
            ("six op fm b", 3), ("six-op fm b", 3), ("dx7 b", 3),
            ("six op fm c", 4), ("six-op fm c", 4), ("dx7 c", 4),
            ("wave terrain", 5),
            ("string machine", 6),
            ("chiptune", 7),
            ("virtual analog", 8),
            ("waveshaper", 9), ("waveshaping", 9),
            ("two op fm", 10), ("two-op fm", 10),
            ("granular formant", 11),
            ("harmonic", 12),
            ("wavetable", 13),
            ("chords", 14),
            ("speech", 15), ("vowel speech", 15),
            ("granular cloud", 16), ("swarm", 16),
            ("filtered noise", 17), ("noise", 17),
            ("particle noise", 18), ("particle", 18),
            ("string", 19),
            ("modal", 20),
            ("bass drum", 21), ("kick", 21),
            ("snare drum", 22), ("snare", 22),
            ("hi hat", 23), ("hihat", 23),
            ("six op fm", 2), ("six-op fm", 2), ("sixop fm", 2), ("6 op fm", 2), ("dx7", 2),
        ]
        if let exact = names.first(where: { $0.0 == normalized }) {
            return Float(exact.1) / 23.0
        }
        if normalized.contains("phase") {
            return Float(1) / 23.0
        }
        if normalized.contains("terrain") {
            return Float(5) / 23.0
        }
        if normalized.contains("string machine") {
            return Float(6) / 23.0
        }
        if normalized.contains("chiptune") {
            return Float(7) / 23.0
        }
        if normalized.contains("virtual analog") && normalized.contains("vcf") {
            return Float(0) / 23.0
        }
        if normalized.contains("virtual analog") {
            return Float(8) / 23.0
        }
        if normalized.contains("wave") && normalized.contains("shape") {
            return Float(9) / 23.0
        }
        if normalized.contains("granular") && normalized.contains("formant") {
            return Float(11) / 23.0
        }
        if normalized.contains("granular") || normalized.contains("swarm") {
            return Float(16) / 23.0
        }
        if normalized.contains("particle") {
            return Float(18) / 23.0
        }
        if normalized.contains("noise") {
            return Float(17) / 23.0
        }
        if normalized.contains("string") {
            return Float(19) / 23.0
        }
        if normalized.contains("modal") {
            return Float(20) / 23.0
        }
        if normalized.contains("bass") || normalized.contains("kick") {
            return Float(21) / 23.0
        }
        if normalized.contains("snare") {
            return Float(22) / 23.0
        }
        if normalized.contains("hat") {
            return Float(23) / 23.0
        }
        if normalized.contains("six op") || normalized.contains("6op") || normalized.contains("dx7") {
            return Float(2) / 23.0
        }
        return nil
    }

    private func daisyDrumModeName(fromNormalized normalized: Float) -> String {
        let names = [
            "analog kick",
            "synthetic kick",
            "analog snare",
            "synthetic snare",
            "hi hat",
        ]
        let clamped = clamp01(Double(normalized))
        let index = min(max(Int((clamped * 4.0).rounded()), 0), names.count - 1)
        return names[index]
    }

    private func daisyDrumModelNormalized(modeText: String) -> Float? {
        let normalized = modeText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().replacingOccurrences(of: "_", with: " ")
        let names: [(String, Int)] = [
            ("analog kick", 0), ("synth kick", 1), ("synthetic kick", 1),
            ("analog snare", 2), ("synth snare", 3), ("synthetic snare", 3),
            ("hi hat", 4), ("hihat", 4),
        ]
        if let exact = names.first(where: { $0.0 == normalized }) {
            return Float(exact.1) / 4.0
        }
        if normalized.contains("kick") {
            return 0.0
        }
        if normalized.contains("snare") {
            return 2.0 / 4.0
        }
        if normalized.contains("hat") {
            return 4.0 / 4.0
        }
        return nil
    }

    private func ringsModelNormalized(modeText: String) -> Float? {
        let normalized = modeText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().replacingOccurrences(of: "_", with: " ")
        // Part resonator models (0-5)
        if normalized == "modal" { return 0.0 / 11.0 }
        if normalized == "sympathetic" { return 1.0 / 11.0 }
        if normalized == "string" { return 2.0 / 11.0 }
        if normalized == "fm voice" { return 3.0 / 11.0 }
        if normalized == "symp quant" || normalized == "quantized string" || normalized == "quantized_string" {
            return 4.0 / 11.0
        }
        if normalized == "string+rev" || normalized == "string rev" || normalized == "string reverb" {
            return 5.0 / 11.0
        }
        // StringSynthPart easter egg models (6-11)
        if normalized == "strsyn formant" || normalized == "string synth formant" { return 6.0 / 11.0 }
        if normalized == "strsyn chorus" || normalized == "string synth chorus" { return 7.0 / 11.0 }
        if normalized == "strsyn reverb" || normalized == "string synth reverb" { return 8.0 / 11.0 }
        if normalized == "strsyn form2" || normalized == "string synth formant 2" { return 9.0 / 11.0 }
        if normalized == "strsyn ensemble" || normalized == "string synth ensemble" { return 10.0 / 11.0 }
        if normalized == "strsyn rev2" || normalized == "string synth reverb 2" { return 11.0 / 11.0 }
        return nil
    }

    private func parseSessionKeyDescriptor(_ text: String) -> (rootNote: Int, scaleIndex: Int)? {
        let tokens = text
            .split(separator: " ", omittingEmptySubsequences: true)
            .map(String.init)
        guard let rootToken = tokens.first, let root = parsePitchClass(rootToken) else {
            return nil
        }
        let scaleText = tokens.dropFirst().joined(separator: " ")
        let scaleIndex: Int
        if scaleText.isEmpty {
            scaleIndex = readCurrentScaleIndex()
        } else if let parsedIndex = findScaleIndex(named: scaleText) {
            scaleIndex = parsedIndex
        } else {
            return nil
        }
        return (root, scaleIndex)
    }

    private func parsePitchClass(_ text: String) -> Int? {
        var token = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .replacingOccurrences(of: "♯", with: "#")
            .replacingOccurrences(of: "♭", with: "B")
        while let last = token.last, last.isNumber {
            token.removeLast()
        }
        let map: [String: Int] = [
            "C": 0, "B#": 0,
            "C#": 1, "DB": 1,
            "D": 2,
            "D#": 3, "EB": 3,
            "E": 4, "FB": 4,
            "F": 5, "E#": 5,
            "F#": 6, "GB": 6,
            "G": 7,
            "G#": 8, "AB": 8,
            "A": 9,
            "A#": 10, "BB": 10,
            "B": 11, "CB": 11,
        ]
        return map[token]
    }

    private func findScaleIndex(named text: String) -> Int? {
        let needle = normalizeScaleName(text)
        return readScaleOptions().first { normalizeScaleName($0.name) == needle }?.id
            ?? readScaleOptions().first { normalizeScaleName($0.name).contains(needle) || needle.contains(normalizeScaleName($0.name)) }?.id
    }

    private func normalizeScaleName(_ text: String) -> String {
        text.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    private func noteSlotForPitchClass(_ pitchClass: Int) -> Int? {
        let context = readScaleContext()
        guard !context.intervals.isEmpty else { return nil }
        let delta = (pitchClass - context.rootNote + 12) % 12

        if let exact = context.intervals.firstIndex(of: delta) {
            return exact
        }

        var bestIndex = 0
        var bestDistance = Int.max
        for (index, interval) in context.intervals.enumerated() {
            let up = (interval - delta + 12) % 12
            let down = (delta - interval + 12) % 12
            let distance = min(up, down)
            if distance < bestDistance {
                bestDistance = distance
                bestIndex = index
            }
        }
        return bestIndex
    }

    private func readTransportRunning() -> Bool {
        if Thread.isMainThread {
            return MainActor.assumeIsolated { [weak self] in
                self?.sequencer?.isPlaying ?? self?.audioEngine?.isClockRunning() ?? false
            }
        }

        var result = false
        DispatchQueue.main.sync {
            result = MainActor.assumeIsolated { [weak self] in
                self?.sequencer?.isPlaying ?? self?.audioEngine?.isClockRunning() ?? false
            }
        }
        return result
    }

    private func writeTransportRunning(_ running: Bool) {
        if Thread.isMainThread {
            MainActor.assumeIsolated { [weak self] in
                if running {
                    self?.sequencer?.start()
                } else {
                    self?.sequencer?.stop()
                }
            }
            return
        }
        DispatchQueue.main.sync {
            MainActor.assumeIsolated { [weak self] in
                if running {
                    self?.sequencer?.start()
                } else {
                    self?.sequencer?.stop()
                }
            }
        }
    }

    private func readCurrentScaleIndex() -> Int {
        if Thread.isMainThread {
            return MainActor.assumeIsolated { [weak self] in
                self?.sequencer?.scaleIndex ?? 0
            }
        }
        var result = 0
        DispatchQueue.main.sync {
            result = MainActor.assumeIsolated { [weak self] in
                self?.sequencer?.scaleIndex ?? 0
            }
        }
        return result
    }

    private func readScaleOptions() -> [SequencerScaleDefinition] {
        if Thread.isMainThread {
            return MainActor.assumeIsolated { [weak self] in
                self?.sequencer?.scaleOptions ?? []
            }
        }
        var result: [SequencerScaleDefinition] = []
        DispatchQueue.main.sync {
            result = MainActor.assumeIsolated { [weak self] in
                self?.sequencer?.scaleOptions ?? []
            }
        }
        return result
    }

    private func readScaleContext() -> (rootNote: Int, intervals: [Int]) {
        if Thread.isMainThread {
            return MainActor.assumeIsolated { [weak self] in
                let seq = self?.sequencer
                let root = seq?.rootNote ?? 0
                let scaleIndex = seq?.scaleIndex ?? 0
                let options = seq?.scaleOptions ?? []
                let index = min(max(scaleIndex, 0), max(options.count - 1, 0))
                return (root, options.isEmpty ? [0, 2, 4, 5, 7, 9, 11] : options[index].intervals)
            }
        }
        var result: (rootNote: Int, intervals: [Int]) = (0, [0, 2, 4, 5, 7, 9, 11])
        DispatchQueue.main.sync {
            result = MainActor.assumeIsolated { [weak self] in
                let seq = self?.sequencer
                let root = seq?.rootNote ?? 0
                let scaleIndex = seq?.scaleIndex ?? 0
                let options = seq?.scaleOptions ?? []
                let index = min(max(scaleIndex, 0), max(options.count - 1, 0))
                return (root, options.isEmpty ? [0, 2, 4, 5, 7, 9, 11] : options[index].intervals)
            }
        }
        return result
    }

    private func writeSequencerRootAndScale(rootNote: Int, scaleIndex: Int) {
        if Thread.isMainThread {
            MainActor.assumeIsolated { [weak self] in
                self?.sequencer?.setRootNote(rootNote)
                self?.sequencer?.setScaleIndex(scaleIndex)
            }
            return
        }
        DispatchQueue.main.sync {
            MainActor.assumeIsolated { [weak self] in
                self?.sequencer?.setRootNote(rootNote)
                self?.sequencer?.setScaleIndex(scaleIndex)
            }
        }
    }

    private func readTrackEnabled(trackIndex: Int) -> Bool {
        if Thread.isMainThread {
            return MainActor.assumeIsolated { [weak self] in
                guard let tracks = self?.sequencer?.tracks, tracks.indices.contains(trackIndex) else { return false }
                let track = tracks[trackIndex]
                return !track.muted
            }
        }
        var result = false
        DispatchQueue.main.sync {
            result = MainActor.assumeIsolated { [weak self] in
                guard let tracks = self?.sequencer?.tracks, tracks.indices.contains(trackIndex) else { return false }
                let track = tracks[trackIndex]
                return !track.muted
            }
        }
        return result
    }

    private func writeTrackEnabled(trackIndex: Int, enabled: Bool) {
        if Thread.isMainThread {
            MainActor.assumeIsolated { [weak self] in
                self?.sequencer?.setTrackMuted(trackIndex, !enabled)
            }
            return
        }
        DispatchQueue.main.sync {
            MainActor.assumeIsolated { [weak self] in
                self?.sequencer?.setTrackMuted(trackIndex, !enabled)
            }
        }
    }

    private func writeTrackDivision(trackIndex: Int, division: SequencerClockDivision) {
        if Thread.isMainThread {
            MainActor.assumeIsolated { [weak self] in
                self?.sequencer?.setTrackDivision(trackIndex, division)
            }
            return
        }
        DispatchQueue.main.sync {
            MainActor.assumeIsolated { [weak self] in
                self?.sequencer?.setTrackDivision(trackIndex, division)
            }
        }
    }

    private func writeTrackOutput(trackIndex: Int, output: SequencerTrackOutput) {
        if Thread.isMainThread {
            MainActor.assumeIsolated { [weak self] in
                self?.sequencer?.setTrackOutput(trackIndex, output)
            }
            return
        }
        DispatchQueue.main.sync {
            MainActor.assumeIsolated { [weak self] in
                self?.sequencer?.setTrackOutput(trackIndex, output)
            }
        }
    }

    private func writeTrackStageNoteSlot(trackIndex: Int, stage: Int, noteSlot: Int) {
        if Thread.isMainThread {
            MainActor.assumeIsolated { [weak self] in
                self?.sequencer?.setStageNoteSlot(track: trackIndex, stage: stage, value: noteSlot)
            }
            return
        }
        DispatchQueue.main.sync {
            MainActor.assumeIsolated { [weak self] in
                self?.sequencer?.setStageNoteSlot(track: trackIndex, stage: stage, value: noteSlot)
            }
        }
    }

    private func writeTrackStageProbability(trackIndex: Int, stage: Int, probability: Double) {
        if Thread.isMainThread {
            MainActor.assumeIsolated { [weak self] in
                self?.sequencer?.setStageProbability(track: trackIndex, stage: stage, value: probability)
            }
            return
        }
        DispatchQueue.main.sync {
            MainActor.assumeIsolated { [weak self] in
                self?.sequencer?.setStageProbability(track: trackIndex, stage: stage, value: probability)
            }
        }
    }

    private func writeTrackStageRatchets(trackIndex: Int, stage: Int, ratchets: Int) {
        if Thread.isMainThread {
            MainActor.assumeIsolated { [weak self] in
                self?.sequencer?.setStageRatchets(track: trackIndex, stage: stage, value: ratchets)
            }
            return
        }
        DispatchQueue.main.sync {
            MainActor.assumeIsolated { [weak self] in
                self?.sequencer?.setStageRatchets(track: trackIndex, stage: stage, value: ratchets)
            }
        }
    }

    private func writeTrackStageGateMode(trackIndex: Int, stage: Int, gateMode: SequencerGateMode) {
        if Thread.isMainThread {
            MainActor.assumeIsolated { [weak self] in
                self?.sequencer?.setStageGateMode(track: trackIndex, stage: stage, value: gateMode)
            }
            return
        }
        DispatchQueue.main.sync {
            MainActor.assumeIsolated { [weak self] in
                self?.sequencer?.setStageGateMode(track: trackIndex, stage: stage, value: gateMode)
            }
        }
    }

    private func writeTrackStageStepType(trackIndex: Int, stage: Int, stepType: SequencerStepType) {
        if Thread.isMainThread {
            MainActor.assumeIsolated { [weak self] in
                self?.sequencer?.setStageStepType(track: trackIndex, stage: stage, value: stepType)
            }
            return
        }
        DispatchQueue.main.sync {
            MainActor.assumeIsolated { [weak self] in
                self?.sequencer?.setStageStepType(track: trackIndex, stage: stage, value: stepType)
            }
        }
    }

    private func writeTrackStageGateLength(trackIndex: Int, stage: Int, gateLength: Double) {
        if Thread.isMainThread {
            MainActor.assumeIsolated { [weak self] in
                self?.sequencer?.setStageGateLength(track: trackIndex, stage: stage, value: gateLength)
            }
            return
        }
        DispatchQueue.main.sync {
            MainActor.assumeIsolated { [weak self] in
                self?.sequencer?.setStageGateLength(track: trackIndex, stage: stage, value: gateLength)
            }
        }
    }

    private func writeTrackStepGroup(trackIndex: Int, stageRange: ClosedRange<Int>, noteSlot: Int) {
        if Thread.isMainThread {
            MainActor.assumeIsolated { [weak self] in
                for stage in stageRange {
                    self?.sequencer?.setStageNoteSlot(track: trackIndex, stage: stage, value: noteSlot)
                }
            }
            return
        }
        DispatchQueue.main.sync {
            MainActor.assumeIsolated { [weak self] in
                for stage in stageRange {
                    self?.sequencer?.setStageNoteSlot(track: trackIndex, stage: stage, value: noteSlot)
                }
            }
        }
    }

    private func readTrack(trackIndex: Int) -> SequencerTrack? {
        if Thread.isMainThread {
            return MainActor.assumeIsolated { [weak self] in
                guard let tracks = self?.sequencer?.tracks, tracks.indices.contains(trackIndex) else { return nil }
                return tracks[trackIndex]
            }
        }
        var result: SequencerTrack?
        DispatchQueue.main.sync {
            result = MainActor.assumeIsolated { [weak self] in
                guard let tracks = self?.sequencer?.tracks, tracks.indices.contains(trackIndex) else { return nil }
                return tracks[trackIndex]
            }
        }
        return result
    }

    private func readTrackStage(trackIndex: Int, stage: Int) -> SequencerStage? {
        guard let track = readTrack(trackIndex: trackIndex), track.stages.indices.contains(stage) else {
            return nil
        }
        return track.stages[stage]
    }

    private func readSessionKeyText() -> String {
        let context = readScaleContext()
        let options = readScaleOptions()
        let scaleIndex = readCurrentScaleIndex()
        let safeIndex = min(max(scaleIndex, 0), max(options.count - 1, 0))
        let scaleName = options.isEmpty ? "major" : options[safeIndex].name
        return "\(pitchClassName(context.rootNote)) \(scaleName)"
    }

    private func readSynthModeName(parameter: ParameterID) -> String {
        let normalized = readGlobalParameter(id: parameter)
        switch parameter {
        case .plaitsModel:
            return plaitsModeName(fromNormalized: normalized)
        case .ringsModel:
            return ringsModeName(fromNormalized: normalized)
        case .daisyDrumEngine:
            return daisyDrumModeName(fromNormalized: normalized)
        default:
            return "unknown"
        }
    }

    private func readGlobalParameter(id: ParameterID) -> Float {
        if Thread.isMainThread {
            return MainActor.assumeIsolated { [weak self] in
                self?.audioEngine?.getParameter(id: id) ?? 0.0
            }
        }
        var result: Float = 0.0
        DispatchQueue.main.sync {
            result = MainActor.assumeIsolated { [weak self] in
                self?.audioEngine?.getParameter(id: id) ?? 0.0
            }
        }
        return result
    }

    private func readStepNoteName(trackIndex: Int, stage: Int) -> String? {
        guard let stageState = readTrackStage(trackIndex: trackIndex, stage: stage) else {
            return nil
        }
        return noteName(forNoteSlot: stageState.noteSlot)
    }

    private func noteName(forNoteSlot noteSlot: Int) -> String {
        let context = readScaleContext()
        guard !context.intervals.isEmpty else {
            return pitchClassName(context.rootNote)
        }
        let degree = max(noteSlot, 0)
        let interval = context.intervals[degree % context.intervals.count]
        let pitchClass = (context.rootNote + interval + 120) % 12
        return pitchClassName(pitchClass)
    }

    private func pitchClassName(_ pitchClass: Int) -> String {
        let names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let index = ((pitchClass % 12) + 12) % 12
        return names[index]
    }

    private func plaitsModeName(fromNormalized normalized: Float) -> String {
        let names = [
            "va vcf",
            "phase distortion",
            "six op fm a",
            "six op fm b",
            "six op fm c",
            "wave terrain",
            "string machine",
            "chiptune",
            "virtual analog",
            "waveshaping",
            "two op fm",
            "granular formant",
            "harmonic",
            "wavetable",
            "chords",
            "speech",
            "granular cloud",
            "filtered noise",
            "particle noise",
            "string",
            "modal",
            "bass drum",
            "snare drum",
            "hi hat",
        ]
        let clamped = clamp01(Double(normalized))
        let index = min(max(Int((clamped * 23.0).rounded()), 0), names.count - 1)
        return names[index]
    }

    private func ringsModeName(fromNormalized normalized: Float) -> String {
        let names = [
            "modal",
            "sympathetic",
            "string",
            "fm voice",
            "quantized string",
            "string+rev",
            // Easter egg: StringSynthPart FX variants
            "strsyn formant",
            "strsyn chorus",
            "strsyn reverb",
            "strsyn form2",
            "strsyn ensemble",
            "strsyn rev2",
        ]
        let clamped = clamp01(Double(normalized))
        let index = min(max(Int((clamped * 11.0).rounded()), 0), names.count - 1)
        return names[index]
    }

    private func trackPatternName(trackIndex: Int) -> String? {
        guard let track = readTrack(trackIndex: trackIndex) else { return nil }
        guard track.stages.count >= 8 else { return "custom" }
        let ascending = track.direction == .forward && (0...7).allSatisfy { stage in
            track.stages[stage].noteSlot == stage
        }
        return ascending ? "ascending" : "custom"
    }

    private func writeAscendingPattern(trackIndex: Int) {
        if Thread.isMainThread {
            MainActor.assumeIsolated { [weak self] in
                for stage in 0...7 {
                    self?.sequencer?.setStageNoteSlot(track: trackIndex, stage: stage, value: stage)
                }
                self?.sequencer?.setTrackDirection(trackIndex, .forward)
            }
            return
        }
        DispatchQueue.main.sync {
            MainActor.assumeIsolated { [weak self] in
                for stage in 0...7 {
                    self?.sequencer?.setStageNoteSlot(track: trackIndex, stage: stage, value: stage)
                }
                self?.sequencer?.setTrackDirection(trackIndex, .forward)
            }
        }
    }

    private func writeSynthMode(parameter: ParameterID, normalizedValue: Float) {
        if Thread.isMainThread {
            MainActor.assumeIsolated { [weak self] in
                self?.audioEngine?.setParameter(id: parameter, value: normalizedValue)
            }
            return
        }
        DispatchQueue.main.sync {
            MainActor.assumeIsolated { [weak self] in
                self?.audioEngine?.setParameter(id: parameter, value: normalizedValue)
            }
        }
    }

    private func writeGranularPlaying(voiceIndex: Int, playing: Bool) {
        if Thread.isMainThread {
            MainActor.assumeIsolated { [weak self] in
                self?.audioEngine?.setGranularPlaying(voiceIndex: voiceIndex, playing: playing)
            }
            return
        }
        DispatchQueue.main.sync {
            MainActor.assumeIsolated { [weak self] in
                self?.audioEngine?.setGranularPlaying(voiceIndex: voiceIndex, playing: playing)
            }
        }
    }

    private func writeGranularParameter(id: ParameterID, value: Float, voiceIndex: Int) {
        if Thread.isMainThread {
            MainActor.assumeIsolated { [weak self] in
                self?.audioEngine?.setParameter(id: id, value: value, voiceIndex: voiceIndex)
            }
            return
        }
        DispatchQueue.main.sync {
            MainActor.assumeIsolated { [weak self] in
                self?.audioEngine?.setParameter(id: id, value: value, voiceIndex: voiceIndex)
            }
        }
    }

    private func readGranularParameter(id: ParameterID, voiceIndex: Int) -> Float {
        if Thread.isMainThread {
            return MainActor.assumeIsolated { [weak self] in
                self?.audioEngine?.getParameter(id: id, voiceIndex: voiceIndex) ?? 0.0
            }
        }
        var result: Float = 0.0
        DispatchQueue.main.sync {
            result = MainActor.assumeIsolated { [weak self] in
                self?.audioEngine?.getParameter(id: id, voiceIndex: voiceIndex) ?? 0.0
            }
        }
        return result
    }

    private func granularEnvelopeName(from normalized: Float) -> String {
        let names = ["hann", "gaussian", "trap", "tri", "tukey", "pluck", "soft", "decay"]
        let index = min(max(Int((normalized * 7.0).rounded()), 0), names.count - 1)
        return names[index]
    }

    private func clamp01(_ value: Double) -> Double {
        min(max(value, 0.0), 1.0)
    }

    private func feedbackValueFromAction(_ action: ActionRequest) -> Double? {
        if let to = action.to { return to }
        if let from = action.from { return from }
        if let value = action.value {
            switch value {
            case .number(let number):
                return number
            case .string(let string):
                return Double(string)
            default:
                return nil
            }
        }
        return nil
    }

    private func modeTextFromAction(_ action: ActionRequest) -> String? {
        if let value = action.value {
            switch value {
            case .string(let text):
                return text
            default:
                return nil
            }
        }
        return nil
    }

    private func resolveVoiceTarget(fromActionTarget target: String?) -> VoiceTarget? {
        guard let target else { return nil }
        for voice in voiceTargets where target.hasPrefix(voice.id) {
            return voice
        }
        return nil
    }

    private func musicalDiff(bundle: ActionBundleRequest, risk: String) -> [String: Any] {
        let changes: [[String: Any]] = bundle.actions.map { action in
            var afterValue: Any = NSNull()
            if let number = feedbackValueFromAction(action) {
                afterValue = number
            } else if let mode = modeTextFromAction(action) {
                afterValue = mode
            }
            return [
                "path": action.target ?? "",
                "before": NSNull(),
                "after": afterValue,
            ]
        }
        return [
            "bundleId": bundle.bundleId,
            "risk": risk,
            "summary": "Bundle modifies \(bundle.actions.count) actions",
            "changes": changes,
            "timing": [
                "anchor": "now",
                "durationBars": NSNull(),
            ],
        ]
    }

    private func bundleToJSONObject(_ bundle: ActionBundleRequest) -> [String: Any] {
        var actionObjects: [[String: Any]] = []
        for action in bundle.actions {
            var object: [String: Any] = [
                "actionId": jsonOptional(action.actionId),
                "type": action.type,
                "target": jsonOptional(action.target),
                "from": jsonOptional(action.from),
                "to": jsonOptional(action.to),
            ]
            if let value = action.value {
                object["value"] = anyJSONValue(value)
            } else {
                object["value"] = NSNull()
            }
            actionObjects.append(object)
        }

        return [
            "bundleId": bundle.bundleId,
            "intentId": jsonOptional(bundle.intentId),
            "validationId": jsonOptional(bundle.validationId),
            "preconditionStateVersion": jsonOptional(bundle.preconditionStateVersion),
            "atomic": bundle.atomic,
            "requireConfirmation": jsonOptional(bundle.requireConfirmation),
            "actions": actionObjects,
        ]
    }

    private func anyJSONValue(_ value: JSONValue) -> Any {
        switch value {
        case .string(let text):
            return text
        case .number(let number):
            return number
        case .bool(let bool):
            return bool
        case .null:
            return NSNull()
        }
    }

    private func jsonOptional(_ value: Any?) -> Any {
        value ?? NSNull()
    }

    private func bundleSignature(_ bundle: ActionBundleRequest) -> String {
        let encoder = JSONEncoder()
        if #available(macOS 13.0, *) {
            encoder.outputFormatting = [.sortedKeys]
        }
        let data = (try? encoder.encode(bundle)) ?? Data()
        return data.base64EncodedString()
    }

    private func bundleSignatureForValidation(_ bundle: ActionBundleRequest) -> String {
        let canonical = ActionBundleRequest(
            bundleId: bundle.bundleId,
            intentId: bundle.intentId,
            validationId: nil,
            preconditionStateVersion: bundle.preconditionStateVersion,
            atomic: bundle.atomic,
            requireConfirmation: bundle.requireConfirmation,
            actions: bundle.actions
        )
        return bundleSignature(canonical)
    }

    private func bundlePrimaryTimeSpec(_ bundle: ActionBundleRequest) -> TimeSpecRequest? {
        for action in bundle.actions {
            if let time = action.time {
                return time
            }
        }
        return nil
    }

    private func purgeExpiredValidationRecords() {
        let now = Date()
        validationsById = validationsById.filter { _, record in
            record.expiresAt >= now
        }
    }

    private func value(forStatePath path: String) -> Any? {
        let transport = currentTransport()
        switch path {
        case "transport":
            return [
                "playing": transport.playing,
                "bar": transport.bar,
                "beat": transport.beat,
            ]
        case "transport.playing":
            return transport.playing
        case "transport.bar":
            return transport.bar
        case "transport.beat":
            return transport.beat
        case "session.tempoBpm":
            return readMasterClockBPM()
        case "session.key":
            return readSessionKeyText()
        case "synth.plaits.mode":
            return readSynthModeName(parameter: .plaitsModel)
        case "synth.plaits.harmonics":
            return readGlobalParameter(id: .plaitsHarmonics)
        case "synth.plaits.timbre":
            return readGlobalParameter(id: .plaitsTimbre)
        case "synth.plaits.morph":
            return readGlobalParameter(id: .plaitsMorph)
        case "synth.plaits.level":
            return readGlobalParameter(id: .plaitsLevel)
        case "synth.plaits.lpgColor":
            return readGlobalParameter(id: .plaitsLPGColor)
        case "synth.plaits.lpgDecay":
            return readGlobalParameter(id: .plaitsLPGDecay)
        case "synth.plaits.lpgAttack":
            return readGlobalParameter(id: .plaitsLPGAttack)
        case "synth.plaits.lpgBypass":
            return readGlobalParameter(id: .plaitsLPGBypass)
        case "synth.rings.mode":
            return readSynthModeName(parameter: .ringsModel)
        case "synth.rings.structure":
            return readGlobalParameter(id: .ringsStructure)
        case "synth.rings.brightness":
            return readGlobalParameter(id: .ringsBrightness)
        case "synth.rings.damping":
            return readGlobalParameter(id: .ringsDamping)
        case "synth.rings.position":
            return readGlobalParameter(id: .ringsPosition)
        case "synth.rings.level":
            return readGlobalParameter(id: .ringsLevel)
        case "synth.daisydrum.mode":
            return readSynthModeName(parameter: .daisyDrumEngine)
        case "synth.daisydrum.harmonics":
            return readGlobalParameter(id: .daisyDrumHarmonics)
        case "synth.daisydrum.timbre":
            return readGlobalParameter(id: .daisyDrumTimbre)
        case "synth.daisydrum.morph":
            return readGlobalParameter(id: .daisyDrumMorph)
        case "synth.sampler":
            return canonicalSamplerStatePayload()
        case "synth.sampler.mode":
            var mode = "soundfont"
            DispatchQueue.main.sync {
                MainActor.assumeIsolated { [weak self] in
                    switch self?.audioEngine?.activeSamplerMode {
                    case .sfz: mode = "sfz"
                    case .wavSampler: mode = "wavsampler"
                    default: mode = "soundfont"
                    }
                }
            }
            return mode
        case "synth.sampler.instrumentName":
            var name = ""
            DispatchQueue.main.sync {
                MainActor.assumeIsolated { [weak self] in
                    guard let engine = self?.audioEngine else { return }
                    switch engine.activeSamplerMode {
                    case .sfz:
                        name = engine.sfzInstrumentName
                    case .wavSampler:
                        name = engine.wavSamplerInstrumentName
                    case .soundFont:
                        if engine.soundFontLoaded {
                            let names = engine.soundFontPresetNames
                            let idx = engine.soundFontCurrentPreset
                            name = idx < names.count ? names[idx] : ""
                        }
                    }
                }
            }
            return name
        case "synth.sampler.preset":
            return readGlobalParameter(id: .samplerPreset)
        case "synth.sampler.attack":
            return readGlobalParameter(id: .samplerAttack)
        case "synth.sampler.decay":
            return readGlobalParameter(id: .samplerDecay)
        case "synth.sampler.sustain":
            return readGlobalParameter(id: .samplerSustain)
        case "synth.sampler.release":
            return readGlobalParameter(id: .samplerRelease)
        case "synth.sampler.filterCutoff":
            return readGlobalParameter(id: .samplerFilterCutoff)
        case "synth.sampler.filterResonance":
            return readGlobalParameter(id: .samplerFilterResonance)
        case "synth.sampler.tuning":
            return readGlobalParameter(id: .samplerTuning)
        case "synth.sampler.level":
            return readGlobalParameter(id: .samplerLevel)
        case "drums.playing":
            return readDrumSequencerProperty { $0.isPlaying }
        case "drums.syncToTransport":
            return readDrumSequencerProperty { $0.syncToTransport }
        case "drums.clockDivision":
            return readDrumSequencerProperty { $0.stepDivision.rawValue }
        case "drums.currentStep":
            return readDrumSequencerProperty { $0.currentStep + 1 }
        default:
            // Drum sequencer lane/step paths
            if let drumTarget = parseDrumSequencerTarget(path) {
                return readDrumSequencerValue(drumTarget)
            }
            if let trackTarget = parseSequencerTrackTarget(path) {
                let trackIndex = trackTarget.trackIndex
                guard let track = readTrack(trackIndex: trackIndex) else {
                    return nil
                }

                if let stepProperty = parseSequencerStepProperty(trackTarget.property),
                   let stage = readTrackStage(trackIndex: trackIndex, stage: stepProperty.stageIndex) {
                    switch stepProperty.field {
                    case "note":
                        return noteName(forNoteSlot: stage.noteSlot)
                    case "probability":
                        return stage.probability
                    case "ratchets":
                        return stage.ratchets
                    case "gateMode":
                        return stage.gateMode.rawValue.lowercased()
                    case "gateLength":
                        return stage.gateLength
                    case "stepType":
                        return stage.stepType.rawValue.lowercased()
                    default:
                        return nil
                    }
                }

                switch trackTarget.property {
                case "enabled":
                    return !track.muted
                case "pattern":
                    return trackPatternName(trackIndex: trackIndex)
                case "rateMultiplier":
                    return track.division.multiplier
                case "clockDivision":
                    return track.division.rawValue
                case "output":
                    return track.output.rawValue.lowercased()
                case "stepGroupA.note":
                    return readStepNoteName(trackIndex: trackIndex, stage: 0)
                case "stepGroupB.note":
                    return readStepNoteName(trackIndex: trackIndex, stage: 4)
                default:
                    return nil
                }
            }

            if path.hasSuffix(".speedRatio"), let target = parseGranularVoiceTarget(path) {
                let raw = readGranularParameter(id: .granularSpeed, voiceIndex: target.voice.reelIndex)
                return (Double(raw) - 0.5) * 4.0
            }
            if path.hasSuffix(".sizeMs"), let target = parseGranularVoiceTarget(path) {
                let raw = readGranularParameter(id: .granularSize, voiceIndex: target.voice.reelIndex)
                return pow(1000.0, Double(raw))
            }
            if path.hasSuffix(".pitchSemitones"), let target = parseGranularVoiceTarget(path) {
                let raw = readGranularParameter(id: .granularPitch, voiceIndex: target.voice.reelIndex)
                return (Double(raw) - 0.5) * 48.0
            }
            if path.hasSuffix(".envelope"), let target = parseGranularVoiceTarget(path) {
                let raw = readGranularParameter(id: .granularEnvelope, voiceIndex: target.voice.reelIndex)
                return granularEnvelopeName(from: raw)
            }
            if path.hasSuffix(".recording.active"), let target = resolveVoiceTarget(fromStatePath: path) {
                return recordingState(for: target).active
            }
            if path.hasSuffix(".recording.feedback"), let target = resolveVoiceTarget(fromStatePath: path) {
                return recordingState(for: target).feedback
            }
            if path.hasSuffix(".recording.mode"), let target = resolveVoiceTarget(fromStatePath: path) {
                return recordingState(for: target).mode
            }
            return nil
        }
    }

    private func handleListRecordingVoices() -> HTTPResponse {
        let list = voiceTargets.map { target -> [String: Any] in
            let state = recordingState(for: target)
            return [
                "voiceId": target.id,
                "module": target.module,
                "isRecording": state.active,
                "mode": state.mode,
                "feedback": state.feedback,
                "inputLevel": NSNull(),
                "recordedDurationMs": NSNull(),
            ]
        }
        return .json(statusCode: 200, payload: list)
    }

    private func handleStartRecording(_ request: HTTPRequest) -> HTTPResponse {
        guard let voice = resolveVoiceTarget(fromRecordingPath: request.path) else {
            return errorResponse(statusCode: 404, reason: "Not Found", code: .notFound, message: "Unknown voice id")
        }
        guard let payload = tryDecode(RecordingStartRequest.self, from: request.body) else {
            return errorResponse(statusCode: 400, reason: "Bad Request", code: .badRequest, message: "Invalid recording start payload")
        }

        if let replay = idempotencyReplayIfPresent(key: payload.idempotencyKey, request: request) {
            return replay
        }

        let mode = mapRecordMode(apiMode: payload.mode)
        guard let mode else {
            return errorResponse(statusCode: 422, reason: "Unprocessable Entity", code: .recordingModeUnsupported, message: "Unsupported recording mode")
        }

        let resolvedSource = resolveRecordingSource(sourceType: payload.sourceType, sourceChannel: payload.sourceChannel)
        guard let sourceType = resolvedSource.sourceType else {
            return errorResponse(statusCode: 422, reason: "Unprocessable Entity", code: .badRequest, message: "Unsupported recording sourceType")
        }
        let sourceChannel = resolvedSource.sourceChannel
        if sourceChannel < 0 || sourceChannel > 10 {
            return errorResponse(statusCode: 422, reason: "Unprocessable Entity", code: .actionOutOfRange, message: "sourceChannel must be within [0, 10]")
        }

        let active = readIsReelRecording(voice.reelIndex)
        if active {
            return errorResponse(statusCode: 422, reason: "Unprocessable Entity", code: .recordingAlreadyActive, message: "Voice is already recording")
        }

        let scheduledTime = resolveScheduledTime(timeSpec: payload.time)
        scheduleExecution(at: scheduledTime) { [weak self] in
            guard let self else { return }
            if self.readIsReelRecording(voice.reelIndex) {
                return
            }
            self.writeStartRecording(
                reelIndex: voice.reelIndex,
                mode: mode,
                sourceType: sourceType,
                sourceChannel: sourceChannel,
                feedback: payload.feedback
            )
            self.recordMutation(
                changedPaths: [
                    "\(voice.id).recording.active",
                    "\(voice.id).recording.mode",
                    "\(voice.id).recording.feedback",
                ],
                additionalEvents: [
                    (
                        type: "recording.started",
                        payload: [
                            "voiceId": voice.id,
                            "mode": self.apiMode(from: mode),
                            "feedback": payload.feedback ?? Double(voice.defaultFeedback),
                        ]
                    ),
                ]
            )
        }

        let responsePayload: [String: Any] = [
            "voiceId": voice.id,
            "status": "scheduled",
            "scheduledAtTransport": [
                "bar": scheduledTime.bar,
                "beat": scheduledTime.beat,
            ],
        ]
        let response = HTTPResponse.json(statusCode: 202, reason: "Accepted", payload: responsePayload)
        recordIdempotency(key: payload.idempotencyKey, request: request, response: response)
        return response
    }

    private func handleStopRecording(_ request: HTTPRequest) -> HTTPResponse {
        guard let voice = resolveVoiceTarget(fromRecordingPath: request.path) else {
            return errorResponse(statusCode: 404, reason: "Not Found", code: .notFound, message: "Unknown voice id")
        }
        guard let payload = tryDecode(RecordingStopRequest.self, from: request.body) else {
            return errorResponse(statusCode: 400, reason: "Bad Request", code: .badRequest, message: "Invalid recording stop payload")
        }

        if let replay = idempotencyReplayIfPresent(key: payload.idempotencyKey, request: request) {
            return replay
        }

        let active = readIsReelRecording(voice.reelIndex)
        if !active {
            return errorResponse(statusCode: 422, reason: "Unprocessable Entity", code: .recordingNotActive, message: "Voice is not recording")
        }

        let scheduledTime = resolveScheduledTime(timeSpec: payload.time)
        scheduleExecution(at: scheduledTime) { [weak self] in
            guard let self else { return }
            if !self.readIsReelRecording(voice.reelIndex) {
                return
            }
            self.writeStopRecording(reelIndex: voice.reelIndex)
            self.recordMutation(
                changedPaths: ["\(voice.id).recording.active"],
                additionalEvents: [
                    (
                        type: "recording.stopped",
                        payload: [
                            "voiceId": voice.id,
                            "recordedDurationMs": NSNull(),
                        ]
                    ),
                ]
            )
        }

        let responsePayload: [String: Any] = [
            "voiceId": voice.id,
            "status": "scheduled",
            "scheduledAtTransport": [
                "bar": scheduledTime.bar,
                "beat": scheduledTime.beat,
            ],
        ]
        let response = HTTPResponse.json(statusCode: 202, reason: "Accepted", payload: responsePayload)
        recordIdempotency(key: payload.idempotencyKey, request: request, response: response)
        return response
    }

    private func handleSetRecordingFeedback(_ request: HTTPRequest) -> HTTPResponse {
        guard let voice = resolveVoiceTarget(fromRecordingPath: request.path) else {
            return errorResponse(statusCode: 404, reason: "Not Found", code: .notFound, message: "Unknown voice id")
        }
        guard let payload = tryDecode(RecordingFeedbackRequest.self, from: request.body) else {
            return errorResponse(statusCode: 400, reason: "Bad Request", code: .badRequest, message: "Invalid recording feedback payload")
        }

        if let replay = idempotencyReplayIfPresent(key: payload.idempotencyKey, request: request) {
            return replay
        }

        guard payload.value >= 0.0, payload.value <= 1.0 else {
            return errorResponse(statusCode: 422, reason: "Unprocessable Entity", code: .actionOutOfRange, message: "Feedback must be within [0.0, 1.0]")
        }

        let currentMode = currentRecordMode(for: voice)
        guard currentMode == .liveLoop else {
            return errorResponse(statusCode: 422, reason: "Unprocessable Entity", code: .recordingFeedbackUnsupported, message: "Feedback is only supported in overdub/live modes")
        }

        let scheduledTime = resolveScheduledTime(timeSpec: payload.time)
        scheduleExecution(at: scheduledTime) { [weak self] in
            guard let self else { return }
            guard self.currentRecordMode(for: voice) == .liveLoop else {
                return
            }
            let before = self.readRecordingModeAndFeedback(
                reelIndex: voice.reelIndex,
                defaultMode: voice.defaultMode,
                defaultFeedback: voice.defaultFeedback
            ).feedback
            self.writeSetRecordingFeedback(reelIndex: voice.reelIndex, feedback: Float(payload.value))
            self.recordMutation(
                changedPaths: ["\(voice.id).recording.feedback"],
                additionalEvents: [
                    (
                        type: "recording.feedback_changed",
                        payload: [
                            "voiceId": voice.id,
                            "previous": before,
                            "current": payload.value,
                        ]
                    ),
                ]
            )
        }

        let responsePayload: [String: Any] = [
            "voiceId": voice.id,
            "status": "scheduled",
            "target": "\(voice.id).recording.feedback",
            "scheduledAtTransport": [
                "bar": scheduledTime.bar,
                "beat": scheduledTime.beat,
            ],
        ]
        let response = HTTPResponse.json(statusCode: 202, reason: "Accepted", payload: responsePayload)
        recordIdempotency(key: payload.idempotencyKey, request: request, response: response)
        return response
    }

    private func handleSetRecordingMode(_ request: HTTPRequest) -> HTTPResponse {
        guard let voice = resolveVoiceTarget(fromRecordingPath: request.path) else {
            return errorResponse(statusCode: 404, reason: "Not Found", code: .notFound, message: "Unknown voice id")
        }
        guard let payload = tryDecode(RecordingModeRequest.self, from: request.body) else {
            return errorResponse(statusCode: 400, reason: "Bad Request", code: .badRequest, message: "Invalid recording mode payload")
        }

        if let replay = idempotencyReplayIfPresent(key: payload.idempotencyKey, request: request) {
            return replay
        }

        guard let mode = mapRecordMode(apiMode: payload.mode) else {
            return errorResponse(statusCode: 422, reason: "Unprocessable Entity", code: .recordingModeUnsupported, message: "Unsupported recording mode")
        }

        let scheduledTime = resolveScheduledTime(timeSpec: payload.time)
        scheduleExecution(at: scheduledTime) { [weak self] in
            guard let self else { return }
            let before = self.currentRecordMode(for: voice)
            guard before != mode else {
                return
            }
            self.writeSetRecordingMode(reelIndex: voice.reelIndex, mode: mode)
            self.recordMutation(
                changedPaths: ["\(voice.id).recording.mode"],
                additionalEvents: [
                    (
                        type: "recording.mode_changed",
                        payload: [
                            "voiceId": voice.id,
                            "previous": self.apiMode(from: before),
                            "current": self.apiMode(from: mode),
                        ]
                    ),
                ]
            )
        }

        let responsePayload: [String: Any] = [
            "voiceId": voice.id,
            "status": "scheduled",
            "target": "\(voice.id).recording.mode",
            "scheduledAtTransport": [
                "bar": scheduledTime.bar,
                "beat": scheduledTime.beat,
            ],
        ]
        let response = HTTPResponse.json(statusCode: 202, reason: "Accepted", payload: responsePayload)
        recordIdempotency(key: payload.idempotencyKey, request: request, response: response)
        return response
    }

    private func resolveVoiceTarget(fromRecordingPath path: String) -> VoiceTarget? {
        // Expected path: /v1/recording/voices/{voiceId}/(start|stop|feedback|mode)
        let prefix = "/v1/recording/voices/"
        guard path.hasPrefix(prefix) else { return nil }
        let tail = path.dropFirst(prefix.count)
        let parts = tail.split(separator: "/")
        guard parts.count >= 2 else { return nil }
        let voiceId = String(parts[0])
        return voiceTargets.first { $0.id == voiceId }
    }

    private func resolveVoiceTarget(fromStatePath path: String) -> VoiceTarget? {
        for voice in voiceTargets {
            if path.hasPrefix(voice.id) {
                return voice
            }
        }
        return nil
    }

    private func mapRecordMode(apiMode: String) -> AudioEngineWrapper.RecordMode? {
        switch apiMode {
        case "replace":
            return .oneShot
        case "append":
            return .oneShot
        case "overdub":
            return .liveLoop
        case "live_overdub":
            return .liveLoop
        default:
            return nil
        }
    }

    private func mapRecordSourceType(apiSourceType: String?) -> AudioEngineWrapper.RecordSourceType? {
        guard let apiSourceType else { return .external }
        switch apiSourceType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "external", "mic", "line":
            return .external
        case "internal", "internal_voice", "internalvoice":
            return .internalVoice
        default:
            return nil
        }
    }

    /// Resolves a recording source from named drum sources or falls back to standard sourceType/sourceChannel.
    /// Named drum sources (e.g. "drums", "kick", "snare") automatically set the correct sourceChannel.
    private func resolveRecordingSource(sourceType: String?, sourceChannel: Int?) -> (sourceType: AudioEngineWrapper.RecordSourceType?, sourceChannel: Int) {
        if let sourceType {
            let key = sourceType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            switch key {
            // Named drum sources — auto-resolve to internalVoice with correct channel
            case "drums", "drum", "drum_bus", "drumbus":
                return (.internalVoice, 6)
            case "kick", "analog_kick", "analogkick":
                return (.internalVoice, 7)
            case "synth_kick", "synthkick", "synth_kick_drum":
                return (.internalVoice, 8)
            case "snare", "analog_snare", "analogsnare":
                return (.internalVoice, 9)
            case "hihat", "hi_hat", "hi-hat", "hat":
                return (.internalVoice, 10)
            case "sampler", "sample", "sf2", "wav_sampler", "soundfont":
                return (.internalVoice, 11)
            default:
                // Fall through to standard resolution
                break
            }
        }
        // Standard resolution: use mapRecordSourceType + explicit sourceChannel
        let resolved = mapRecordSourceType(apiSourceType: sourceType)
        return (resolved, sourceChannel ?? 0)
    }

    private func recordingSourcesList() -> [[String: Any]] {
        [
            ["name": "external", "aliases": ["mic", "line"], "sourceType": "external"],
            ["name": "macro_osc", "aliases": ["plaits"], "channel": 0, "sourceType": "internal"],
            ["name": "resonator", "aliases": ["rings"], "channel": 1, "sourceType": "internal"],
            ["name": "granular1", "channel": 2, "sourceType": "internal"],
            ["name": "looper1", "channel": 3, "sourceType": "internal"],
            ["name": "looper2", "channel": 4, "sourceType": "internal"],
            ["name": "granular4", "channel": 5, "sourceType": "internal"],
            ["name": "drums", "aliases": ["drum", "drum_bus"], "channel": 6, "sourceType": "internal", "description": "All drum lanes mixed"],
            ["name": "kick", "aliases": ["analog_kick"], "channel": 7, "sourceType": "internal", "description": "Analog Kick lane only"],
            ["name": "synth_kick", "channel": 8, "sourceType": "internal", "description": "Synth Kick lane only"],
            ["name": "snare", "aliases": ["analog_snare"], "channel": 9, "sourceType": "internal", "description": "Analog Snare lane only"],
            ["name": "hihat", "aliases": ["hi_hat", "hi-hat"], "channel": 10, "sourceType": "internal", "description": "Hi-Hat lane only"],
            ["name": "sampler", "aliases": ["sample", "sf2", "soundfont"], "channel": 11, "sourceType": "internal", "description": "Sampler output (SF2 or WAV)"],
        ]
    }

    private func apiMode(from mode: AudioEngineWrapper.RecordMode) -> String {
        switch mode {
        case .oneShot:
            return "replace"
        case .liveLoop:
            return "live_overdub"
        }
    }

    private func currentRecordMode(for voice: VoiceTarget) -> AudioEngineWrapper.RecordMode {
        readRecordingModeAndFeedback(
            reelIndex: voice.reelIndex,
            defaultMode: voice.defaultMode,
            defaultFeedback: voice.defaultFeedback
        ).mode
    }

    private func recordingState(for voice: VoiceTarget) -> (active: Bool, mode: String, feedback: Float) {
        let active = readIsReelRecording(voice.reelIndex)
        let mode = currentRecordMode(for: voice)
        let feedback = readRecordingModeAndFeedback(
            reelIndex: voice.reelIndex,
            defaultMode: voice.defaultMode,
            defaultFeedback: voice.defaultFeedback
        ).feedback
        return (active, apiMode(from: mode), feedback)
    }

    private func currentTransport() -> (playing: Bool, bar: Int, beat: Double) {
        let playing = readClockRunning()
        let bpm = max(1.0, readMasterClockBPM())
        let sampleRate = max(1.0, readSampleRate())
        let sampleTime = readCurrentSampleTime()
        let startSample = readClockStartSample()
        let elapsed = sampleTime > startSample ? Double(sampleTime - startSample) : 0
        let samplesPerBeat = sampleRate * 60.0 / Double(bpm)
        let totalBeats = samplesPerBeat > 0 ? elapsed / samplesPerBeat : 0
        let qnPerBar = readQuarterNotesPerBar()
        let bar = max(1, Int(totalBeats / qnPerBar) + 1)
        let beat = (totalBeats.truncatingRemainder(dividingBy: qnPerBar)) + 1.0
        return (playing, bar, beat)
    }

    private func readQuarterNotesPerBar() -> Double {
        // Read directly from C++ engine via cached handle — atomic read, thread-safe
        guard let handle = cachedEngineHandle else { return 4.0 }
        return Double(AudioEngine_GetQuarterNotesPerBar(handle))
    }

    private func readTimeSignatureString() -> String {
        // Read directly from C++ engine via cached handle — atomic reads, thread-safe
        guard let handle = cachedEngineHandle else { return "4/4" }
        let num = AudioEngine_GetTimeSignatureNumerator(handle)
        let den = AudioEngine_GetTimeSignatureDenominator(handle)
        return "\(num)/\(den)"
    }

    private func resolveScheduledTime(timeSpec: TimeSpecRequest?) -> ScheduledTime {
        let transport = currentTransport()
        let bpm = max(1.0, Double(readMasterClockBPM()))
        let qnPerBar = readQuarterNotesPerBar()
        let secondsPerBeat = 60.0 / bpm

        let target = ConversationalRoutingCore.resolveTargetTransport(
            current: .init(bar: transport.bar, beat: transport.beat, bpm: bpm, quarterNotesPerBar: qnPerBar),
            timeSpec: .init(anchor: timeSpec?.anchor, quantization: timeSpec?.quantization)
        )
        let beatsDelta = target.beatsDelta
        let executeAt = Date().addingTimeInterval(beatsDelta * secondsPerBeat)
        return ScheduledTime(executeAt: executeAt, bar: target.bar, beat: target.beat)
    }

    private func scheduleExecution(at scheduledTime: ScheduledTime, _ operation: @escaping @Sendable () -> Void) {
        let delay = max(0.0, scheduledTime.executeAt.timeIntervalSinceNow)
        if delay <= 0.005 {
            queue.async(execute: operation)
        } else {
            queue.asyncAfter(deadline: .now() + delay, execute: operation)
        }
    }

    private func idempotencyReplayIfPresent(key: String, request: HTTPRequest, setReplayFlag: Bool = false) -> HTTPResponse? {
        guard let existing = idempotency[key] else { return nil }
        let signature = signatureForIdempotency(request: request)
        if existing.signature != signature {
            return errorResponse(statusCode: 409, reason: "Conflict", code: .idempotencyConflict, message: "Idempotency key was already used with a different payload")
        }

        var body = existing.responseBody
        if setReplayFlag,
           var object = (try? JSONSerialization.jsonObject(with: body, options: [])) as? [String: Any] {
            object["idempotentReplay"] = true
            body = (try? JSONSerialization.data(withJSONObject: object, options: [])) ?? body
        }

        return HTTPResponse(
            statusCode: setReplayFlag ? 200 : existing.statusCode,
            reason: setReplayFlag ? "OK" : (existing.statusCode == 202 ? "Accepted" : "OK"),
            headers: ["Content-Type": "application/json"],
            body: body
        )
    }

    private func recordIdempotency(key: String, request: HTTPRequest, response: HTTPResponse) {
        idempotency[key] = IdempotencyRecord(
            signature: signatureForIdempotency(request: request),
            statusCode: response.statusCode,
            responseBody: response.body
        )
    }

    private func signatureForIdempotency(request: HTTPRequest) -> String {
        "\(request.method)|\(request.path)|\(request.body.base64EncodedString())"
    }

    private func tryDecode<T: Decodable>(_ type: T.Type, from data: Data) -> T? {
        try? jsonDecoder.decode(type, from: data)
    }

    private func send(_ response: HTTPResponse, on connection: NWConnection) {
        var headers = response.headers
        headers["Content-Length"] = "\(response.body.count)"
        headers["Connection"] = "close"

        var head = "HTTP/1.1 \(response.statusCode) \(response.reason)\r\n"
        for (k, v) in headers {
            head += "\(k): \(v)\r\n"
        }
        head += "\r\n"

        var data = Data(head.utf8)
        data.append(response.body)

        connection.send(content: data, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private func errorResponse(statusCode: Int, reason: String, code: BridgeErrorCode, message: String, details: [String: Any]? = nil) -> HTTPResponse {
        var errorPayload: [String: Any] = [
            "code": code.rawValue,
            "message": message,
        ]
        if let details {
            errorPayload["details"] = details
        }
        return .json(
            statusCode: statusCode,
            reason: reason,
            payload: ["error": errorPayload]
        )
    }

    private func iso8601(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    private func readMasterClockBPM() -> Float {
        // Read directly from C++ engine via cached handle — atomic read, thread-safe
        guard let handle = cachedEngineHandle else { return 120.0 }
        return AudioEngine_GetClockBPM(handle)
    }

    private func writeMasterClockBPM(_ bpm: Double) {
        let clamped = max(20.0, min(300.0, bpm))
        if Thread.isMainThread {
            MainActor.assumeIsolated { [weak self] in
                self?.masterClock?.bpm = clamped
            }
            return
        }
        DispatchQueue.main.sync {
            MainActor.assumeIsolated { [weak self] in
                self?.masterClock?.bpm = clamped
            }
        }
    }

    private func readClockRunning() -> Bool {
        // Read directly from C++ engine via cached handle — atomic read, thread-safe
        guard let handle = cachedEngineHandle else { return false }
        return AudioEngine_IsClockRunning(handle)
    }

    private func readSampleRate() -> Double {
        // Sample rate is set once at init and cached — immutable after startup
        return cachedSampleRate
    }

    private func readCurrentSampleTime() -> UInt64 {
        // Read directly from C++ engine via cached handle — atomic read, thread-safe
        guard let handle = cachedEngineHandle else { return 0 }
        return AudioEngine_GetCurrentSampleTime(handle)
    }

    private func readClockStartSample() -> UInt64 {
        // Read directly from C++ engine via cached handle — atomic read, thread-safe
        guard let handle = cachedEngineHandle else { return 0 }
        return AudioEngine_GetClockStartSample(handle)
    }

    private func readIsReelRecording(_ reelIndex: Int) -> Bool {
        // Call the C++ engine directly — IsRecording() reads an atomic<bool>
        // so it's safe from any thread. This avoids DispatchQueue.main.sync
        // which can deadlock when main thread is busy with waveform updates.
        guard let handle = cachedEngineHandle else { return false }
        return AudioEngine_IsRecording(handle, Int32(reelIndex))
    }

    private func readRecordingModeAndFeedback(
        reelIndex: Int,
        defaultMode: AudioEngineWrapper.RecordMode,
        defaultFeedback: Float
    ) -> (mode: AudioEngineWrapper.RecordMode, feedback: Float) {
        if Thread.isMainThread {
            return MainActor.assumeIsolated { [weak self] in
                let state = self?.audioEngine?.recordingStates[reelIndex]
                return (state?.mode ?? defaultMode, state?.feedback ?? defaultFeedback)
            }
        }

        var result: (mode: AudioEngineWrapper.RecordMode, feedback: Float) = (defaultMode, defaultFeedback)
        DispatchQueue.main.sync {
            result = MainActor.assumeIsolated { [weak self] in
                let state = self?.audioEngine?.recordingStates[reelIndex]
                return (state?.mode ?? defaultMode, state?.feedback ?? defaultFeedback)
            }
        }
        return result
    }

    private func writeStartRecording(
        reelIndex: Int,
        mode: AudioEngineWrapper.RecordMode,
        sourceType: AudioEngineWrapper.RecordSourceType = .external,
        sourceChannel: Int = 0,
        feedback: Double?
    ) {
        let clampedFeedback: Float? = feedback.map { Float(max(0.0, min(1.0, $0))) }
        if Thread.isMainThread {
            MainActor.assumeIsolated { [weak self] in
                // Stop granular playback before recording to avoid buffer read/write hazard
                self?.audioEngine?.setGranularPlaying(voiceIndex: reelIndex, playing: false)
                self?.audioEngine?.startRecording(
                    reelIndex: reelIndex,
                    mode: mode,
                    sourceType: sourceType,
                    sourceChannel: sourceChannel
                )
                if let clampedFeedback {
                    self?.audioEngine?.setRecordingFeedback(reelIndex: reelIndex, feedback: clampedFeedback)
                }
            }
            return
        }

        DispatchQueue.main.sync {
            MainActor.assumeIsolated { [weak self] in
                // Stop granular playback before recording to avoid buffer read/write hazard
                self?.audioEngine?.setGranularPlaying(voiceIndex: reelIndex, playing: false)
                self?.audioEngine?.startRecording(
                    reelIndex: reelIndex,
                    mode: mode,
                    sourceType: sourceType,
                    sourceChannel: sourceChannel
                )
                if let clampedFeedback {
                    self?.audioEngine?.setRecordingFeedback(reelIndex: reelIndex, feedback: clampedFeedback)
                }
            }
        }
    }

    private func writeStopRecording(reelIndex: Int) {
        if Thread.isMainThread {
            MainActor.assumeIsolated { [weak self] in
                self?.audioEngine?.stopRecording(reelIndex: reelIndex)
            }
            return
        }

        DispatchQueue.main.sync {
            MainActor.assumeIsolated { [weak self] in
                self?.audioEngine?.stopRecording(reelIndex: reelIndex)
            }
        }
    }

    private func writeSetRecordingFeedback(reelIndex: Int, feedback: Float) {
        if Thread.isMainThread {
            MainActor.assumeIsolated { [weak self] in
                self?.audioEngine?.setRecordingFeedback(reelIndex: reelIndex, feedback: feedback)
            }
            return
        }

        DispatchQueue.main.sync {
            MainActor.assumeIsolated { [weak self] in
                self?.audioEngine?.setRecordingFeedback(reelIndex: reelIndex, feedback: feedback)
            }
        }
    }

    private func writeSetRecordingMode(reelIndex: Int, mode: AudioEngineWrapper.RecordMode) {
        if Thread.isMainThread {
            MainActor.assumeIsolated { [weak self] in
                var state = self?.audioEngine?.recordingStates[reelIndex] ?? AudioEngineWrapper.RecordingUIState()
                state.mode = mode
                self?.audioEngine?.recordingStates[reelIndex] = state
            }
            return
        }

        DispatchQueue.main.sync {
            MainActor.assumeIsolated { [weak self] in
                var state = self?.audioEngine?.recordingStates[reelIndex] ?? AudioEngineWrapper.RecordingUIState()
                state.mode = mode
                self?.audioEngine?.recordingStates[reelIndex] = state
            }
        }
    }

    // MARK: - Drum Sequencer Target Parsing

    /// Parsed drum sequencer target: "drums.lane1.step3.active" → lane=0, step=2, property="active"
    private struct DrumSequencerTarget {
        let property: String       // Top-level: "playing", "syncToTransport", "clockDivision"
        let laneIndex: Int?        // 0-3 (nil for top-level targets)
        let stepIndex: Int?        // 0-15 (nil for lane-level targets)
        let stepField: String?     // "active", "velocity" (nil for non-step targets)
    }

    private func parseDrumSequencerTarget(_ target: String) -> DrumSequencerTarget? {
        guard target.hasPrefix("drums.") else { return nil }
        let remainder = String(target.dropFirst(6)) // Drop "drums."

        // Top-level targets
        switch remainder {
        case "playing":
            return DrumSequencerTarget(property: "playing", laneIndex: nil, stepIndex: nil, stepField: nil)
        case "syncToTransport":
            return DrumSequencerTarget(property: "syncToTransport", laneIndex: nil, stepIndex: nil, stepField: nil)
        case "clockDivision":
            return DrumSequencerTarget(property: "clockDivision", laneIndex: nil, stepIndex: nil, stepField: nil)
        case "currentStep":
            return DrumSequencerTarget(property: "currentStep", laneIndex: nil, stepIndex: nil, stepField: nil)
        default:
            break
        }

        // Lane targets: "lane1.enabled", "lane2.step3.active"
        guard remainder.hasPrefix("lane") else { return nil }
        let laneRemainder = String(remainder.dropFirst(4)) // Drop "lane"

        // Parse lane number
        guard let dotIndex = laneRemainder.firstIndex(of: ".") else { return nil }
        let laneNumStr = String(laneRemainder[laneRemainder.startIndex..<dotIndex])
        guard let laneNum = Int(laneNumStr), (1...4).contains(laneNum) else { return nil }
        let laneIndex = laneNum - 1
        let laneProp = String(laneRemainder[laneRemainder.index(after: dotIndex)...])

        // Lane-level properties
        switch laneProp {
        case "enabled", "level", "harmonics", "timbre", "morph", "note", "pattern":
            return DrumSequencerTarget(property: laneProp, laneIndex: laneIndex, stepIndex: nil, stepField: nil)
        default:
            break
        }

        // Step-level: "step3.active"
        guard laneProp.hasPrefix("step") else { return nil }
        let stepRemainder = String(laneProp.dropFirst(4)) // Drop "step"
        guard let stepDot = stepRemainder.firstIndex(of: ".") else { return nil }
        let stepNumStr = String(stepRemainder[stepRemainder.startIndex..<stepDot])
        guard let stepNum = Int(stepNumStr), (1...16).contains(stepNum) else { return nil }
        let stepIndex = stepNum - 1
        let stepField = String(stepRemainder[stepRemainder.index(after: stepDot)...])

        guard stepField == "active" || stepField == "velocity" else { return nil }
        return DrumSequencerTarget(property: "step", laneIndex: laneIndex, stepIndex: stepIndex, stepField: stepField)
    }

    // MARK: - Drum Sequencer Validation

    private func validateDrumSequencerAction(_ action: ActionRequest, target: DrumSequencerTarget) -> (handled: Bool, failure: ActionFailure?) {
        switch target.property {
        case "playing", "syncToTransport":
            if action.type == "toggle" || boolValueFromAction(action) != nil {
                return (true, nil)
            }
            return (true, ActionFailure(actionId: action.actionId, code: .badRequest, message: "drums.\(target.property) requires a boolean value"))

        case "clockDivision":
            guard let text = modeTextFromAction(action), divisionFromText(text) != nil else {
                return (true, ActionFailure(actionId: action.actionId, code: .badRequest, message: "Unsupported drums clockDivision"))
            }
            return (true, nil)

        case "enabled":
            guard target.laneIndex != nil else {
                return (true, ActionFailure(actionId: action.actionId, code: .badRequest, message: "Lane index required"))
            }
            if action.type == "toggle" || boolValueFromAction(action) != nil {
                return (true, nil)
            }
            return (true, ActionFailure(actionId: action.actionId, code: .badRequest, message: "drums lane enabled requires boolean value"))

        case "level", "harmonics", "timbre", "morph":
            guard target.laneIndex != nil else {
                return (true, ActionFailure(actionId: action.actionId, code: .badRequest, message: "Lane index required"))
            }
            guard let value = feedbackValueFromAction(action), value >= 0.0, value <= 1.0 else {
                return (true, ActionFailure(actionId: action.actionId, code: .actionOutOfRange, message: "drums lane \(target.property) must be within [0.0, 1.0]"))
            }
            return (true, nil)

        case "note":
            guard target.laneIndex != nil else {
                return (true, ActionFailure(actionId: action.actionId, code: .badRequest, message: "Lane index required"))
            }
            guard let noteVal = feedbackValueFromAction(action), noteVal >= 24.0, noteVal <= 96.0 else {
                return (true, ActionFailure(actionId: action.actionId, code: .actionOutOfRange, message: "drums lane note must be MIDI note 24-96"))
            }
            return (true, nil)

        case "pattern":
            guard target.laneIndex != nil else {
                return (true, ActionFailure(actionId: action.actionId, code: .badRequest, message: "Lane index required"))
            }
            guard let text = modeTextFromAction(action), drumLanePatternSteps(text) != nil else {
                return (true, ActionFailure(actionId: action.actionId, code: .badRequest, message: "Unsupported drum pattern. Use: fourOnTheFloor, backbeat, straight16ths, straight8ths, offbeats, clear"))
            }
            return (true, nil)

        case "step":
            guard target.laneIndex != nil, let stepField = target.stepField else {
                return (true, ActionFailure(actionId: action.actionId, code: .badRequest, message: "Step target requires lane and step index"))
            }
            switch stepField {
            case "active":
                if action.type == "toggle" || boolValueFromAction(action) != nil {
                    return (true, nil)
                }
                return (true, ActionFailure(actionId: action.actionId, code: .badRequest, message: "drums step active requires boolean value"))
            case "velocity":
                guard let value = feedbackValueFromAction(action), value >= 0.0, value <= 1.0 else {
                    return (true, ActionFailure(actionId: action.actionId, code: .actionOutOfRange, message: "drums step velocity must be within [0.0, 1.0]"))
                }
                return (true, nil)
            default:
                return (true, ActionFailure(actionId: action.actionId, code: .notFound, message: "Unsupported drum step field"))
            }

        default:
            return (true, ActionFailure(actionId: action.actionId, code: .notFound, message: "Unsupported drum sequencer target"))
        }
    }

    // MARK: - Drum Sequencer Apply

    private func applyDrumSequencerAction(_ action: ActionRequest, target: DrumSequencerTarget) -> (handled: Bool, failure: ActionFailure?) {
        switch target.property {
        case "playing":
            let current = readDrumSequencerProperty { $0.isPlaying } ?? false
            guard let desired = desiredBoolValue(for: action, current: current) else {
                return (true, ActionFailure(actionId: action.actionId, code: .badRequest, message: "drums.playing requires boolean value"))
            }
            writeDrumSequencer { drumSeq in
                if desired { drumSeq.start() } else { drumSeq.stop() }
            }
            recordMutation(
                changedPaths: ["drums.playing"],
                additionalEvents: [(type: "drums.playing_changed", payload: ["playing": desired])]
            )
            return (true, nil)

        case "syncToTransport":
            let current = readDrumSequencerProperty { $0.syncToTransport } ?? false
            guard let desired = desiredBoolValue(for: action, current: current) else {
                return (true, ActionFailure(actionId: action.actionId, code: .badRequest, message: "drums.syncToTransport requires boolean value"))
            }
            writeDrumSequencer { drumSeq in drumSeq.syncToTransport = desired }
            recordMutation(
                changedPaths: ["drums.syncToTransport"],
                additionalEvents: [(type: "drums.param_changed", payload: ["param": "syncToTransport", "value": desired])]
            )
            return (true, nil)

        case "clockDivision":
            guard let text = modeTextFromAction(action), let division = divisionFromText(text) else {
                return (true, ActionFailure(actionId: action.actionId, code: .badRequest, message: "Unsupported drums clockDivision"))
            }
            writeDrumSequencer { drumSeq in drumSeq.stepDivision = division }
            recordMutation(
                changedPaths: ["drums.clockDivision"],
                additionalEvents: [(type: "drums.param_changed", payload: ["param": "clockDivision", "value": division.rawValue])]
            )
            return (true, nil)

        case "enabled":
            guard let laneIndex = target.laneIndex else {
                return (true, ActionFailure(actionId: action.actionId, code: .badRequest, message: "Lane index required"))
            }
            let current = readDrumSequencerProperty { !$0.lanes[laneIndex].isMuted } ?? false
            guard let desired = desiredBoolValue(for: action, current: current) else {
                return (true, ActionFailure(actionId: action.actionId, code: .badRequest, message: "drums lane enabled requires boolean value"))
            }
            writeDrumSequencer { drumSeq in drumSeq.setLaneMuted(laneIndex, muted: !desired) }
            let path = "drums.lane\(laneIndex + 1).enabled"
            recordMutation(
                changedPaths: [path],
                additionalEvents: [(type: "drums.lane_changed", payload: ["lane": laneIndex + 1, "param": "enabled", "value": desired])]
            )
            return (true, nil)

        case "level":
            guard let laneIndex = target.laneIndex else {
                return (true, ActionFailure(actionId: action.actionId, code: .badRequest, message: "Lane index required"))
            }
            guard let value = feedbackValueFromAction(action), value >= 0.0, value <= 1.0 else {
                return (true, ActionFailure(actionId: action.actionId, code: .actionOutOfRange, message: "drums lane level must be within [0.0, 1.0]"))
            }
            writeDrumSequencer { drumSeq in drumSeq.setLaneLevel(laneIndex, value: Float(value)) }
            let path = "drums.lane\(laneIndex + 1).level"
            recordMutation(
                changedPaths: [path],
                additionalEvents: [(type: "drums.lane_changed", payload: ["lane": laneIndex + 1, "param": "level", "value": value])]
            )
            return (true, nil)

        case "harmonics":
            guard let laneIndex = target.laneIndex else {
                return (true, ActionFailure(actionId: action.actionId, code: .badRequest, message: "Lane index required"))
            }
            guard let value = feedbackValueFromAction(action), value >= 0.0, value <= 1.0 else {
                return (true, ActionFailure(actionId: action.actionId, code: .actionOutOfRange, message: "drums lane harmonics must be within [0.0, 1.0]"))
            }
            writeDrumSequencer { drumSeq in drumSeq.setLaneHarmonics(laneIndex, value: Float(value)) }
            let path = "drums.lane\(laneIndex + 1).harmonics"
            recordMutation(
                changedPaths: [path],
                additionalEvents: [(type: "drums.lane_changed", payload: ["lane": laneIndex + 1, "param": "harmonics", "value": value])]
            )
            return (true, nil)

        case "timbre":
            guard let laneIndex = target.laneIndex else {
                return (true, ActionFailure(actionId: action.actionId, code: .badRequest, message: "Lane index required"))
            }
            guard let value = feedbackValueFromAction(action), value >= 0.0, value <= 1.0 else {
                return (true, ActionFailure(actionId: action.actionId, code: .actionOutOfRange, message: "drums lane timbre must be within [0.0, 1.0]"))
            }
            writeDrumSequencer { drumSeq in drumSeq.setLaneTimbre(laneIndex, value: Float(value)) }
            let path = "drums.lane\(laneIndex + 1).timbre"
            recordMutation(
                changedPaths: [path],
                additionalEvents: [(type: "drums.lane_changed", payload: ["lane": laneIndex + 1, "param": "timbre", "value": value])]
            )
            return (true, nil)

        case "morph":
            guard let laneIndex = target.laneIndex else {
                return (true, ActionFailure(actionId: action.actionId, code: .badRequest, message: "Lane index required"))
            }
            guard let value = feedbackValueFromAction(action), value >= 0.0, value <= 1.0 else {
                return (true, ActionFailure(actionId: action.actionId, code: .actionOutOfRange, message: "drums lane morph must be within [0.0, 1.0]"))
            }
            writeDrumSequencer { drumSeq in drumSeq.setLaneMorph(laneIndex, value: Float(value)) }
            let path = "drums.lane\(laneIndex + 1).morph"
            recordMutation(
                changedPaths: [path],
                additionalEvents: [(type: "drums.lane_changed", payload: ["lane": laneIndex + 1, "param": "morph", "value": value])]
            )
            return (true, nil)

        case "note":
            guard let laneIndex = target.laneIndex else {
                return (true, ActionFailure(actionId: action.actionId, code: .badRequest, message: "Lane index required"))
            }
            guard let noteVal = feedbackValueFromAction(action) else {
                return (true, ActionFailure(actionId: action.actionId, code: .badRequest, message: "drums lane note requires numeric MIDI note"))
            }
            let midiNote = UInt8(min(max(Int(noteVal.rounded()), 24), 96))
            writeDrumSequencer { drumSeq in drumSeq.setLaneNote(laneIndex, note: midiNote) }
            let path = "drums.lane\(laneIndex + 1).note"
            recordMutation(
                changedPaths: [path],
                additionalEvents: [(type: "drums.lane_changed", payload: ["lane": laneIndex + 1, "param": "note", "value": Int(midiNote)])]
            )
            return (true, nil)

        case "pattern":
            guard let laneIndex = target.laneIndex else {
                return (true, ActionFailure(actionId: action.actionId, code: .badRequest, message: "Lane index required"))
            }
            guard let text = modeTextFromAction(action), let activeSteps = drumLanePatternSteps(text) else {
                return (true, ActionFailure(actionId: action.actionId, code: .badRequest, message: "Unsupported drum pattern"))
            }
            writeDrumSequencer { drumSeq in
                drumSeq.clearLane(laneIndex)
                for stepIndex in activeSteps {
                    drumSeq.setStepActive(lane: laneIndex, step: stepIndex, active: true)
                }
            }
            let path = "drums.lane\(laneIndex + 1).pattern"
            recordMutation(
                changedPaths: [path],
                additionalEvents: [(type: "drums.pattern_changed", payload: ["lane": laneIndex + 1, "pattern": text.lowercased()])]
            )
            return (true, nil)

        case "step":
            guard let laneIndex = target.laneIndex,
                  let stepIndex = target.stepIndex,
                  let stepField = target.stepField else {
                return (true, ActionFailure(actionId: action.actionId, code: .badRequest, message: "Step target requires lane and step index"))
            }
            switch stepField {
            case "active":
                let current = readDrumSequencerProperty { $0.lanes[laneIndex].steps[stepIndex].isActive } ?? false
                guard let desired = desiredBoolValue(for: action, current: current) else {
                    return (true, ActionFailure(actionId: action.actionId, code: .badRequest, message: "drums step active requires boolean value"))
                }
                writeDrumSequencer { drumSeq in drumSeq.setStepActive(lane: laneIndex, step: stepIndex, active: desired) }
                let path = "drums.lane\(laneIndex + 1).step\(stepIndex + 1).active"
                recordMutation(
                    changedPaths: [path],
                    additionalEvents: [(type: "drums.step_changed", payload: ["lane": laneIndex + 1, "step": stepIndex + 1, "field": "active", "value": desired])]
                )
                return (true, nil)
            case "velocity":
                guard let value = feedbackValueFromAction(action), value >= 0.0, value <= 1.0 else {
                    return (true, ActionFailure(actionId: action.actionId, code: .actionOutOfRange, message: "drums step velocity must be within [0.0, 1.0]"))
                }
                writeDrumSequencer { drumSeq in
                    drumSeq.setStepVelocity(lane: laneIndex, step: stepIndex, velocity: Float(value))
                }
                let path = "drums.lane\(laneIndex + 1).step\(stepIndex + 1).velocity"
                recordMutation(
                    changedPaths: [path],
                    additionalEvents: [(type: "drums.step_changed", payload: ["lane": laneIndex + 1, "step": stepIndex + 1, "field": "velocity", "value": value])]
                )
                return (true, nil)
            default:
                return (true, ActionFailure(actionId: action.actionId, code: .notFound, message: "Unsupported drum step field"))
            }

        default:
            return (true, ActionFailure(actionId: action.actionId, code: .notFound, message: "Unsupported drum sequencer target"))
        }
    }

    // MARK: - Drum Pattern Presets

    /// Returns the set of active step indices (0-based) for a named drum pattern.
    private func drumLanePatternSteps(_ patternName: String) -> [Int]? {
        switch patternName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) {
        case "fouronthefloor", "four on the floor", "4otf":
            return [0, 4, 8, 12]  // Steps 1,5,9,13
        case "backbeat", "back beat":
            return [4, 12]  // Steps 5,13
        case "straight16ths", "straight 16ths", "16ths", "sixteenths":
            return Array(0..<16)
        case "straight8ths", "straight 8ths", "8ths", "eighths":
            return [0, 2, 4, 6, 8, 10, 12, 14]
        case "offbeats", "off beats", "offbeat":
            return [2, 6, 10, 14]  // Steps 3,7,11,15
        case "halftime", "half time":
            return [0, 8]  // Steps 1,9
        case "clear", "empty", "none":
            return []
        default:
            return nil
        }
    }

    // MARK: - Drum Sequencer Read Helpers

    /// Unified read helper that runs a closure on the main actor to safely access DrumSequencer properties.
    private func readDrumSequencerProperty<T>(_ accessor: @escaping @MainActor (DrumSequencer) -> T) -> T? {
        if Thread.isMainThread {
            return MainActor.assumeIsolated { [weak self] in
                guard let drumSeq = self?.drumSequencer else { return nil }
                return accessor(drumSeq)
            }
        }
        return DispatchQueue.main.sync {
            MainActor.assumeIsolated { [weak self] in
                guard let drumSeq = self?.drumSequencer else { return nil as T? }
                return accessor(drumSeq)
            }
        }
    }

    private func readDrumSequencerValue(_ target: DrumSequencerTarget) -> Any? {
        return DispatchQueue.main.sync {
            MainActor.assumeIsolated { [weak self] in
                guard let drumSeq = self?.drumSequencer else { return nil as Any? }

                // Lane-level read
                if let laneIndex = target.laneIndex {
                    guard laneIndex < drumSeq.lanes.count else { return nil as Any? }
                    let lane = drumSeq.lanes[laneIndex]

                    // Step-level read
                    if let stepIndex = target.stepIndex, let stepField = target.stepField {
                        guard stepIndex < DrumSequencer.numSteps else { return nil as Any? }
                        let step = lane.steps[stepIndex]
                        switch stepField {
                        case "active": return step.isActive as Any?
                        case "velocity": return step.velocity as Any?
                        default: return nil as Any?
                        }
                    }

                    switch target.property {
                    case "enabled": return !lane.isMuted as Any?
                    case "level": return lane.level as Any?
                    case "harmonics": return lane.harmonics as Any?
                    case "timbre": return lane.timbre as Any?
                    case "morph": return lane.morph as Any?
                    case "note": return Int(lane.note) as Any?
                    default: return nil as Any?
                    }
                }

                // Top-level reads handled in value(forStatePath:) switch
                return nil as Any?
            }
        }
    }

    // MARK: - Drum Sequencer Write Helper

    private func writeDrumSequencer(_ block: @escaping @MainActor (DrumSequencer) -> Void) {
        if Thread.isMainThread {
            MainActor.assumeIsolated { [weak self] in
                guard let drumSeq = self?.drumSequencer else { return }
                block(drumSeq)
            }
            return
        }

        DispatchQueue.main.sync {
            MainActor.assumeIsolated { [weak self] in
                guard let drumSeq = self?.drumSequencer else { return }
                block(drumSeq)
            }
        }
    }
}
