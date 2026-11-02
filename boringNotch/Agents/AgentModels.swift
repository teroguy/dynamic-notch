//
//  AgentModels.swift
//  boringNotch
//
//  Created for AI Agent Integration (Claude Code, Codex, and others).
//

import Foundation
import SwiftUI

// MARK: - Supported Agent Types
public enum AgentType: String, Codable, CaseIterable, Identifiable {
    case claudeCode = "claude"
    case codex = "codex"
    case gemini = "gemini"
    case cursor = "cursor"
    case opencode = "opencode"
    case hermes = "hermes"
    case generic = "agent"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .claudeCode: return "Claude Code"
        case .codex: return "Codex"
        case .gemini: return "Gemini CLI"
        case .cursor: return "Cursor"
        case .opencode: return "OpenCode"
        case .hermes: return "Hermes"
        case .generic: return "AI Agent"
        }
    }

    public var systemIcon: String {
        switch self {
        case .claudeCode: return "sparkles"
        case .codex: return "cpu"
        case .gemini: return "diamond.fill"
        case .cursor: return "cursorarrow.rays"
        case .opencode: return "chevron.left.forwardslash.chevron.right"
        case .hermes: return "paperplane.fill"
        case .generic: return "terminal.fill"
        }
    }

    public var brandColor: Color {
        switch self {
        case .claudeCode: return Color(red: 0.85, green: 0.45, blue: 0.25) // Terracotta / Anthropic warm orange
        case .codex: return Color(red: 0.1, green: 0.65, blue: 0.5)      // OpenAI emerald
        case .gemini: return Color(red: 0.25, green: 0.5, blue: 0.95)    // Google blue
        case .cursor: return Color(red: 0.4, green: 0.4, blue: 0.9)      // Slate indigo
        case .opencode: return Color(red: 0.9, green: 0.6, blue: 0.1)    // Warm yellow
        case .hermes: return Color(red: 0.8, green: 0.3, blue: 0.6)      // Magenta
        case .generic: return Color.accentColor
        }
    }

    public static func from(source: String?) -> AgentType {
        guard let s = source?.lowercased() else { return .generic }
        if s.contains("claude") { return .claudeCode }
        if s.contains("codex") { return .codex }
        if s.contains("gemini") { return .gemini }
        if s.contains("cursor") { return .cursor }
        if s.contains("opencode") { return .opencode }
        if s.contains("hermes") { return .hermes }
        return .generic
    }
}

// MARK: - Session Status
public enum AgentSessionStatus: String, Codable, Equatable {
    case running = "running"
    case waitingForApproval = "waiting_approval"
    case waitingForAnswer = "waiting_answer"
    case idle = "idle"
    case completed = "completed"
    case error = "error"

    public var displayLabel: String {
        switch self {
        case .running: return "В процессе"
        case .waitingForApproval: return "Требует аппрува"
        case .waitingForAnswer: return "Вопрос"
        case .idle: return "В ожидании"
        case .completed: return "Завершено"
        case .error: return "Ошибка"
        }
    }

    public var statusColor: Color {
        switch self {
        case .running: return Color.green
        case .waitingForApproval: return Color.orange
        case .waitingForAnswer: return Color.purple
        case .idle: return Color.gray
        case .completed: return Color.blue
        case .error: return Color.red
        }
    }

    public var statusIcon: String {
        switch self {
        case .running: return "gearshape.arrow.triangle.2.circlepath"
        case .waitingForApproval: return "exclamationmark.shield.fill"
        case .waitingForAnswer: return "questionmark.circle.fill"
        case .idle: return "pause.circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .error: return "xmark.octagon.fill"
        }
    }
}

// MARK: - Interactive Question Models (AskUserQuestion)
public struct AgentQuestionOption: Identifiable, Codable, Hashable {
    public var id: String { label }
    public let label: String
    public let description: String?

    public init(label: String, description: String? = nil) {
        self.label = label
        self.description = description
    }
}

public struct AgentQuestion: Identifiable, Codable {
    public var id: String { header.isEmpty ? question : header }
    public let header: String
    public let question: String
    public let options: [AgentQuestionOption]
    public let multiSelect: Bool

    public init(header: String, question: String, options: [AgentQuestionOption], multiSelect: Bool = false) {
        self.header = header
        self.question = question
        self.options = options
        self.multiSelect = multiSelect
    }
}

// MARK: - Permission Request Model
public struct AgentPermissionRequest: Identifiable, Codable {
    public let id: String
    public let toolName: String
    public let command: String?
    public let filePath: String?
    public let description: String?
    public let questions: [AgentQuestion]?
    public let rawInput: [String: AnyCodable]?
    public let timestamp: Date

