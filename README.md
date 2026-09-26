# Floosy

Floosy is a private, offline-first personal finance app for Android and iOS. It
uses a local SQLite database, has no Floosy account, subscription, advertising,
or analytics, and can replicate its data to the signed-in owner’s private
Google Drive `appDataFolder`.

## Included features

- Expense, income, and account-to-account transfer entry
- Manual, natural-language, voice, Android bank-SMS, and Apple Shortcut capture
- Mandatory preview for AI-parsed text and voice; unambiguous bank SMS can be
  saved locally without an AI call, while ambiguous messages enter the review queue
- Accounts, cards, exact legacy categories, budgets, installments, assets, gold
  pricing, foreign-exchange rates, and net-worth balances
- Monthly overview, transaction search/filtering, daily spending chart, and insights
- Private AI Q&A using computed summaries and recent transactions
- CSV, JSON, and PDF exports
- English and Arabic UI with RTL support, EGP defaults, light/dark themes, and
  optional biometric/device-passcode lock
- Offline writes with automatic retry after connectivity returns
- Multi-device Google Drive replication using compressed operation logs,
  idempotent replay, and hybrid logical-clock conflict handling

OpenAI requests use `gpt-4o-mini`; voice transcription uses `gpt-transcribe`.
The key is entered inside Settings and stored in the platform secure keystore.

## Local development

Requirements: Flutter 3.41 or newer and Dart 3.11 or newer.

```powershell
flutter pub get
dart run build_runner build
flutter test
flutter run
```

Android builds also require Android SDK command-line tools and accepted SDK
licenses. iOS builds and signing require macOS with Xcode.

## Google Drive setup

Google Drive does not use a static API key for private user data. OAuth is the
safer and correct mechanism: it grants this private build only the
`drive.appdata` scope, and the user can revoke it at any time.

1. In Google Cloud Console, create a project and enable Google Drive API.
2. Configure the OAuth consent screen and add the owner’s Google account as a
   test user if the app remains in testing mode.
3. Create an Android OAuth client for package `net.floosy.app` and the signing
   certificate SHA-1. Create the Web client ID used as the server client ID (or
   use the Google Services configuration supported by `google_sign_in`).
4. Create an iOS OAuth client for bundle ID `net.floosy.app`. Add that client’s
   reversed client ID as another URL scheme in `ios/Runner/Info.plist`.
5. Run a private build with the relevant IDs:

```powershell
flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=000000.apps.googleusercontent.com
```

On iOS add:

```powershell
--dart-define=GOOGLE_IOS_CLIENT_ID=000000.apps.googleusercontent.com
```

The first tap on **Google Drive sync** asks for Google authorization. After
that, Floosy restores a legacy baseline if present, uploads this device’s state
and operation logs, downloads other devices’ logs, and automatically retries
when connectivity returns. Drive’s app-data directory is hidden from the normal
Drive file list and accessible only to this app’s OAuth client.

## OpenAI setup

Open Floosy → Settings → OpenAI API key, paste a project API key, and choose
**Save & test**. The key is never written to SQLite, exports, source control, or
Google Drive. This client-only setup is appropriate for a private personal
build, but a backend token broker is safer if the app is ever distributed to
other people.

## Legacy data migration

`unstractures_data.txt` stays out of the app bundle and is ignored by Git. The
developer-only migration reads its three concatenated JSON documents, preserves
legacy IDs/categories/deletions, validates golden totals, and writes a compressed
baseline plus an audit report:

```powershell
dart run tool/migrate_legacy.dart
```

Validated source totals:

- 2,436 records: 2,396 active and 40 deleted
- 154 active income and 2,242 active expense records
- EGP 1,389,999.00 income and EGP 1,476,842.38 expense
- 74 category documents and one Cash account

Output is placed in ignored `migration-output/`. To upload the validated
baseline directly to the same private Drive app-data space, create a Desktop
OAuth client and run:

```powershell
dart run tool/migrate_legacy.dart --upload `
  --client-id YOUR_DESKTOP_CLIENT_ID `
  --client-secret YOUR_DESKTOP_CLIENT_SECRET
```

The CLI opens Google’s consent flow. On the first mobile sync, Floosy imports
`floosy-baseline-v1.json.gz` once and records its source fingerprint so it cannot
be imported twice.

## Platform capture notes

- Android registers an SMS receiver and asks for SMS permission. A unique,
  clearly classified EGP debit/credit is saved; messages with multiple amounts
  or unclear direction remain in **Needs review**.
- iOS exposes **Log in Floosy** through App Intents/Shortcuts. Apple does not
  allow third-party apps to read the SMS inbox, so an automation can pass the
  bank message text to this intent.

SMS permissions are highly restricted for public Google Play releases. This
implementation is intended for the requested private build.
