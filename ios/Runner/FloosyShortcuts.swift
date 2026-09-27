import AppIntents
import Foundation

@available(iOS 16.0, *)
struct LogFloosyTransactionIntent: AppIntent {
  private let appGroup = "group.net.floosy.app"
  private let captureKey = "floosy_pending_captures"

  static var title: LocalizedStringResource = "Log in Floosy"
  static var description = IntentDescription(
    "Save an expense or income note for review in Floosy."
  )
  static var openAppWhenRun = true

  @Parameter(title: "Transaction")
  var transactionText: String

  func perform() async throws -> some IntentResult & ProvidesDialog {
    let body = transactionText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !body.isEmpty else {
      return .result(dialog: "No message content was received.")
    }
    guard let defaults = UserDefaults(suiteName: appGroup) else {
      return .result(dialog: "Floosy could not access its shared capture storage.")
    }
    var pending = defaults.array(forKey: captureKey) as? [[String: String]] ?? []
    pending.append([
      "sender": "Apple Shortcuts",
      "body": body,
      "fingerprint": UUID().uuidString,
    ])
    defaults.set(pending, forKey: captureKey)
    return .result(dialog: "Saved in Floosy for review.")
  }
}

@available(iOS 16.0, *)
struct FloosyAppShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: LogFloosyTransactionIntent(),
      phrases: [
        "Log money in \(.applicationName)",
        "Add an expense to \(.applicationName)",
      ],
      shortTitle: "Log transaction",
      systemImageName: "banknote"
    )
  }
}
