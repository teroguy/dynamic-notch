//
//  AgentServer.swift
//  boringNotch
//
//  Created for AI Agent Integration.
//  Lightweight, high-performance UNIX Domain Socket IPC Server.
//

import Foundation

// MARK: - Unix Domain Socket Server
public final class AgentServer {
    public static let shared = AgentServer()

    private var serverFd: Int32 = -1
    private var dispatchSource: DispatchSourceRead?
    private let serverQueue = DispatchQueue(label: "com.theboringteam.boringnotch.agentserver", qos: .userInitiated)
    private var isRunning = false

    public static var primarySocketPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.boring-notch/run/boring-notch.sock"
    }

    public static var fallbackSocketPath: String {
        return "/tmp/boring-notch.sock"
    }

    private init() {}

    public func start() {
        guard !isRunning else { return }
        isRunning = true

        serverQueue.async { [weak self] in
            self?.setupSocket()
        }
    }

    public func stop() {
        guard isRunning else { return }
        isRunning = false

        serverQueue.async { [weak self] in
            self?.teardownSocket()
        }
    }

    private func setupSocket() {
        let socketPath = AgentServer.primarySocketPath
        let fallbackPath = AgentServer.fallbackSocketPath

        // Ensure ~/.boring-notch/run directory exists
        let runDir = (socketPath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: runDir, withIntermediateDirectories: true, attributes: nil)

        // Clean up stale socket files
        unlink(socketPath)
        unlink(fallbackPath)

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            print("[AgentServer] Failed to create socket: \(errno)")
            return
        }

        // Set non-blocking
        let flags = fcntl(fd, F_GETFL, 0)
        if flags != -1 {
            _ = fcntl(fd, F_SETFL, flags | O_NONBLOCK)
        }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)

        let maxSunPathLen = MemoryLayout.size(ofValue: addr.sun_path)
        var bindPath = socketPath
        if socketPath.utf8.count >= maxSunPathLen {
            bindPath = fallbackPath
        }

        _ = withUnsafeMutablePointer(to: &addr.sun_path.0) { ptr in
            bindPath.withCString { cstr in
                strncpy(ptr, cstr, maxSunPathLen - 1)
            }
        }

        let addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)
        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                bind(fd, sa, addrLen)
            }
        }

        guard bindResult == 0 else {
            print("[AgentServer] Failed to bind to \(bindPath): \(errno)")
            close(fd)
            return
        }

        guard listen(fd, 32) == 0 else {
            print("[AgentServer] Failed to listen on socket: \(errno)")
            close(fd)
            return
        }

        // Create symlink to /tmp/boring-notch.sock if bound to primary path
        if bindPath == socketPath {
            try? FileManager.default.createSymbolicLink(atPath: fallbackPath, withDestinationPath: socketPath)
        }

        // Set permissions to 0700 (owner only)
        chmod(bindPath, 0o700)

        self.serverFd = fd

        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: serverQueue)
        source.setEventHandler { [weak self] in
            self?.acceptConnections()
        }
        source.setCancelHandler {
            close(fd)
        }
        source.resume()
        self.dispatchSource = source

        print("[AgentServer] Listening on \(bindPath)")
    }

    private func acceptConnections() {
        while isRunning {
            var clientAddr = sockaddr_un()
            var clientAddrLen = socklen_t(MemoryLayout<sockaddr_un>.size)

            let clientFd = withUnsafeMutablePointer(to: &clientAddr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                    accept(serverFd, sa, &clientAddrLen)
                }
            }

            if clientFd < 0 {
                if errno == EWOULDBLOCK || errno == EAGAIN {
                    break
                }
                break
            }

            // Handle client connection in background
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.handleClient(clientFd)
            }
        }
    }

    private func handleClient(_ clientFd: Int32) {
        // Read client payload
        var buffer = [UInt8](repeating: 0, count: 65536)
        var receivedData = Data()

        // Set read timeout of 10s
        var tv = timeval(tv_sec: 10, tv_usec: 0)
        setsockopt(clientFd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))

        while true {
            let bytesRead = read(clientFd, &buffer, buffer.count)
            if bytesRead > 0 {
                receivedData.append(buffer, count: bytesRead)
                // If payload is a complete JSON or ends with newline, attempt parse
                if let _ = try? JSONSerialization.jsonObject(with: receivedData) {
                    break
                }
                if receivedData.last == UInt8(ascii: "\n") {
                    break
                }
            } else if bytesRead == 0 {
                break
            } else {
                if errno == EAGAIN || errno == EWOULDBLOCK {
                    // Try parsing what we have
                    if let _ = try? JSONSerialization.jsonObject(with: receivedData) {
                        break
                    }
                }
                break
            }
        }

        guard !receivedData.isEmpty else {
            close(clientFd)
            return
        }

        guard let jsonObject = try? JSONSerialization.jsonObject(with: receivedData) as? [String: Any] else {
            close(clientFd)
            return
        }

        processMessage(jsonObject, clientFd: clientFd)
    }

    private func processMessage(_ json: [String: Any], clientFd: Int32) {
        // Extract event metadata
        let eventName = (json["hook_event_name"] as? String)
            ?? (json["event"] as? [String: Any])?["type"] as? String
            ?? "Unknown"

        let sessionId = (json["session_id"] as? String)
            ?? (json["session_key"] as? String)
            ?? (json["_session_key"] as? String)
            ?? UUID().uuidString

        let source = (json["_source"] as? String) ?? (json["source"] as? String) ?? "claude"
        let cwd = (json["cwd"] as? String) ?? (json["working_directory"] as? String) ?? ""

        let toolName = (json["tool_name"] as? String)
        let toolInput = (json["tool_input"] as? [String: Any])
        let prompt = (json["prompt"] as? String)

        let isPermissionRequest = (eventName == "PermissionRequest" || eventName == "pre_approval_request")

        if isPermissionRequest {
            // Keep connection open and forward to AgentManager
            let pendingConn = AgentPendingConnection(fileDescriptor: clientFd, sessionId: sessionId)

            DispatchQueue.main.async {
                AgentManager.shared.handlePermissionRequest(
                    sessionId: sessionId,
                    source: source,
                    cwd: cwd,
                    toolName: toolName ?? "Tool",
                    toolInput: toolInput,
                    pendingConnection: pendingConn
                )
            }
        } else {
            // Non-blocking notification event
            DispatchQueue.main.async {
                AgentManager.shared.handleEvent(
                    eventName: eventName,
                    sessionId: sessionId,
                    source: source,
                    cwd: cwd,
                    toolName: toolName,
                    toolInput: toolInput,
                    prompt: prompt,
                    raw: json
                )
            }

            // Acknowledge and close
            let ack = "{\"ok\":true}\n".data(using: .utf8)!
            _ = ack.withUnsafeBytes { write(clientFd, $0.baseAddress, ack.count) }
            close(clientFd)
        }
    }

    private func teardownSocket() {
        if let source = dispatchSource {
            source.cancel()
            dispatchSource = nil
        }
        if serverFd >= 0 {
            close(serverFd)
            serverFd = -1
        }
        unlink(AgentServer.primarySocketPath)
        unlink(AgentServer.fallbackSocketPath)
    }

    deinit {
        teardownSocket()
    }
}
