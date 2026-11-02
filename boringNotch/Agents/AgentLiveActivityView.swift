//
//  AgentLiveActivityView.swift
//  boringNotch
//
//  Created for AI Agent Integration.
//  Renders closed-notch live activity and chin notification banner.
//

import Defaults
import SwiftUI

// MARK: - Closed Notch Agent Live Activity (left & right wings of notch)
public struct AgentLiveActivityView: View {
    @ObservedObject var agentManager = AgentManager.shared
    @EnvironmentObject var vm: BoringViewModel

    @State private var pulseAnimation = false

    public init() {}

    public var body: some View {
        if let session = agentManager.primaryActiveSession {
            HStack(spacing: 0) {
                // Left Wing: Agent Icon with pulsing indicator
                HStack(spacing: 4) {
                    Image(systemName: session.agentType.systemIcon)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(session.agentType.brandColor)

                    Circle()
                        .fill(session.status.statusColor)
                        .frame(width: 5, height: 5)
                        .scaleEffect(pulseAnimation ? 1.3 : 0.8)
                        .opacity(pulseAnimation ? 1.0 : 0.6)
                        .animation(
                            Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                            value: pulseAnimation
                        )
                }
                .frame(width: max(0, vm.effectiveClosedNotchHeight - 8), alignment: .center)
                .onAppear {
                    pulseAnimation = true
                }

                // Center: Notch hardware cutout filler
                Rectangle()
                    .fill(.black)
                    .frame(width: vm.closedNotchSize.width - 20)

                // Right Wing: Status icon / indicator
                HStack(spacing: 3) {
                    if session.status == .waitingForApproval {
                        Image(systemName: "exclamationmark.shield.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.orange)
                    } else if session.status == .waitingForAnswer {
                        Image(systemName: "questionmark.bubble.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.purple)
                    } else if session.status == .running {
                        HStack(spacing: 2) {
                            ForEach(0..<3) { _ in
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 3, height: 3)
                            }
                        }
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                }
                .frame(width: max(0, vm.effectiveClosedNotchHeight - 8), alignment: .center)
            }
            .frame(height: vm.effectiveClosedNotchHeight, alignment: .center)
        }
    }
}

// MARK: - Expanding Chin Notification View
public struct AgentChinNotificationView: View {
    @ObservedObject var agentManager = AgentManager.shared
    @EnvironmentObject var vm: BoringViewModel

    public init() {}

    public var body: some View {
        if let session = agentManager.latestPendingSession,
           let req = session.pendingPermission {
            HStack(spacing: 8) {
                // Icon
                Image(systemName: req.toolName == "AskUserQuestion" ? "questionmark.circle.fill" : "exclamationmark.shield.fill")
                    .foregroundColor(req.toolName == "AskUserQuestion" ? .purple : .orange)
                    .font(.system(size: 13, weight: .bold))

                // Text
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(session.agentType.displayName) — \(session.projectName)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white)

                    Text(req.toolName == "AskUserQuestion"
                         ? (req.questions?.first?.question ?? "Has an interactive question")
                         : (req.command ?? req.description ?? "Needs permission for \(req.toolName)"))
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }

                Spacer()

                // Quick Allow / Deny buttons if tool approval
                if req.toolName != "AskUserQuestion" {
                    Button(action: {
                        agentManager.approve(session: session)
                    }) {
                        Text("Allow")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.green))
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: {
                        agentManager.deny(session: session)
                    }) {
                        Text("Deny")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.red.opacity(0.8)))
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    Text("Click to answer")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.purple)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.purple.opacity(0.2)))
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.85)))
            .padding(.bottom, 6)
        }
    }
}