    public init(
        id: String = UUID().uuidString,
        toolName: String,
        command: String? = nil,
        filePath: String? = nil,
        description: String? = nil,
        questions: [AgentQuestion]? = nil,
        rawInput: [String: AnyCodable]? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.toolName = toolName
        self.command = command
        self.filePath = filePath
        self.description = description
        self.questions = questions
        self.rawInput = rawInput
        self.timestamp = timestamp
    }
}

// MARK: - Connection wrapper for pending permission/question requests
public class AgentPendingConnection {
    public let fileDescriptor: Int32
    public let sessionId: String
    private var isClosed = false
    private let lock = NSLock()

    public init(fileDescriptor: Int32, sessionId: String) {
        self.fileDescriptor = fileDescriptor
        self.sessionId = sessionId
    }

    public func respond(with jsonString: String) {
        lock.lock()
        defer { lock.unlock() }
        guard !isClosed else { return }
        isClosed = true

        guard let data = jsonString.data(using: .utf8) else {
            close(fileDescriptor)
            return
        }

        data.withUnsafeBytes { rawBuffer in
            guard let ptr = rawBuffer.baseAddress else { return }
            var written = 0
            let total = data.count
            while written < total {
                let res = write(fileDescriptor, ptr + written, total - written)
                if res <= 0 { break }
                written += res
            }
        }
        close(fileDescriptor)
    }

    public func closeConnection() {
        lock.lock()
        defer { lock.unlock() }
        guard !isClosed else { return }
        isClosed = true
        close(fileDescriptor)
    }

    deinit {
        closeConnection()
    }
}

// MARK: - Agent Session
public class AgentSession: Identifiable, ObservableObject, Equatable {
    public static func == (lhs: AgentSession, rhs: AgentSession) -> Bool {
        lhs.id == rhs.id && lhs.updatedAt == rhs.updatedAt && lhs.status == rhs.status
    }

    public let id: String
    public let agentType: AgentType
    @Published public var cwd: String
    @Published public var projectName: String
    @Published public var gitBranch: String?
    @Published public var status: AgentSessionStatus
    @Published public var currentTool: String?
    @Published public var lastPrompt: String?
    @Published public var pendingPermission: AgentPermissionRequest?
    @Published public var terminalAppName: String?
    public let startedAt: Date
    @Published public var updatedAt: Date

    // Active socket connection for waiting PermissionRequest
    public var pendingConnection: AgentPendingConnection?
    public var rawToolInput: [String: Any]?

    public init(
        id: String,
        agentType: AgentType = .claudeCode,
        cwd: String = "",
        status: AgentSessionStatus = .running,
        lastPrompt: String? = nil,
        terminalAppName: String? = nil
    ) {
        self.id = id
        self.agentType = agentType
        self.cwd = cwd
        self.projectName = AgentSession.extractProjectName(from: cwd)
        self.gitBranch = AgentSession.detectGitBranch(for: cwd)
        self.status = status
        self.lastPrompt = lastPrompt
        self.terminalAppName = terminalAppName
        self.startedAt = Date()
        self.updatedAt = Date()
    }

    public static func extractProjectName(from path: String) -> String {
        guard !path.isEmpty else { return "Terminal" }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path == home || path == "\(home)/" || path == "/Users/\(NSUserName())" {
            return "Home (~)"
        }
        let url = URL(fileURLWithPath: path)
        let name = url.lastPathComponent
        return name.isEmpty ? "Project" : name
    }

    public static func detectGitBranch(for path: String) -> String? {
        guard !path.isEmpty else { return nil }
        let headURL = URL(fileURLWithPath: path).appendingPathComponent(".git/HEAD")
        guard let content = try? String(contentsOf: headURL, encoding: .utf8) else { return nil }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("ref: refs/heads/") {
            return String(trimmed.dropFirst("ref: refs/heads/".count))
        }
        return String(trimmed.prefix(7)) // detached commit hash
    }
}

// MARK: - AnyCodable helper for parsing arbitrary tool_input
public struct AnyCodable: Codable, Equatable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let boolVal = try? container.decode(Bool.self) {
            value = boolVal
        } else if let intVal = try? container.decode(Int.self) {
            value = intVal
        } else if let doubleVal = try? container.decode(Double.self) {
            value = doubleVal
        } else if let stringVal = try? container.decode(String.self) {
            value = stringVal
        } else if let arrayVal = try? container.decode([AnyCodable].self) {
            value = arrayVal.map { $0.value }
        } else if let dictVal = try? container.decode([String: AnyCodable].self) {
            value = dictVal.mapValues { $0.value }
        } else {
            value = ()
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let b as Bool: try container.encode(b)
        case let i as Int: try container.encode(i)
        case let d as Double: try container.encode(d)
        case let s as String: try container.encode(s)
        case let arr as [Any]: try container.encode(arr.map { AnyCodable($0) })
        case let dict as [String: Any]: try container.encode(dict.mapValues { AnyCodable($0) })
        default: break
        }
    }

    public static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        String(describing: lhs.value) == String(describing: rhs.value)
    }
}
