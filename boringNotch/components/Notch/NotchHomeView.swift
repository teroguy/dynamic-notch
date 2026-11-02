//
//  NotchHomeView.swift
//  boringNotch
//
//  Created in NotchNook Pro style.
//  Compact, highly functional media player with Audio Output Device switcher and App Volume Mixer.
//

import AppKit
import Combine
import Defaults
import SwiftUI

enum PlayerDrawerTab: String, CaseIterable, Identifiable {
    case output = "Output"
    case apps = "Apps"
    var id: String { rawValue }
}

// MARK: - NotchNook Pro Media Player
struct NotchNookPlayerView: View {
    @ObservedObject var musicManager = MusicManager.shared
    @EnvironmentObject var vm: BoringViewModel
    let albumArtNamespace: Namespace.ID

    @State private var selectedDrawerTab: PlayerDrawerTab = .output
    @State private var sliderValue: Double = 0
    @State private var dragging: Bool = false
    @State private var lastDragged: Date = .distantPast

    var body: some View {
        VStack(spacing: 10) {
            // Top Section: Artwork + Track Info + Menu
            HStack(spacing: 12) {
                // Album Artwork with Native Source App Icon Badge
                ZStack(alignment: .bottomTrailing) {
                    Image(nsImage: musicManager.albumArt)
                        .resizable()
                        .aspectRatio(1, contentMode: .fit)
                        .matchedGeometryEffect(id: "albumArt", in: albumArtNamespace)
                        .frame(width: 52, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(color: Color.black.opacity(0.3), radius: 4, y: 2)

                    if let bundleID = musicManager.bundleIdentifier, !bundleID.isEmpty {
                        AppIcon(for: bundleID)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 18, height: 18)
                            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .stroke(Color.black.opacity(0.4), lineWidth: 0.8)
                            )
                            .shadow(color: Color.black.opacity(0.35), radius: 2, y: 1)
                            .offset(x: 4, y: 4)
                    }
                }

                // Track Title & Artist with Source App Indicator
                VStack(alignment: .leading, spacing: 3) {
                    Text(musicManager.songTitle.isEmpty ? String(localized: "Not Playing") : musicManager.songTitle)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    HStack(spacing: 5) {
                        Text(musicManager.artistName.isEmpty ? String(localized: "Choose a track to play") : musicManager.artistName)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.gray)
                            .lineLimit(1)

                        if let bundleID = musicManager.bundleIdentifier, !bundleID.isEmpty {
                            Text("•")
                                .font(.system(size: 10))
                                .foregroundColor(.gray.opacity(0.5))

                            HStack(spacing: 3) {
                                AppIcon(for: bundleID)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 11, height: 11)
                                    .clipShape(RoundedRectangle(cornerRadius: 2.5, style: .continuous))

                                Text(appDisplayName(for: bundleID))
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                                    .foregroundColor(.gray.opacity(0.85))
                                    .lineLimit(1)
                            }
                        }
                    }
                }

                Spacer(minLength: 0)

