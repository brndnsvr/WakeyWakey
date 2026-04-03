import Foundation

/// Handles CLI commands received via CFMessagePort IPC.
protocol CLICommandHandler: AnyObject {
    func cliEnable(duration: TimeInterval?) -> CLIServer.Response
    func cliDisable() -> CLIServer.Response
    func cliStatus() -> CLIServer.Response
}

/// Listens on a local Mach port for JSON commands from the `wakey` CLI.
final class CLIServer {

    struct Response {
        let ok: Bool
        let message: String

        func toData() -> Data {
            var dict: [String: Any] = ["ok": ok]
            if ok {
                dict["message"] = message
            } else {
                dict["error"] = message
            }
            return (try? JSONSerialization.data(withJSONObject: dict)) ?? Data()
        }
    }

    private static let portName = "com.brndnsvr.WakeyWakey.cli"

    private var port: CFMessagePort?
    private var runLoopSource: CFRunLoopSource?
    private weak var handler: CLICommandHandler?

    init(handler: CLICommandHandler) {
        self.handler = handler
        startListening()
    }

    deinit {
        stop()
    }

    func stop() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
            runLoopSource = nil
        }
        if let port = port {
            CFMessagePortInvalidate(port)
            self.port = nil
        }
    }

    private func startListening() {
        // Store self as info pointer for the C callback
        var context = CFMessagePortContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        port = CFMessagePortCreateLocal(
            nil,
            CLIServer.portName as CFString,
            cliServerCallback,
            &context,
            nil
        )

        guard let port = port else {
            print("WakeyWakey: Failed to create CLI message port")
            return
        }

        runLoopSource = CFMessagePortCreateRunLoopSource(nil, port, 0)
        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        }
    }

    /// Dispatches a parsed command to the handler.
    fileprivate func handleRequest(_ data: Data) -> Data {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let command = json["command"] as? String else {
            return Response(ok: false, message: "Invalid request").toData()
        }

        guard let handler = handler else {
            return Response(ok: false, message: "App not ready").toData()
        }

        let response: Response
        switch command {
        case "enable":
            let duration = json["duration"] as? TimeInterval
            response = handler.cliEnable(duration: duration)
        case "disable":
            response = handler.cliDisable()
        case "status":
            response = handler.cliStatus()
        default:
            response = Response(ok: false, message: "Unknown command: \(command)")
        }

        return response.toData()
    }
}

// C-compatible callback for CFMessagePort
private func cliServerCallback(
    _ port: CFMessagePort?,
    _ msgid: Int32,
    _ data: CFData?,
    _ info: UnsafeMutableRawPointer?
) -> Unmanaged<CFData>? {
    guard let info = info, let data = data as Data? else {
        return nil
    }
    let server = Unmanaged<CLIServer>.fromOpaque(info).takeUnretainedValue()
    let responseData = server.handleRequest(data)
    return Unmanaged.passRetained(responseData as CFData)
}
