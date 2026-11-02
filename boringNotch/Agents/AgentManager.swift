//
//  AgentManager.swift
//  boringNotch
//
//  Created for AI Agent Integration.
//  Coordinates active AI coding agent sessions, permissions, and question answering.
//

import AppKit
import Combine
import Defaults
import Foundation
import SwiftUI

@MainActor
public final class AgentManager: ObservableObject {
    public static let shared = AgentManager()

    @Published public private(set) var sessions: [AgentSession] = []
    @Published public private(set) var activeSessionCount: Int = 0
    @Published public private(set) var pendingApprovalCount: Int = 0
    @Published public private(set) var latestPendingSession: AgentSession?

    private var cancellables = Set<AnyCancellable>()

    private init() {
        // Auto cleanup finished sessions after 1 hour
        Timer.publish(every: 300, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.cleanupStaleSessions()
            }
            .store(in: &cancellables)
    }

    public var hasActiveSessions: Bool {
        activeSessionCount > 0
    }

    public var activeSessions: [AgentSession] {
        sessions.filter { $0.status == .running || $0.status == .waitingForApproval || $0.status == .waitingForAnswer }
    }

    public var primaryActiveSession: AgentSession? {
        // Prioritize sessions needing attention (waiting for approval/answer)
        if let pending = sessions.first(where: { $0.status == .waitingForApproval || $0.status == .waitingForAnswer }) {
            return pending
        }
        return sessions.first(where: { $0.status == .running }) ?? sessions.first
    }

    // MARK: - Event Handling
    public func handleEvent(
        eventName: String,
        sessionId: String,
        source: String,
        cwd: String,
        toolName: String?,
        toolInput: [String: Any]?,
        prompt: String?,
        raw: [String: Any]
    ) {
        let session = getOrCreateSession(id: sessionId, source: source, cwd: cwd)
        session.updatedAt = Date()

        switch eventName {
        case "SessionStart", "on_session_start":
            session.status = .running
            if !cwd.isEmpty {
                session.cwd = cwd
                session.projectName = AgentSession.extractProjectName(from: cwd)
                session.gitBranch = AgentSession.detectGitBranch(for: cwd)
            }
            session.terminalAppName = detectCurrentTerminalApp()

        case "UserPromptSubmit", "pre_llm_call":
            session.status = .running
            session.currentTool = nil
            if let p = prompt ?? raw["user_message"] as? String {
                session.lastPrompt = p
            }

        case "PreToolUse", "pre_tool_call":
            session.status = .running
            if let t = toolName ?? raw["tool_name"] as? String {
                session.currentTool = formatToolDisplay(toolName: t, input: toolInput)
            }

        case "PostToolUse", "post_tool_call":
            session.status = .running
            session.currentTool = nil

        case "Stop", "StopFailure", "on_session_finalize":
            session.status = (eventName == "StopFailure") ? .error : .idle
            session.currentTool = nil
            session.pendingPermission = nil
            session.pendingConnection?.closeConnection()
            session.pendingConnection = nil

        case "SessionEnd", "on_session_end":
            let isError = (raw["interrupted"] as? Bool == true) || (raw["reason"] as? String == "error")
            session.status = isError ? .error : .completed
            session.currentTool = nil
            session.pendingPermission = nil
            session.pendingConnection?.closeConnection()
            session.pendingConnection = nil

        default:
            break
        }

        updateCounts()
    }

    // MARK: - Permission & Question Requests
    public func handlePermissionRequest(
        sessionId: String,
        source: String,
        cwd: String,
        toolName: String,
        toolInput: [String: Any]?,
        pendingConnection: AgentPendingConnection
    ) {
        let session = getOrCreateSession(id: sessionId, source: source, cwd: cwd)
        session.updatedAt = Date()
        session.pendingConnection?.closeConnection()
        session.pendingConnection = pendingConnection

        let isQuestion = (toolName == "AskUserQuestion" || toolName == "ask")
        var questions: [AgentQuestion]?

        if isQuestion, let input = toolInput {
            questions = parseQuestions(from: input)
        }

        let command = toolInput?["command"] as? String
        let filePath = (toolInput?["file_path"] as? String) ?? (toolInput?["path"] as? String)
        let desc = (toolInput?["description"] as? String)

        let permissionReq = AgentPermissionRequest(
            toolName: toolName,
            command: command,
            filePath: filePath,
            description: desc,
            questions: questions,
            rawInput: nil,
            timestamp: Date()
        )

        session.pendingPermission = permissionReq
        session.rawToolInput = toolInput
        session.status = (isQuestion && questions?.isEmpty == false) ? .waitingForAnswer : .waitingForApproval
        session.currentTool = isQuestion ? "Answering Question" : "Approval: \(toolName)"

        updateCounts()
        notifyUser(for: session)
    }

