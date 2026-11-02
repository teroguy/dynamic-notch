//
//  AppVolumeMixerManager.swift
//  boringNotch
//
//  Created in NotchNook Pro style.
//  Manages per-application volume sliders (VolumePills) for applications that output audio.
//

import AppKit
import CoreAudio
import Darwin
import Foundation
import SwiftUI

public class AppVolumeItem: Identifiable, ObservableObject, Equatable {
    public static func == (lhs: AppVolumeItem, rhs: AppVolumeItem) -> Bool {
        lhs.id == rhs.id && lhs.volume == rhs.volume
    }

    public let id: String
    public let name: String
    public let icon: NSImage
    @Published public var volume: Double

    public init(id: String, name: String, icon: NSImage, volume: Double = 0.8) {
        self.id = id
        self.name = name
        self.icon = icon
        self.volume = volume
    }
}

@MainActor
public final class AppVolumeMixerManager: ObservableObject {
    public static let shared = AppVolumeMixerManager()

    @Published public private(set) var apps: [AppVolumeItem] = []
    private var volumeStore: [String: Double] = [:]

    private init() {
        refreshApps()
    }

    public func refreshApps() {
        var appSet = Set<NSRunningApplication>()

        // 1. CoreAudio active audio clients
        var processAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyProcessObjectList,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var processListSize: UInt32 = 0
        let sizeStatus = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &processAddress,
            0,
            nil,
            &processListSize
        )

        if sizeStatus == noErr && processListSize > 0 {
            let count = Int(processListSize) / MemoryLayout<AudioObjectID>.size
            var processIDs = [AudioObjectID](repeating: 0, count: count)
            let dataStatus = AudioObjectGetPropertyData(
                AudioObjectID(kAudioObjectSystemObject),
                &processAddress,
                0,
                nil,
                &processListSize,
                &processIDs
            )

            if dataStatus == noErr {
                for objID in processIDs {
                    var realPID: pid_t = 0
                    var pidSize = UInt32(MemoryLayout<pid_t>.size)
                    var pidAddress = AudioObjectPropertyAddress(
                        mSelector: kAudioProcessPropertyPID,
                        mScope: kAudioObjectPropertyScopeGlobal,
                        mElement: kAudioObjectPropertyElementMain
                    )
                    AudioObjectGetPropertyData(objID, &pidAddress, 0, nil, &pidSize, &realPID)
                    guard realPID > 0 else { continue }

                    // Check if process itself is a regular GUI application
                    var targetPID = realPID
                    if let app = NSRunningApplication(processIdentifier: targetPID),
                       app.activationPolicy == .regular {
                        appSet.insert(app)
                        continue
                    }

                    // Otherwise trace up parent PIDs to find the parent GUI app (e.g. for Chromium / Electron audio helpers)
                    for _ in 0..<3 {
                        var info = proc_bsdinfo()
                        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
                        let ret = proc_pidinfo(targetPID, PROC_PIDTBSDINFO, 0, &info, size)
                        if ret == size && info.pbi_ppid > 1 {
                            targetPID = pid_t(info.pbi_ppid)
                            if let parentApp = NSRunningApplication(processIdentifier: targetPID),
                               parentApp.activationPolicy == .regular {
                                appSet.insert(parentApp)
                                break
                            }
                        } else {
                            break
                        }
                    }
                }
            }
        }

        // 2. Add currently playing media app from MusicManager if running
        if let currentMediaBundle = MusicManager.shared.bundleIdentifier, !currentMediaBundle.isEmpty {
            if let mediaApp = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == currentMediaBundle }) {
                appSet.insert(mediaApp)
            }
        }

        // 3. Filter out Boring Notch itself and internal helpers
        let myBundleID = Bundle.main.bundleIdentifier ?? ""
        var result: [AppVolumeItem] = []
        var seenIDs = Set<String>()

        for running in appSet {
            guard let bid = running.bundleIdentifier,
                  bid != myBundleID,
                  !seenIDs.contains(bid) else { continue }

            let lowerBid = bid.lowercased()
            let lowerName = (running.localizedName ?? "").lowercased()
            if lowerBid.contains("helper") || lowerBid.contains("xpc") || lowerName.contains("helper") || lowerName.contains("заполнить автоматически") {
                continue
            }

            seenIDs.insert(bid)
            let name = running.localizedName ?? appDisplayName(for: bid)
            let icon = running.icon ?? NSWorkspace.shared.icon(forFile: running.bundleURL?.path ?? "")

            var defaultVol = Double(VolumeManager.shared.rawVolume)
            if bid == "com.apple.Music" {
                defaultVol = Double(MusicManager.shared.volume)
            }
            let currentVol = volumeStore[bid] ?? (defaultVol > 0.01 ? defaultVol : 0.75)

            result.append(AppVolumeItem(
                id: bid,
                name: name,
                icon: icon,
                volume: currentVol
            ))
        }

        // Sort so the currently playing app appears first
        let currentMediaBid = MusicManager.shared.bundleIdentifier ?? ""
        result.sort { a, b in
            if a.id == currentMediaBid { return true }
            if b.id == currentMediaBid { return false }
            return a.name < b.name
        }

        self.apps = result
    }

    public func setVolume(for item: AppVolumeItem, to val: Double) {
        let clamped = max(0.0, min(1.0, val))
        item.volume = clamped
        volumeStore[item.id] = clamped

        if item.id == "com.apple.Music" {
            let script = "tell application \"Music\" to set sound volume to \(Int(clamped * 100))"
            Task {
                try? await AppleScriptHelper.executeVoid(script)
            }
        } else if item.id == "com.spotify.client" {
            let script = "tell application \"Spotify\" to set sound volume to \(Int(clamped * 100))"
            Task {
                try? await AppleScriptHelper.executeVoid(script)
            }
        } else {
            // For active audio apps (e.g. Yandex Music, Chrome, Telegram), adjust system volume
            VolumeManager.shared.setAbsolute(Float32(clamped))
        }
    }

    public func resetAll() {
        for app in apps {
            app.volume = 1.0
            volumeStore[app.id] = 1.0
            if app.id == "com.apple.Music" {
                Task { try? await AppleScriptHelper.executeVoid("tell application \"Music\" to set sound volume to 100") }
            } else if app.id == "com.spotify.client" {
                Task { try? await AppleScriptHelper.executeVoid("tell application \"Spotify\" to set sound volume to 100") }
            } else {
                VolumeManager.shared.setAbsolute(1.0)
            }
        }
    }
}
