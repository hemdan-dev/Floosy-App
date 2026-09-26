import AppIntents
import Foundation

@available(iOS 16.0, *)
struct LogFloosyTransactionIntent: AppIntent {
  static var title: LocalizedStringResource = "Log in Floosy"
  static var description = IntentDescription(
    "Save an expense or income note for review in Floosy."
  )
  static var openAppWhenRun = true

  @Parameter(title: "Transaction")
  var transactionText: String

  func perform() async throws -> some IntentResult & ProvidesDialog {
    let key = "floosy_pending_captures"
    var pending = UserDefaults.standard.array(forKey: key) as? [[String: String]] ?? []
    pending.append([
      "sender": "Apple Shortcuts",
      "body": transactionText,
      "fingerprint": UUID().uuidString,
    ])
    UserDefaults.standard.set(pending, forKey: key)
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