    // MARK: - Decision Actions
    public func approve(session: AgentSession) {
        guard let connection = session.pendingConnection else {
            session.pendingPermission = nil
            session.status = .running
            updateCounts()
            return
        }

        let response: [String: Any] = [
            "hookSpecificOutput": [
                "hookEventName": "PermissionRequest",
                "decision": [
                    "behavior": "allow"
                ]
            ]
        ]

        if let data = try? JSONSerialization.data(withJSONObject: response),
           let jsonString = String(data: data, encoding: .utf8) {
            connection.respond(with: jsonString + "\n")
        } else {
            connection.respond(with: "{\"hookSpecificOutput\":{\"hookEventName\":\"PermissionRequest\",\"decision\":{\"behavior\":\"allow\"}}}\n")
        }

        session.pendingPermission = nil
        session.pendingConnection = nil
        session.status = .running
        session.updatedAt = Date()
        updateCounts()
    }

    public func deny(session: AgentSession, reason: String? = nil) {
        guard let connection = session.pendingConnection else {
            session.pendingPermission = nil
            session.status = .running
            updateCounts()
            return
        }

        let denialReason = reason ?? "Declined from Boring Notch"
        let response: [String: Any] = [
            "hookSpecificOutput": [
                "hookEventName": "PermissionRequest",
                "decision": [
                    "behavior": "deny",
                    "reason": denialReason
                ]
            ]
        ]

        if let data = try? JSONSerialization.data(withJSONObject: response),
           let jsonString = String(data: data, encoding: .utf8) {
            connection.respond(with: jsonString + "\n")
        } else {
            connection.respond(with: "{\"hookSpecificOutput\":{\"hookEventName\":\"PermissionRequest\",\"decision\":{\"behavior\":\"deny\",\"reason\":\"\(denialReason)\"}}}\n")
        }

        session.pendingPermission = nil
        session.pendingConnection = nil
        session.status = .running
        session.updatedAt = Date()
        updateCounts()
    }

    public func answerQuestion(session: AgentSession, answers: [String: String]) {
        guard let connection = session.pendingConnection else {
            session.pendingPermission = nil
            session.status = .running
            updateCounts()
            return
        }

        var updatedInput: [String: Any] = session.rawToolInput ?? [:]
        updatedInput["answers"] = answers

        let response: [String: Any] = [
            "hookSpecificOutput": [
                "hookEventName": "PermissionRequest",
                "decision": [
                    "behavior": "allow",
                    "updatedInput": updatedInput
                ]
            ]
        ]

        if let data = try? JSONSerialization.data(withJSONObject: response),
           let jsonString = String(data: data, encoding: .utf8) {
            connection.respond(with: jsonString + "\n")
        } else {
            connection.respond(with: "{\"hookSpecificOutput\":{\"hookEventName\":\"PermissionRequest\",\"decision\":{\"behavior\":\"allow\"}}}\n")
        }

        session.pendingPermission = nil
        session.pendingConnection = nil
        session.status = .running
        session.currentTool = "Thinking..."
        session.updatedAt = Date()
        updateCounts()
    }

    // MARK: - Terminal Focus Jump-back
    public func focusTerminal(for session: AgentSession) {
        let appName = session.terminalAppName ?? detectCurrentTerminalApp() ?? "Ghostty"

        let appleScript = """
        tell application "\(appName)"
            activate
        end tell
        """

        var error: NSDictionary?
        if let script = NSAppleScript(source: appleScript) {
            script.executeAndReturnError(&error)
        }

        if error != nil {
            // Fallback: try NSWorkspace by app name
            let ws = NSWorkspace.shared
            if let running = ws.runningApplications.first(where: {
                $0.localizedName?.localizedCaseInsensitiveContains(appName) == true
            }) {
                running.activate(options: [.activateIgnoringOtherApps])
            }
        }
    }

    public func removeSession(id: String) {
        if let index = sessions.firstIndex(where: { $0.id == id }) {
            sessions[index].pendingConnection?.closeConnection()
            sessions.remove(at: index)
            updateCounts()
        }
    }

    public func clearCompletedSessions() {
        sessions.removeAll { $0.status == .completed || $0.status == .error || $0.status == .idle }
        updateCounts()
    }

    public func clearAllSessions() {
        for s in sessions {
            s.pendingConnection?.closeConnection()
        }
        sessions.removeAll()
        updateCounts()
    }

