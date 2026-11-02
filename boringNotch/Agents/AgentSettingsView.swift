//
//  AgentSettingsView.swift
//  boringNotch
//
//  Created for AI Agent Integration.
//  Settings panel for configuring AI coding agents (Claude Code, Codex, etc.).
//

import Defaults
import SwiftUI

public struct AgentSettingsView: View {
    @ObservedObject var agentManager = AgentManager.shared
    @State private var hookInstaller = AgentHookInstaller.shared
    @State private var hooksInstalled: Bool = false
    @State private var statusMessage: String?

    @Default(.enableAgentIntegration) var enableAgentIntegration
    @Default(.agentLiveActivityEnabled) var agentLiveActivityEnabled
    @Default(.autoOpenNotchOnApproval) var autoOpenNotchOnApproval
    @Default(.playAgentNotificationSound) var playAgentNotificationSound

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.orange.opacity(0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: "sparkles")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.orange)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("ИИ-ассистенты для кода")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("Управление в челке для Claude Code, Codex и консольных агентов")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.bottom, 4)

                Divider()

                // Master Toggle
                Toggle("Включить интеграцию с агентами", isOn: $enableAgentIntegration)
                    .font(.system(size: 13, weight: .medium))

                // Claude Code Connection Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Интеграция с Claude Code")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                            Text("Подключается через хуки ~/.claude/settings.json")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                        }

                        Spacer()

                        if hooksInstalled {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Подключено")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.green)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.green.opacity(0.15)))
                        } else {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(.orange)
                                Text("Не подключено")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.orange)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.orange.opacity(0.15)))
                        }
                    }

                    HStack(spacing: 10) {
                        Button(action: {
                            if hookInstaller.installHooks() {
                                withAnimation {
                                    hooksInstalled = true
                                    statusMessage = "Хуки Claude Code успешно установлены!"
                                }
                            } else {
                                statusMessage = "Не удалось установить хуки."
                            }
                        }) {
                            Text(hooksInstalled ? "Переустановить хуки" : "Установить хуки Claude Code")
                                .font(.system(size: 12, weight: .medium))
                        }

                        if hooksInstalled {
                            Button(role: .destructive, action: {
                                if hookInstaller.uninstallHooks() {
                                    withAnimation {
                                        hooksInstalled = false
                                        statusMessage = "Хуки удалены."
                                    }
                                }
                            }) {
                                Text("Удалить")
                                    .font(.system(size: 12))
                                    .foregroundColor(.red)
                            }
                        }

                        Spacer()

                        Button(action: {
                            sendTestEvent()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "play.fill")
                                Text("Тестовый вопрос")
                            }
                            .font(.system(size: 11))
                        }
                    }

                    if let msg = statusMessage {
                        Text(msg)
                            .font(.system(size: 11))
                            .foregroundColor(.orange)
                    }
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.04)))

                // Behavior Settings
                VStack(alignment: .leading, spacing: 14) {
                    Text("Поведение")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)

                    Toggle("Показывать активность агента в закрытой челке (Live Activity)", isOn: $agentLiveActivityEnabled)
                    Toggle("Автоматически открывать челку при запросе подтверждения", isOn: $autoOpenNotchOnApproval)
                    Toggle("Звуковой сигнал при запросе подтверждения", isOn: $playAgentNotificationSound)
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.04)))

                // Supported Agents
                VStack(alignment: .leading, spacing: 10) {
                    Text("Поддерживаемые CLI-агенты")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        agentBadge(name: "Claude Code", icon: "sparkles", color: .orange)
                        agentBadge(name: "OpenAI Codex", icon: "cpu", color: .green)
                        agentBadge(name: "Gemini CLI", icon: "diamond.fill", color: .blue)
                        agentBadge(name: "Cursor Agent", icon: "cursorarrow.rays", color: .purple)
                        agentBadge(name: "OpenCode", icon: "chevron.left.forwardslash.chevron.right", color: .yellow)
                        agentBadge(name: "Hermes", icon: "paperplane.fill", color: .pink)
                    }
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.04)))
            }
            .padding(20)
        }
        .onAppear {
            hooksInstalled = hookInstaller.areHooksInstalled
        }
    }

    private func agentBadge(name: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 12))
            Text(name)
                .font(.system(size: 12))
                .foregroundColor(.white)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.03)))
    }

    private func sendTestEvent() {
        let dummySessionId = "test-session-\(UUID().uuidString.prefix(6))"
        let questions: [String: Any] = [
            "questions": [
                [
                    "header": "Deployment",
                    "question": "Where would you like to deploy this release?",
                    "options": [
                        ["label": "Production (Recommended)", "description": "Deploy to main cluster"],
                        ["label": "Staging", "description": "Deploy to staging environment for testing"],
                        ["label": "Local Docker", "description": "Run locally in containers"]
                    ],
                    "multiSelect": false
                ]
            ]
        ]

        let dummyConn = AgentPendingConnection(fileDescriptor: -1, sessionId: dummySessionId)
        agentManager.handlePermissionRequest(
            sessionId: dummySessionId,
            source: "claude",
            cwd: FileManager.default.currentDirectoryPath,
            toolName: "AskUserQuestion",
            toolInput: questions,
            pendingConnection: dummyConn
        )
    }
}