                // Menu Button (•••) without arrow indicator
                Menu {
                    Button(String(localized: "Open Music App")) {
                        musicManager.openMusicApp()
                    }
                    Button(String(localized: "Copy Track Title")) {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(musicManager.songTitle, forType: .string)
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 28, height: 28)
                        Image(systemName: "ellipsis")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white.opacity(0.85))
                    }
                    .contentShape(Circle())
                }
                .menuIndicator(.hidden)
                .menuStyle(BorderlessButtonMenuStyle())
            }
            .padding(.horizontal, 4)

            // Timeline Progress Slider with Real-time Animation Clock
            TimelineView(.animation(minimumInterval: musicManager.isPlaying ? 0.1 : 1.0)) { timeline in
                MusicSliderView(
                    sliderValue: $sliderValue,
                    duration: $musicManager.songDuration,
                    lastDragged: $lastDragged,
                    color: musicManager.avgColor,
                    dragging: $dragging,
                    currentDate: timeline.date,
                    timestampDate: musicManager.timestampDate,
                    elapsedTime: musicManager.elapsedTime,
                    playbackRate: musicManager.playbackRate,
                    isPlaying: musicManager.isPlaying,
                    onValueChange: { newValue in
                        MusicManager.shared.seek(to: newValue)
                    }
                )
            }
            .padding(.horizontal, 4)
            .onAppear {
                sliderValue = MusicManager.shared.estimatedPlaybackPosition()
            }

            // Controls Row (Queue, Shuffle, Backward, Play/Pause, Forward, Output Device Drawer Button)
            HStack(spacing: 0) {
                // Secondary Controls: Queue & Shuffle
                HStack(spacing: 10) {
                    Button(action: {
                        musicManager.openMusicApp()
                    }) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.gray)
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: {
                        musicManager.toggleShuffle()
                    }) {
                        Image(systemName: "shuffle")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(musicManager.isShuffled ? .effectiveAccent : .gray)
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                Spacer(minLength: 12)

                // Primary Playback Controls: Previous, Play/Pause, Next
                HStack(spacing: 14) {
                    Button(action: {
                        musicManager.previousTrack()
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.08))
                                .frame(width: 32, height: 32)
                            Image(systemName: "backward.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .contentShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: {
                        musicManager.togglePlay()
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.14))
                                .frame(width: 42, height: 42)
                            Image(systemName: musicManager.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .contentShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: {
                        musicManager.nextTrack()
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.08))
                                .frame(width: 32, height: 32)
                            Image(systemName: "forward.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .contentShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                Spacer(minLength: 12)

                // Audio Output / Device Switcher Button (Laptop icon)
                Button(action: {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                        vm.isPlayerDrawerOpen.toggle()
                        if vm.isPlayerDrawerOpen {
                            AudioOutputDeviceManager.shared.refreshDevices()
                            AppVolumeMixerManager.shared.refreshApps()
                        }
                    }
                }) {
                    ZStack {
                        if vm.isPlayerDrawerOpen {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.white.opacity(0.18))
                                .frame(width: 30, height: 30)
                        }
                        Image(systemName: "laptopcomputer")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(vm.isPlayerDrawerOpen ? .white : .gray)
                            .frame(width: 30, height: 30)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .help("Audio output & app volume mixer")
            }
            .padding(.horizontal, 6)

            // Expandable Drawer ([Image #16] Output Devices & [Image #17] App Volume Mixer)
            if vm.isPlayerDrawerOpen {
                VStack(spacing: 8) {
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 1)
                        .padding(.vertical, 2)

                    // Segmented Picker Header [ Output | Apps ]
                    HStack {
                        HStack(spacing: 2) {
                            Button(action: {
                                withAnimation(.smooth(duration: 0.2)) {
                                    selectedDrawerTab = .output
                                    AudioOutputDeviceManager.shared.refreshDevices()
                                }
                            }) {
                                Text(String(localized: "Output"))
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(selectedDrawerTab == .output ? .white : .gray)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 3)
                                    .background(
                                        Capsule().fill(selectedDrawerTab == .output ? Color.white.opacity(0.2) : Color.clear)
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())

                            Button(action: {
                                withAnimation(.smooth(duration: 0.2)) {
                                    selectedDrawerTab = .apps
                                    AppVolumeMixerManager.shared.refreshApps()
                                }
                            }) {
                                Text(String(localized: "Apps"))
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(selectedDrawerTab == .apps ? .white : .gray)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 3)
                                    .background(
                                        Capsule().fill(selectedDrawerTab == .apps ? Color.white.opacity(0.2) : Color.clear)
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(2)
                        .background(Capsule().fill(Color.white.opacity(0.08)))

                        Spacer()

                        if selectedDrawerTab == .apps {
                            Button(action: {
                                AppVolumeMixerManager.shared.resetAll()
                            }) {
                                Text(String(localized: "Reset"))
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.gray)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 4)

                    // Drawer Content
                    if selectedDrawerTab == .output {
                        outputDevicesListView
                    } else {
                        appsVolumeListView
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(width: 390)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }


    // [Image #16] Output Devices List
    private var outputDevicesListView: some View {
        let devices = AudioOutputDeviceManager.shared.devices
        return Group {
            if devices.count <= 3 {
                VStack(spacing: 5) {
                    ForEach(devices) { device in
                        outputDeviceButton(device)
                    }
                }
                .padding(.horizontal, 2)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 5) {
                        ForEach(devices) { device in
                            outputDeviceButton(device)
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.bottom, 2)
                }
                .frame(maxHeight: 145)
            }
        }
    }

    private func outputDeviceButton(_ device: AudioOutputDevice) -> some View {
        Button(action: {
            AudioOutputDeviceManager.shared.setOutputDevice(device)
        }) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(device.iconBgColor)
                        .frame(width: 26, height: 26)
                    Image(systemName: device.iconName)
                        .font(.system(size: 12))
                        .foregroundColor(device.iconColor)
                }

                Text(device.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Spacer()

                if device.isDefault {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(device.isDefault ? Color.white.opacity(0.12) : Color.white.opacity(0.04))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    // [Image #17] Apps Volume Mixer List
    private var appsVolumeListView: some View {
        let apps = AppVolumeMixerManager.shared.apps
        return Group {
            if apps.isEmpty {
                VStack(spacing: 4) {
                    Text(String(localized: "No audio apps detected"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 38)
            } else if apps.count <= 3 {
                VStack(spacing: 6) {
                    ForEach(apps) { appItem in
                        VolumePillRow(item: appItem)
                    }
                }
                .padding(.horizontal, 2)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 6) {
                        ForEach(apps) { appItem in
                            VolumePillRow(item: appItem)
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.bottom, 2)
                }
                .frame(maxHeight: 145)
            }
        }
    }
}

// MARK: - [Image #17] VolumePill Capsule Slider
struct VolumePillRow: View {
    @ObservedObject var item: AppVolumeItem

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let fillWidth = max(0, min(width, width * item.volume))

            ZStack(alignment: .leading) {
                // Background Capsule
                Capsule()
                    .fill(Color.white.opacity(0.08))

                // Progress Fill
                Capsule()
                    .fill(Color.white.opacity(0.20))
                    .frame(width: fillWidth)

                // Content
                HStack(spacing: 8) {
                    Image(nsImage: item.icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 18, height: 18)
                        .clipShape(Circle())

                    Text(item.name)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Spacer()

                    Text("\(Int(item.volume * 100))%")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                }
                .padding(.horizontal, 10)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let fraction = max(0.0, min(1.0, value.location.x / width))
                        AppVolumeMixerManager.shared.setVolume(for: item, to: fraction)
                    }
            )
        }
        .frame(height: 32)
    }
}

// MARK: - Root Home View
struct NotchHomeView: View {
    @EnvironmentObject var vm: BoringViewModel
    @ObservedObject var webcamManager = WebcamManager.shared
    @ObservedObject var coordinator = BoringViewCoordinator.shared
    let albumArtNamespace: Namespace.ID

    var body: some View {
        Group {
            if !coordinator.firstLaunch {
                mainContent
            }
        }
        .transition(.opacity)
    }

    private var shouldShowCamera: Bool {
        Defaults[.showMirror] && webcamManager.cameraAvailable && vm.isCameraExpanded
    }

    private var mainContent: some View {
        HStack(alignment: .top, spacing: shouldShowCamera ? 12 : 0) {
            NotchNookPlayerView(albumArtNamespace: albumArtNamespace)

            if shouldShowCamera {
                CameraPreviewView(webcamManager: webcamManager)
                    .scaledToFit()
                    .opacity(vm.notchState == .closed ? 0 : 1)
                    .blur(radius: vm.notchState == .closed ? 20 : 0)
                    .animation(.interactiveSpring(response: 0.32, dampingFraction: 0.76, blendDuration: 0), value: shouldShowCamera)
            }
        }
        .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .top)), removal: .opacity))
        .blur(radius: vm.notchState == .closed ? 30 : 0)
    }
}

