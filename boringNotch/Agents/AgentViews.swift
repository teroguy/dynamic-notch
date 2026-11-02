//
//  AgentViews.swift
//  boringNotch
//
//  Created for AI Agent Integration.
//  SwiftUI UI components for displaying active AI agent sessions,
//  interactive question answering (AskUserQuestion), and tool permissions.
//

import AppKit
import Defaults
import SwiftUI

// MARK: - Main Agents Tab View
public struct AgentNotchView: View {
    @ObservedObject var agentManager = AgentManager.shared
    @State private var hookInstaller = AgentHookInstaller.shared
    @State private var hooksInstalled: Bool = false

    public init() {}

    public var body: some View {
        VStack(spacing: 8) {
            if agentManager.sessions.isEmpty {
                emptyStateView
            } else {
                headerBar
                if agentManager.sessions.count <= 2 {
                    VStack(spacing: 8) {
                        ForEach(agentManager.sessions) { session in
                            AgentSessionCardView(session: session)
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.bottom, 4)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 8) {
                            ForEach(agentManager.sessions) { session in
                                AgentSessionCardView(session: session)
                            }
                        }
                        .padding(.horizontal, 2)
                        .padding(.bottom, 6)
                    }
                    .frame(maxHeight: 220)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 14)
        .padding(.bottom, 6)
        .onAppear {
            hooksInstalled = hookInstaller.areHooksInstalled
        }
    }

    private var headerBar: some View {
        HStack {
            if agentManager.activeSessionCount > 0 {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    Text("\(agentManager.activeSessionCount) активных")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.green.opacity(0.15)))
            } else {
                Text("\(agentManager.sessions.count) сессий")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.gray)
            }

            Spacer()

            HStack(spacing: 8) {
                Button(action: {
                    withAnimation(.smooth) {
                        agentManager.clearCompletedSessions()
                    }
                }) {
                    Text("Очистить завершенные")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.gray)
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: {
                    withAnimation(.smooth) {
                        agentManager.clearAllSessions()
                    }
                }) {
                    Text("Очистить все")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.red.opacity(0.8))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 2)
        .padding(.top, 2)
    }

    private var emptyStateView: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.orange)
            }
            .padding(.top, 2)

            Text("Нет активных сессий")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)

            Text("Запустите Claude Code или Codex в терминале.\nЗдесь появятся сессии, вопросы и подтверждения.")
                .font(.system(size: 10))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            if hooksInstalled {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 5, height: 5)
                    Text("Хуки Claude Code подключены")
                        .foregroundColor(.gray)
                }
                .font(.system(size: 10))
                .padding(.top, 2)
            } else {
                Button(action: {
                    if hookInstaller.installHooks() {
                        withAnimation {
                            hooksInstalled = true
                        }
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                        Text("Подключить хуки Claude Code")
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.orange))
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

// MARK: - Session Card View
public struct AgentSessionCardView: View {
    @ObservedObject var session: AgentSession
    @ObservedObject var agentManager = AgentManager.shared

    public init(session: AgentSession) {
        self.session = session
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header Row: Agent logo, Project name, Directory, Status, Terminal button, Dismiss
            HStack(spacing: 8) {
                // Agent Icon
                ZStack {
                    Circle()
                        .fill(session.agentType.brandColor.opacity(0.2))
                        .frame(width: 28, height: 28)
                    Image(systemName: session.agentType.systemIcon)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(session.agentType.brandColor)
                }

                // Project, Branch & Path
                VStack(alignment: .leading, spacing: 3) {
                    Text(session.projectName)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    if let branch = session.gitBranch, !branch.isEmpty {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.triangle.branch")
                                .font(.system(size: 8, weight: .semibold))
                            Text(branch)
                                .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(Color.white.opacity(0.10)))
                    }

                    Text(shortPath(session.cwd))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.gray.opacity(0.75))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                // Right Actions: identical width pills, dismiss button vertically centered
                HStack(alignment: .center, spacing: 6) {
                    VStack(spacing: 4) {
                        // Status Badge
                        HStack(spacing: 4) {
                            Circle()
                                .fill(session.status.statusColor)
                                .frame(width: 6, height: 6)
                            Text(session.status.displayLabel)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(session.status.statusColor)
                                .lineLimit(1)
                        }
                        .frame(width: 96, height: 22)
                        .background(Capsule().fill(session.status.statusColor.opacity(0.15)))

                        // "В терминал" Button
                        Button(action: {
                            agentManager.focusTerminal(for: session)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "terminal.fill")
                                    .font(.system(size: 9))
                                Text("В терминал")
                                    .font(.system(size: 10, weight: .semibold))
                                    .lineLimit(1)
                            }
                            .foregroundColor(.white.opacity(0.9))
                            .frame(width: 96, height: 22)
                            .background(Capsule().fill(Color.white.opacity(0.12)))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("Переключиться в терминал этой сессии")
                    }

                    // Dismiss Session Button - centered vertically
                    Button(action: {
                        withAnimation {
                            agentManager.removeSession(id: session.id)
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.gray)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(Color.white.opacity(0.06)))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Закрыть сессию")
                }
            }

            // User Prompt if present
            if let prompt = session.lastPrompt, !prompt.isEmpty {
                HStack(alignment: .top, spacing: 4) {
                    Image(systemName: "bubble.left.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                        .padding(.top, 2)
                    Text(prompt)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(2)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.04)))
            }

            // Current Tool Indicator if running
            if session.status == .running, let tool = session.currentTool {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 12, height: 12)
                    Text(tool)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.orange)
                        .lineLimit(1)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 4).fill(Color.orange.opacity(0.1)))
            }

            // Pending Approval or Question Content
            if let req = session.pendingPermission {
                if req.toolName == "AskUserQuestion" || session.status == .waitingForAnswer {
                    AgentQuestionCardView(session: session, request: req)
                } else {
                    AgentApprovalCardView(session: session, request: req)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.35))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            session.status == .waitingForApproval ? Color.orange.opacity(0.5) :
                            session.status == .waitingForAnswer ? Color.purple.opacity(0.6) :
                            Color.white.opacity(0.08),
                            lineWidth: 1
                        )
                )
        )
    }

    private func shortPath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }
}

