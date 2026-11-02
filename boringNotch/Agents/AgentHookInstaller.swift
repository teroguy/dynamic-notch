//
//  AgentHookInstaller.swift
//  boringNotch
//
//  Created for AI Agent Integration.
//  Installs and manages CLI agent hooks (~/.claude/settings.json, bridge executable).
//

import Foundation

public final class AgentHookInstaller {
    public static let shared = AgentHookInstaller()

    private let fileManager = FileManager.default

    public var binDirectory: String {
        let home = fileManager.homeDirectoryForCurrentUser.path
        return "\(home)/.boring-notch/bin"
    }

    public var bridgeScriptPath: String {
        return "\(binDirectory)/boring-notch-bridge"
    }

    public var claudeSettingsPath: String {
        let home = fileManager.homeDirectoryForCurrentUser.path
        return "\(home)/.claude/settings.json"
    }

    private init() {}

    // MARK: - Status
    public var isClaudeCodeInstalled: Bool {
        let home = fileManager.homeDirectoryForCurrentUser.path
        let claudeDir = "\(home)/.claude"
        return fileManager.fileExists(atPath: claudeDir)
    }

    public var areHooksInstalled: Bool {
        guard fileManager.fileExists(atPath: bridgeScriptPath) else { return false }
        guard fileManager.fileExists(atPath: claudeSettingsPath) else { return false }

        guard let data = try? Data(contentsOf: URL(fileURLWithPath: claudeSettingsPath)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let hooks = json["hooks"] as? [String: Any] else {
            return false
        }

        // Check if PermissionRequest hook points to boring-notch
        if let permHooks = hooks["PermissionRequest"] as? [[String: Any]] {
            for entry in permHooks {
                if let subHooks = entry["hooks"] as? [[String: Any]] {
                    for h in subHooks {
                        if let cmd = h["command"] as? String, cmd.contains("boring-notch") {
                            return true
                        }
                    }
                }
            }
        }

        return false
    }

    // MARK: - Installation
    public func ensureInstalledIfNeeded() {
        if !areHooksInstalled && isClaudeCodeInstalled {
            _ = installHooks()
        }
    }

    public func installHooks() -> Bool {
        guard createBridgeScript() else { return false }
        return configureClaudeSettings()
    }

    public func uninstallHooks() -> Bool {
        guard fileManager.fileExists(atPath: claudeSettingsPath) else { return true }

        guard let data = try? Data(contentsOf: URL(fileURLWithPath: claudeSettingsPath)),
              var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              var hooks = json["hooks"] as? [String: Any] else {
            return true
        }

        // Filter out boring-notch hooks
        for (event, value) in hooks {
            if let entries = value as? [[String: Any]] {
                let filtered = entries.filter { entry in
                    guard let subHooks = entry["hooks"] as? [[String: Any]] else { return true }
                    return !subHooks.contains(where: { ($0["command"] as? String)?.contains("boring-notch") == true })
                }
                if filtered.isEmpty {
                    hooks.removeValue(forKey: event)
                } else {
                    hooks[event] = filtered
                }
            }
        }

        json["hooks"] = hooks
        if let updatedData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]) {
            try? updatedData.write(to: URL(fileURLWithPath: claudeSettingsPath))
            return true
        }
        return false
    }

    // MARK: - Bridge Script Generation
    private func createBridgeScript() -> Bool {
        try? fileManager.createDirectory(atPath: binDirectory, withIntermediateDirectories: true, attributes: nil)

        let script = """
        #!/usr/bin/env python3
        # Boring Notch CLI Agent Bridge
        import os
        import sys
        import json
        import socket

        PRIMARY_SOCKET = os.path.expanduser("~/.boring-notch/run/boring-notch.sock")
        CONTAINER_SOCKET = os.path.expanduser("~/Library/Containers/theboringteam.boringnotch/Data/.boring-notch/run/boring-notch.sock")
        FALLBACK_SOCKET = "/tmp/boring-notch.sock"

        def get_socket_path():
            for path in [PRIMARY_SOCKET, CONTAINER_SOCKET, FALLBACK_SOCKET]:
                if os.path.exists(path):
                    return path
            return None

        def main():
            # Read input from stdin
            raw_input = sys.stdin.read()
            if not raw_input.strip():
                sys.exit(0)

            sock_path = get_socket_path()
            if not sock_path:
                # Boring Notch is not running, exit quietly without blocking agent
                sys.exit(0)

            try:
                payload = json.loads(raw_input)
            except Exception:
                payload = {"raw": raw_input}

            # Tag source if argument provided
            if len(sys.argv) > 1:
                payload["_source"] = sys.argv[1]

            event_name = payload.get("hook_event_name") or payload.get("event", {}).get("type") or ""
            is_blocking = (event_name in ["PermissionRequest", "pre_approval_request"])

            try:
                sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
                sock.settimeout(86400 if is_blocking else 5)
                sock.connect(sock_path)

                data = json.dumps(payload).encode("utf-8") + b"\\n"
                sock.sendall(data)

                if is_blocking:
                    # Wait for response from Boring Notch
                    response = b""
                    while True:
                        chunk = sock.recv(4096)
                        if not chunk:
                            break
                        response += chunk
                        if b"\\n" in chunk:
                            break
                    if response:
                        sys.stdout.write(response.decode("utf-8"))
                        sys.stdout.flush()

                sock.close()
            except Exception:
                pass

            sys.exit(0)

        if __name__ == "__main__":
            main()
        """

        guard let data = script.data(using: .utf8) else { return false }
        let scriptURL = URL(fileURLWithPath: bridgeScriptPath)
        do {
            try data.write(to: scriptURL)
            // chmod 755
            try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: bridgeScriptPath)

            // Also create symlink agent-hook
            let agentHookPath = "\(binDirectory)/agent-hook"
            unlink(agentHookPath)
            try? fileManager.createSymbolicLink(atPath: agentHookPath, withDestinationPath: bridgeScriptPath)
            return true
        } catch {
            print("[AgentHookInstaller] Failed to write bridge script: \(error)")
            return false
        }
    }

    // MARK: - Configure Claude settings.json
    private func configureClaudeSettings() -> Bool {
        let settingsURL = URL(fileURLWithPath: claudeSettingsPath)
        let claudeDir = (claudeSettingsPath as NSString).deletingLastPathComponent
        try? fileManager.createDirectory(atPath: claudeDir, withIntermediateDirectories: true, attributes: nil)

        var settings: [String: Any] = [:]
        if fileManager.fileExists(atPath: claudeSettingsPath),
           let existingData = try? Data(contentsOf: settingsURL),
           let existingJson = try? JSONSerialization.jsonObject(with: existingData) as? [String: Any] {
            settings = existingJson

            // Create backup
            let backupPath = "\(claudeSettingsPath).backup"
            try? existingData.write(to: URL(fileURLWithPath: backupPath))
        }

        var hooks = (settings["hooks"] as? [String: Any]) ?? [:]
        let hookCommand = "'\(bridgeScriptPath)' claude"

        let events = [
            ("SessionStart", 10, false),
            ("SessionEnd", 10, false),
            ("UserPromptSubmit", 10, false),
            ("PreToolUse", 10, true),
            ("PostToolUse", 10, true),
            ("PermissionRequest", 86400, true),
            ("Notification", 10, false),
            ("Stop", 10, false)
        ]

        for (eventName, timeout, hasMatcher) in events {
            var existingEntries = (hooks[eventName] as? [[String: Any]]) ?? []

            // Remove existing boring-notch hook if any
            existingEntries = existingEntries.filter { entry in
                guard let subHooks = entry["hooks"] as? [[String: Any]] else { return true }
                return !subHooks.contains(where: { ($0["command"] as? String)?.contains("boring-notch") == true })
            }

            var newEntry: [String: Any] = [
                "hooks": [
                    [
                        "command": hookCommand,
                        "timeout": timeout,
                        "type": "command"
                    ]
                ]
            ]
            if hasMatcher {
                newEntry["matcher"] = "*"
            }

            existingEntries.append(newEntry)
            hooks[eventName] = existingEntries
        }

        settings["hooks"] = hooks

        do {
            let data = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: settingsURL)
            print("[AgentHookInstaller] Successfully configured Claude Code hooks in \(claudeSettingsPath)")
            return true
        } catch {
            print("[AgentHookInstaller] Failed to write settings.json: \(error)")
            return false
        }
    }
}