// MARK: - Music Slider View
struct MusicSliderView: View {
    @Binding var sliderValue: Double
    @Binding var duration: Double
    @Binding var lastDragged: Date
    var color: NSColor
    @Binding var dragging: Bool
    let currentDate: Date
    let timestampDate: Date
    let elapsedTime: Double
    let playbackRate: Double
    let isPlaying: Bool
    var onValueChange: (Double) -> Void

    var body: some View {
        VStack(spacing: 2) {
            CustomSlider(
                value: $sliderValue,
                range: 0...max(duration, 1),
                color: Defaults[.sliderColor] == SliderColorEnum.albumArt
                    ? Color(nsColor: color).ensureMinimumBrightness(factor: 0.8)
                    : Defaults[.sliderColor] == SliderColorEnum.accent ? .effectiveAccent : .white,
                dragging: $dragging,
                lastDragged: $lastDragged,
                onValueChange: onValueChange
            )
            .frame(height: 6, alignment: .center)

            HStack {
                Text(timeString(from: sliderValue))
                Spacer()
                Text(timeString(from: duration))
            }
            .fontWeight(.medium)
            .foregroundColor(Color.gray.opacity(0.8))
            .font(.system(size: 9, design: .monospaced))
        }
        .onAppear {
            sliderValue = MusicManager.shared.estimatedPlaybackPosition(at: currentDate)
        }
        .onChange(of: currentDate) {
            guard !dragging, timestampDate.timeIntervalSince(lastDragged) > -1 else { return }
            sliderValue = MusicManager.shared.estimatedPlaybackPosition(at: currentDate)
        }
        .onChange(of: elapsedTime) {
            guard !dragging else { return }
            sliderValue = MusicManager.shared.estimatedPlaybackPosition(at: currentDate)
        }
    }

    func timeString(from seconds: Double) -> String {
        let totalMinutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
        } else {
            return String(format: "%02d:%02d", minutes, remainingSeconds)
        }
    }
}

struct CustomSlider: View {
    @Binding var value: Double
    var range: ClosedRange<Double>
    var color: Color = .white
    @Binding var dragging: Bool
    @Binding var lastDragged: Date
    var onValueChange: ((Double) -> Void)?
    var onDragChange: ((Double) -> Void)?

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = CGFloat(dragging ? 9 : 5)
            let rangeSpan = range.upperBound - range.lowerBound

            let progress = rangeSpan == .zero ? 0 : (value - range.lowerBound) / rangeSpan
            let filledTrackWidth = min(max(progress, 0), 1) * width

            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(.gray.opacity(0.3))
                    .frame(height: height)

                Rectangle()
                    .fill(color)
                    .frame(width: filledTrackWidth, height: height)
            }
            .cornerRadius(height / 2)
            .frame(height: 10)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        withAnimation {
                            dragging = true
                        }
                        let newValue = range.lowerBound + Double(gesture.location.x / width) * rangeSpan
                        value = min(max(newValue, range.lowerBound), range.upperBound)
                        onDragChange?(value)
                    }
                    .onEnded { _ in
                        onValueChange?(value)
                        dragging = false
                        lastDragged = Date()
                    }
            )
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: dragging)
        }
    }
}
