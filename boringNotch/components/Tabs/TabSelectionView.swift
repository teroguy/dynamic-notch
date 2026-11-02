//
//  TabSelectionView.swift
//  boringNotch
//
//  Created in NotchNook Pro style.
//  Floating bottom navigation capsule bar matching [Image #28]-[Image #29].
//

import SwiftUI

struct TabModel: Identifiable, Equatable {
    let id = UUID()
    let label: String
    let icon: String
    let view: NotchViews
}

let tabs = [
    TabModel(label: "Music", icon: "play.fill", view: .home),
    TabModel(label: "Calendar", icon: "calendar", view: .calendar),
    TabModel(label: "Shelf", icon: "tray.fill", view: .shelf),
    TabModel(label: "Agents", icon: "sparkles", view: .agents)
]

struct TabSelectionView: View {
    @EnvironmentObject var vm: BoringViewModel
    @ObservedObject var coordinator = BoringViewCoordinator.shared
    @Namespace var animation

    var body: some View {
        HStack(spacing: 4) {
            ForEach(tabs) { tab in
                let isSelected = coordinator.currentView == tab.view

                Button(action: {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                        coordinator.currentView = tab.view
                    }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 11, weight: .semibold))

                        if isSelected {
                            Text(LocalizedStringKey(tab.label))
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .lineLimit(1)
                                .transition(.opacity.combined(with: .scale(scale: 0.92)))
                        }
                    }
                    .foregroundColor(isSelected ? .white : .gray.opacity(0.85))
                    .padding(.horizontal, isSelected ? 12 : 10)
                    .padding(.vertical, 6)
                    .frame(minWidth: isSelected ? nil : 38, minHeight: 28)
                    .background {
                        ZStack {
                            if isSelected {
                                Capsule()
                                    .fill(Color.white.opacity(0.20))
                                    .matchedGeometryEffect(id: "navActiveCapsule", in: animation)
                            }
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.85))
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.14), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.4), radius: 8, y: 3)
        )
    }
}
