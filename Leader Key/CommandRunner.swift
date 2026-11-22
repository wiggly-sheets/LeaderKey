import Cocoa

class CommandRunner {
  static func run(_ command: String) {
    DispatchQueue.global(qos: .userInitiated).async {
      let task = Process()
      let pipe = Pipe()
      let errorPipe = Pipe()
      let lock = NSLock()
      var outputData = Data()
      var errorData = Data()

      task.standardOutput = pipe
      task.standardError = errorPipe
      task.launchPath = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/sh"
      task.arguments = ["-c", command]

      pipe.fileHandleForReading.readabilityHandler = { handle in
        let data = handle.availableData
        guard !data.isEmpty else { return }
        lock.lock()
        outputData.append(data)
        lock.unlock()
      }
      errorPipe.fileHandleForReading.readabilityHandler = { handle in
        let data = handle.availableData
        guard !data.isEmpty else { return }
        lock.lock()
        errorData.append(data)
        lock.unlock()
      }

      do {
        try task.run()
      } catch {
        pipe.fileHandleForReading.readabilityHandler = nil
        errorPipe.fileHandleForReading.readabilityHandler = nil
        DispatchQueue.main.async {
          let alert = NSAlert()
          alert.alertStyle = .critical
          alert.messageText = "Failed to run command"
          alert.informativeText = error.localizedDescription
          alert.runModal()
        }
        return
      }

      task.waitUntilExit()

      pipe.fileHandleForReading.readabilityHandler = nil
      errorPipe.fileHandleForReading.readabilityHandler = nil
      lock.lock()
      outputData.append(pipe.fileHandleForReading.readDataToEndOfFile())
      errorData.append(errorPipe.fileHandleForReading.readDataToEndOfFile())
      let error = String(data: errorData, encoding: .utf8) ?? ""
      let output = String(data: outputData, encoding: .utf8) ?? ""
      lock.unlock()

      if task.terminationStatus != 0 {
        let exitCode = task.terminationStatus
        DispatchQueue.main.async {
          let alert = NSAlert()
          alert.alertStyle = .critical
          alert.messageText = "Command failed with exit code \(exitCode)"
          alert.informativeText = [error, output].joined(separator: "\n").trimmingCharacters(
            in: .whitespacesAndNewlines)
          alert.runModal()
        }
      }
    }
  }
}