    // MARK: - Private Helpers
    private func getOrCreateSession(id: String, source: String, cwd: String) -> AgentSession {
        if let existing = sessions.first(where: { $0.id == id }) {
            return existing
        }
        let agentType = AgentType.from(source: source)
        let newSession = AgentSession(
            id: id,
            agentType: agentType,
            cwd: cwd,
            status: .running,
            terminalAppName: detectCurrentTerminalApp()
        )
        sessions.insert(newSession, at: 0)
        return newSession
    }

    private func updateCounts() {
        activeSessionCount = sessions.filter { $0.status == .running || $0.status == .waitingForApproval || $0.status == .waitingForAnswer }.count
        pendingApprovalCount = sessions.filter { $0.status == .waitingForApproval || $0.status == .waitingForAnswer }.count
        latestPendingSession = sessions.first(where: { $0.status == .waitingForApproval || $0.status == .waitingForAnswer })
    }

    private func notifyUser(for session: AgentSession) {
        if Defaults[.playAgentNotificationSound] {
            NSSound.beep()
        }

        // If auto-open is enabled and notch is closed, open notch to agents tab
        if Defaults[.autoOpenNotchOnApproval] {
            BoringViewCoordinator.shared.currentView = .agents
            NotificationCenter.default.post(name: Notification.Name("OpenNotchToAgents"), object: nil)
        }
    }

    private func parseQuestions(from input: [String: Any]) -> [AgentQuestion]? {
        guard let rawQuestions = input["questions"] as? [[String: Any]] else {
            return nil
        }

        var result: [AgentQuestion] = []
        for q in rawQuestions {
            let header = (q["header"] as? String) ?? ""
            let questionText = (q["question"] as? String) ?? (q["text"] as? String) ?? ""
            let multiSelect = (q["multiSelect"] as? Bool) ?? (q["multiple"] as? Bool) ?? false

            var options: [AgentQuestionOption] = []
            if let rawOptions = q["options"] as? [[String: Any]] {
                for opt in rawOptions {
                    if let label = opt["label"] as? String {
                        let desc = opt["description"] as? String
                        options.append(AgentQuestionOption(label: label, description: desc))
                    }
                }
            } else if let rawStringOptions = q["options"] as? [String] {
                for label in rawStringOptions {
                    options.append(AgentQuestionOption(label: label))
                }
            }

            result.append(AgentQuestion(
                header: header,
                question: questionText,
                options: options,
                multiSelect: multiSelect
            ))
        }

        return result
    }

    private func formatToolDisplay(toolName: String, input: [String: Any]?) -> String {
        switch toolName {
        case "Bash":
            if let cmd = input?["command"] as? String {
                let firstLine = cmd.components(separatedBy: "\n").first ?? cmd
                return "Bash: \(firstLine.prefix(40))"
            }
            return "Bash"
        case "Edit":
            if let path = input?["file_path"] as? String {
                let name = URL(fileURLWithPath: path).lastPathComponent
                return "Editing \(name)"
            }
            return "Editing file"
        case "Write":
            if let path = input?["file_path"] as? String {
                let name = URL(fileURLWithPath: path).lastPathComponent
                return "Writing \(name)"
            }
            return "Writing file"
        case "Read":
            if let path = input?["file_path"] as? String {
                let name = URL(fileURLWithPath: path).lastPathComponent
                return "Reading \(name)"
            }
            return "Reading file"
        case "AskUserQuestion":
            return "Asking question"
        default:
            return toolName
        }
    }

    private func detectCurrentTerminalApp() -> String? {
        let knownTerminals = [
            "Ghostty",
            "iTerm2",
            "Terminal",
            "Warp",
            "Code",
            "Cursor",
            "Zed",
            "WezTerm",
            "kitty",
            "Alacritty"
        ]

        let ws = NSWorkspace.shared
        // Check frontmost app first
        if let frontmost = ws.frontmostApplication?.localizedName {
            for term in knownTerminals {
                if frontmost.localizedCaseInsensitiveContains(term) {
                    return term
                }
            }
        }

        // Check running apps
        for app in ws.runningApplications {
            guard let name = app.localizedName else { continue }
            for term in knownTerminals {
                if name.localizedCaseInsensitiveContains(term) {
                    return term
                }
            }
        }

        return "Ghostty"
    }

    private func cleanupStaleSessions() {
        let now = Date()
        sessions.removeAll { session in
            (session.status == .completed || session.status == .error) &&
            now.timeIntervalSince(session.updatedAt) > 3600
        }
        updateCounts()
    }
}
