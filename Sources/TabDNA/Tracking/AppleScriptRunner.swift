import Foundation
import Darwin

/// The timeout and process completion can race; only one may resume the caller.
final class OnceResumer<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var hasResumed = false
    private let continuation: CheckedContinuation<T, Never>

    init(continuation: CheckedContinuation<T, Never>) {
        self.continuation = continuation
    }

    func resume(returning value: T) {
        lock.lock()
        defer { lock.unlock() }
        guard !hasResumed else { return }
        hasResumed = true
        continuation.resume(returning: value)
    }
}

/// Runs browser scripts outside the main thread, with a timeout for unresponsive browsers.
public enum AppleScriptRunner {
    /// Returns trimmed output, or nil when the script produces no output, fails to launch, or times out.
    public static func run(script: String, timeout: TimeInterval = 2.0) async -> String? {
        await withCheckedContinuation { continuation in
            let resumer = OnceResumer(continuation: continuation)

            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                process.arguments = ["-e", script]

                let outputPipe = Pipe()
                process.standardOutput = outputPipe
                // Unread stderr could fill a pipe and block the browser script.
                process.standardError = FileHandle.nullDevice
                process.standardInput = FileHandle.nullDevice

                let timeoutWorkItem = DispatchWorkItem { [weak process] in
                    // Release the caller before waiting for the process to stop.
                    resumer.resume(returning: nil)

                    guard let p = process, p.isRunning else { return }
                    p.terminate()

                    // Give SIGTERM half a second before forcing termination.
                    DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.5) { [weak process] in
                        guard let p = process, p.isRunning else { return }
                        let pid = p.processIdentifier
                        if pid > 0 {
                            _ = Darwin.kill(pid, SIGKILL)
                        }
                    }
                }

                DispatchQueue.global(qos: .userInitiated).asyncAfter(
                    deadline: .now() + timeout,
                    execute: timeoutWorkItem
                )

                do {
                    try process.run()
                    let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()
                    timeoutWorkItem.cancel()

                    guard let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                          !output.isEmpty else {
                        resumer.resume(returning: nil)
                        return
                    }
                    resumer.resume(returning: output)
                } catch {
                    timeoutWorkItem.cancel()
                    resumer.resume(returning: nil)
                }
            }
        }
    }
}
