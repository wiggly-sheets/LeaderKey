import Cocoa

class CommandRunner {
  static let clipboardLimit = 1_048_576

  static func prepare(command: String, clipboard: String) -> String? {
    let clipboard = clipboard.replacingOccurrences(of: "\0", with: "")
    let placeholder = "{{clipboard}}"
    let escapedPlaceholder = "\\{{clipboard}}"
    let quotedClipboard = "'" + clipboard.replacingOccurrences(of: "'", with: "'\\''") + "'"

    var result = ""
    result.reserveCapacity(command.count)
    var index = command.startIndex

    while index < command.endIndex {
      if command[index...].hasPrefix(escapedPlaceholder) {
        result += placeholder
        index = command.index(index, offsetBy: escapedPlaceholder.count)
      } else if command[index...].hasPrefix(placeholder) {
        guard clipboard.utf8.count <= clipboardLimit else { return nil }
        result += quotedClipboard
        index = command.index(index, offsetBy: placeholder.count)
      } else {
        result.append(command[index])
        index = command.index(after: index)
      }
    }

    return result
  }

  static func run(_ command: String) {
    let clipboard = NSPasteboard.general.string(forType: .string) ?? ""
    guard let command = prepare(command: command, clipboard: clipboard) else {
      DispatchQueue.main.async {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Clipboard too large"
        alert.informativeText = "Clipboard text exceeds the 1 MiB limit. Shorten it and try again."
        alert.runModal()
      }
      return
    }

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