// MARK: - Approval Card View (Allow / Deny commands & edits)
public struct AgentApprovalCardView: View {
    @ObservedObject var session: AgentSession
    let request: AgentPermissionRequest
    @ObservedObject var agentManager = AgentManager.shared

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: iconForTool(request.toolName))
                    .foregroundColor(.orange)
                    .font(.system(size: 11, weight: .bold))
                Text("Запрос разрешения: \(request.toolName)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)

                if let desc = request.description, !desc.isEmpty {
                    Text("— \(desc)")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                Spacer()
            }

            // Command / File Path Box
            if let command = request.command, !command.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(command)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.white.opacity(0.9))
                        .padding(6)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.6)))
            } else if let filePath = request.filePath, !filePath.isEmpty {
                Text(filePath)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.6)))
            }

            // Decision Buttons
            HStack(spacing: 10) {
                Button(action: {
                    agentManager.approve(session: session)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                        Text("Разрешить")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.green.opacity(0.85)))
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: {
                    agentManager.deny(session: session)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark")
                        Text("Отклонить")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.red.opacity(0.75)))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.top, 2)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.08)))
    }

    private func iconForTool(_ name: String) -> String {
        switch name {
        case "Bash": return "terminal"
        case "Edit": return "pencil"
        case "Write": return "doc.badge.plus"
        case "Read": return "doc.text"
        default: return "wrench.and.screwdriver"
        }
    }
}

// MARK: - Question Card View (Interactive AskUserQuestion)
public struct AgentQuestionCardView: View {
    @ObservedObject var session: AgentSession
    let request: AgentPermissionRequest
    @ObservedObject var agentManager = AgentManager.shared

    @State private var customAnswer: String = ""
    @State private var showCustomField: Bool = false
    @State private var answeredOption: String?
    @FocusState private var isFieldFocused: Bool

    private func submitCustom() {
        guard !customAnswer.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        SharingStateManager.shared.preventNotchClose = false
        showCustomField = false
        isFieldFocused = false
        var answersMap: [String: String] = [:]
        if let firstQ = request.questions?.first {
            answersMap[firstQ.question] = customAnswer
            if !firstQ.header.isEmpty {
                answersMap[firstQ.header] = customAnswer
            }
        } else {
            answersMap["answer"] = customAnswer
        }
        agentManager.answerQuestion(session: session, answers: answersMap)
        NotificationCenter.default.post(name: .sharingDidFinish, object: nil)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Explanation label
            HStack(spacing: 5) {
                Image(systemName: "questionmark.circle.fill")
                    .foregroundColor(.purple)
                    .font(.system(size: 11, weight: .bold))
                Text("Claude Code Question — click an option to reply directly:")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.purple.opacity(0.9))
                Spacer()
            }

            if let questions = request.questions, !questions.isEmpty {
                ForEach(questions) { q in
                    singleQuestionView(q)
                }
            } else {
                Text(request.description ?? "Agent is asking for your input:")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
            }

            // Custom Answer Input Toggle
            if showCustomField {
                HStack(spacing: 6) {
                    TextField("Type custom answer...", text: $customAnswer)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.system(size: 11))
                        .padding(6)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.6)))
                        .foregroundColor(.white)
                        .focused($isFieldFocused)
                        .onSubmit {
                            submitCustom()
                        }
                        .onTapGesture {
                            NSApp.activate(ignoringOtherApps: true)
                            isFieldFocused = true
                        }

                    Button(action: {
                        submitCustom()
                    }) {
                        Text("Отправить")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.purple))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .onAppear {
                    NSApp.activate(ignoringOtherApps: true)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isFieldFocused = true
                    }
                }
            } else {
                Button(action: {
                    showCustomField = true
                }) {
                    Text("+ Ввести свой ответ")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.top, 2)
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.purple.opacity(0.12)))
        .onChange(of: isFieldFocused) { _, focused in
            SharingStateManager.shared.preventNotchClose = focused
        }
        .onDisappear {
            SharingStateManager.shared.preventNotchClose = false
        }
    }

    @ViewBuilder
    private func singleQuestionView(_ q: AgentQuestion) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if !q.header.isEmpty {
                    Text(q.header.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.purple.opacity(0.3)))
                        .foregroundColor(.purple)
                }
                Text(q.question)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Option buttons
            VStack(spacing: 5) {
                ForEach(q.options) { option in
                    Button(action: {
                        withAnimation {
                            answeredOption = option.label
                        }
                        SharingStateManager.shared.preventNotchClose = false
                        var answersMap: [String: String] = [:]
                        answersMap[q.question] = option.label
                        if !q.header.isEmpty {
                            answersMap[q.header] = option.label
                        }
                        agentManager.answerQuestion(session: session, answers: answersMap)
                        NotificationCenter.default.post(name: .sharingDidFinish, object: nil)
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(option.label)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.white)
                                if let desc = option.description, !desc.isEmpty {
                                    Text(desc)
                                        .font(.system(size: 9))
                                        .foregroundColor(.gray)
                                        .lineLimit(1)
                                }
                            }
                            Spacer()
                            if answeredOption == option.label {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            } else {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 9))
                                    .foregroundColor(.gray.opacity(0.5))
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(answeredOption == option.label ? Color.purple.opacity(0.3) : Color.white.opacity(0.06))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
}
