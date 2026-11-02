//
//  AudioOutputDeviceManager.swift
//  boringNotch
//
//  Created in NotchNook Pro style.
//  Manages CoreAudio output devices (speakers, AirPods, Bluetooth, AirPlay) and switching.
//

import AppKit
import CoreAudio
import Foundation
import SwiftUI

public struct AudioOutputDevice: Identifiable, Equatable {
    public let id: AudioDeviceID
    public let name: String
    public let isDefault: Bool
    public let transportType: UInt32

    public var iconName: String {
        let lower = name.lowercased()
        if lower.contains("airpod") {
            return "headphones"
        }
        if lower.contains("headphone") || lower.contains("наушник") {
            return "headphones"
        }
        if lower.contains("macbook") || lower.contains("mac") || lower.contains("встроен") {
            return "laptopcomputer"
        }
        if lower.contains("living") || lower.contains("room") || lower.contains("speaker") || lower.contains("колонк") || lower.contains("динамик") {
            return "hifispeaker.fill"
        }
        if lower.contains("display") || lower.contains("monitor") || lower.contains("tv") {
            return "display"
        }
        return "laptopcomputer"
    }

    public var iconColor: Color {
        .white
    }

    public var iconBgColor: Color {
        isDefault ? Color.blue : Color.white.opacity(0.12)
    }
}

@MainActor
public final class AudioOutputDeviceManager: ObservableObject {
    public static let shared = AudioOutputDeviceManager()

    @Published public private(set) var devices: [AudioOutputDevice] = []
    @Published public private(set) var defaultDeviceID: AudioDeviceID = 0

    private init() {
        refreshDevices()
        setupListeners()
    }

    public func refreshDevices() {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize)
        guard status == noErr else { return }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var allDevices = [AudioDeviceID](repeating: 0, count: deviceCount)
        status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize, &allDevices)
        guard status == noErr else { return }

        // Get default output device
        var defaultAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var defDevice: AudioDeviceID = 0
        var defSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        _ = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &defaultAddr, 0, nil, &defSize, &defDevice)
        self.defaultDeviceID = defDevice

        var result: [AudioOutputDevice] = []

        for dev in allDevices {
            // Check output streams
            var streamAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreamConfiguration,
                mScope: kAudioObjectPropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            var streamSize: UInt32 = 0
            AudioObjectGetPropertyDataSize(dev, &streamAddr, 0, nil, &streamSize)
            guard streamSize > 0 else { continue }

            // Device Name
            var nameAddr = AudioObjectPropertyAddress(
                mSelector: kAudioObjectPropertyName,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var cfName: Unmanaged<CFString>?
            var nameSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
            _ = AudioObjectGetPropertyData(dev, &nameAddr, 0, nil, &nameSize, &cfName)
            let name = cfName?.takeRetainedValue() as String? ?? "Audio Device"

            // Filter out input-only or microphone virtual devices if labeled as mic
            if name.lowercased().contains("микрофон") || name.lowercased().contains("microphone") {
                continue
            }

            // Transport Type
            var transportAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyTransportType,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var transport: UInt32 = 0
            var transportSize = UInt32(MemoryLayout<UInt32>.size)
            _ = AudioObjectGetPropertyData(dev, &transportAddr, 0, nil, &transportSize, &transport)

            result.append(AudioOutputDevice(
                id: dev,
                name: name,
                isDefault: (dev == defDevice),
                transportType: transport
            ))
        }

        self.devices = result
    }

    public func setOutputDevice(_ device: AudioOutputDevice) {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var devID = device.id
        let dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, dataSize, &devID)
        if status == noErr {
            self.defaultDeviceID = devID
            refreshDevices()
        }
    }

    private func setupListeners() {
        var defaultAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &defaultAddr, DispatchQueue.main) { [weak self] _, _ in
            self?.refreshDevices()
        }

        var devAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &devAddr, DispatchQueue.main) { [weak self] _, _ in
            self?.refreshDevices()
        }
    }
}
