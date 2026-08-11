import Foundation

// MARK: - Constants

let portName = "com.brndnsvr.WakeyWakey.cli"
let sendTimeout: CFTimeInterval = 5.0
let recvTimeout: CFTimeInterval = 5.0

// MARK: - Help

let version = "1.2.1"
let build = "6"

let helpText = """
WakeyWakey v\(version) (build \(build))
by Brandon Seaver — https://wakeywakey.app

Prevent macOS idle sleep from the command line.

USAGE:
    wakey <command> [options]

COMMANDS:
    enable          Enable indefinitely
    enable <dur>    Enable for a duration (e.g., 2h, 90m, 3.5h)
    disable         Disable
    status          Show current status

OPTIONS:
    --help, -h      Show this help message

EXAMPLES:
    wakey enable
    wakey enable 2h
    wakey enable 90m
    wakey enable 3.5h
    wakey disable
    wakey status
"""

// MARK: - IPC

func sendCommand(_ request: [String: Any]) -> (ok: Bool, message: String) {
    guard let port = CFMessagePortCreateRemote(nil, portName as CFString) else {
        return (false, "WakeyWakey is not running.")
    }

    guard let data = try? JSONSerialization.data(withJSONObject: request) else {
        return (false, "Internal error: failed to encode request.")
    }

    var response: Unmanaged<CFData>?
    let status = CFMessagePortSendRequest(
        port,
        0, // msgid
        data as CFData,
        sendTimeout,
        recvTimeout,
        CFRunLoopMode.defaultMode.rawValue,
        &response
    )

    guard status == kCFMessagePortSuccess else {
        return (false, "Failed to communicate with WakeyWakey (error \(status)).")
    }

    guard let responseData = response?.takeRetainedValue() as Data?,
          let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any] else {
        return (false, "Invalid response from WakeyWakey.")
    }

    let ok = json["ok"] as? Bool ?? false
    let msg = json["message"] as? String ?? json["error"] as? String ?? "Unknown response"
    return (ok, msg)
}

// MARK: - Main

let args = Array(CommandLine.arguments.dropFirst()) // drop program name

if args.isEmpty || args.first == "--help" || args.first == "-h" {
    print(helpText)
    exit(0)
}

let command = args[0].lowercased()

switch command {
case "enable":
    var request: [String: Any] = ["command": "enable"]
    if args.count >= 2 {
        guard let seconds = DurationParser.parse(args[1]) else {
            fputs("Invalid duration: \(args[1]). Use format like 2h, 90m, or 3.5h.\n", stderr)
            exit(1)
        }
        request["duration"] = seconds
    }
    let result = sendCommand(request)
    print(result.message)
    exit(result.ok ? 0 : 1)

case "disable":
    let result = sendCommand(["command": "disable"])
    print(result.message)
    exit(result.ok ? 0 : 1)

case "status":
    let result = sendCommand(["command": "status"])
    print(result.message)
    exit(result.ok ? 0 : 1)

default:
    fputs("Unknown command: \(command). Run 'wakey --help' for usage.\n", stderr)
    exit(1)
}
