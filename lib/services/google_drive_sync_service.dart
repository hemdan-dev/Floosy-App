import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../core/hybrid_clock.dart';
import '../data/database/app_database.dart';

const _uuid = Uuid();

enum DriveConnectionState { disconnected, connected, syncing, error }

class DriveSyncReport {
  const DriveSyncReport({
    required this.uploaded,
    required this.downloaded,
    required this.applied,
    required this.conflicts,
    required this.baselineImported,
  });

  final int uploaded;
  final int downloaded;
  final int applied;
  final int conflicts;
  final bool baselineImported;
}

/// Offline-first replication through the private Google Drive appDataFolder.
///
/// Each device owns append-only, month-sized operation files. Operations are
/// idempotent, and last-writer-wins is determined using a hybrid logical clock.
class GoogleDriveSyncService {
  GoogleDriveSyncService(this.db);

  static const _scopes = [drive.DriveApi.driveAppdataScope];
  static const _baselineName = 'floosy-baseline-v1.json.gz';

  final AppDatabase db;
  final GoogleSignIn _signIn = GoogleSignIn.instance;
  GoogleSignInAccount? _account;
  bool _initialized = false;

  String? get connectedEmail => _account?.email;

  Future<void> initialize() async {
    if (_initialized) return;
    const clientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');
    const serverClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
    await _signIn.initialize(
      clientId: clientId.isEmpty ? null : clientId,
      serverClientId: serverClientId.isEmpty ? null : serverClientId,
    );
    _initialized = true;
    _account = await _signIn.attemptLightweightAuthentication();
  }

  Future<String> connect() async {
    await initialize();
    final account = await _signIn.authenticate(scopeHint: _scopes);
    await account.authorizationClient.authorizeScopes(_scopes);
    _account = account;
    await db.setSetting('driveEmail', account.email);
    return account.email;
  }

  Future<void> disconnect() async {
    await initialize();
    await _signIn.disconnect();
    _account = null;
    await db.setSetting('driveEmail', '');
  }

  Future<DriveSyncReport> sync({bool interactive = false}) async {
    await initialize();
    if (_account == null && interactive) await connect();
    final account = _account;
    if (account == null) {
      throw StateError('Connect Google Drive before syncing.');
    }

    final headers = await account.authorizationClient.authorizationHeaders(
      _scopes,
      promptIfNecessary: interactive,
    );
    if (headers == null) {
      throw StateError('Google Drive permission needs to be renewed.');
    }

    final client = _HeaderClient(headers);
    try {
      final api = drive.DriveApi(client);
      final baselineImported = await _restoreBaselineIfNeeded(api);
      final uploaded = await _uploadLocalOperations(api);
      await _uploadLocalState(api);
      final stateResult = await _downloadAndApplyStates(api);
      final result = await _downloadAndApplyOperations(api);
      await db.setSetting(
        'lastSyncAt',
        DateTime.now().toUtc().toIso8601String(),
      );
      return DriveSyncReport(
        uploaded: uploaded,
        downloaded: result.$1 + stateResult.$1,
        applied: result.$2 + stateResult.$2,
        conflicts: result.$3,
        baselineImported: baselineImported,
      );
    } finally {
      client.close();
    }
  }

  Future<void> _uploadLocalState(drive.DriveApi api) async {
    final deviceId = await db.getSetting('deviceId') ?? 'unknown-device';
    final payload = <String, Object?>{
      'format': 'floosy-state-v1',
      'deviceId': deviceId,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'accounts': (await db.select(db.accounts).get())
          .map((row) => row.toJson())
          .toList(),
      'cards': (await db.select(db.cards).get())
          .map((row) => row.toJson())
          .toList(),
      'categories': (await db.select(db.categories).get())
          .map((row) => row.toJson())
          .toList(),
      'merchantRules': (await db.select(db.merchantRules).get())
          .map((row) => row.toJson())
          .toList(),
      'budgets': (await db.select(db.budgets).get())
          .map((row) => row.toJson())
          .toList(),
      'installmentPlans': (await db.select(db.installmentPlans).get())
          .map((row) => row.toJson())
          .toList(),
      'assets': (await db.select(db.assets).get())
          .map((row) => row.toJson())
          .toList(),
      'aiMessages': (await db.select(db.aiMessages).get())
          .map((row) => row.toJson())
          .toList(),
    };
    final bytes = Uint8List.fromList(
      gzip.encode(utf8.encode(jsonEncode(payload))),
    );
    await _upsertAppDataFile(
      api,
      'floosy-state-$deviceId.json.gz',
      bytes,
      'application/gzip',
    );
  }

  Future<(int, int)> _downloadAndApplyStates(drive.DriveApi api) async {
    final files = await _listAppDataFiles(api, "name contains 'floosy-state-'");
    var applied = 0;
    for (final file in files) {
      if (file.id == null) continue;
      final payload =
          jsonDecode(utf8.decode(gzip.decode(await _download(api, file.id!))))
              as Map<String, dynamic>;
      if (payload['format'] != 'floosy-state-v1') continue;
      applied += await _mergeState(payload);
    }
    return (files.length, applied);
  }

  Future<int> _mergeState(Map<String, dynamic> payload) async {
    var applied = 0;
    await db.transaction(() async {
      for (final raw in payload['accounts'] as List? ?? const []) {
        final remote = Account.fromJson((raw as Map).cast<String, dynamic>());
        final local = await (db.select(
          db.accounts,
        )..where((row) => row.id.equals(remote.id))).getSingleOrNull();
        if (_remoteWins(
          remote.syncStamp,
          remote.updatedAt,
          local?.syncStamp,
          local?.updatedAt,
        )) {
          await db.into(db.accounts).insertOnConflictUpdate(remote);
          applied++;
        }
      }
      for (final raw in payload['categories'] as List? ?? const []) {
        final remote = Category.fromJson((raw as Map).cast<String, dynamic>());
        final local = await (db.select(
          db.categories,
        )..where((row) => row.id.equals(remote.id))).getSingleOrNull();
        if (_remoteWins(
          remote.syncStamp,
          remote.updatedAt,
          local?.syncStamp,
          local?.updatedAt,
        )) {
          await db.into(db.categories).insertOnConflictUpdate(remote);
          applied++;
        }
      }
      for (final raw in payload['cards'] as List? ?? const []) {
        final remote = Card.fromJson((raw as Map).cast<String, dynamic>());
        final local = await (db.select(
          db.cards,
        )..where((row) => row.id.equals(remote.id))).getSingleOrNull();
        if (_remoteWins(
          remote.syncStamp,
          remote.updatedAt,
          local?.syncStamp,
          local?.updatedAt,
        )) {
          await db.into(db.cards).insertOnConflictUpdate(remote);
          applied++;
        }
      }
      for (final raw in payload['merchantRules'] as List? ?? const []) {
        final remote = MerchantRule.fromJson(
          (raw as Map).cast<String, dynamic>(),
        );
        final local = await (db.select(
          db.merchantRules,
        )..where((row) => row.id.equals(remote.id))).getSingleOrNull();
        if (_remoteWins(
          remote.syncStamp,
          remote.updatedAt,
          local?.syncStamp,
          local?.updatedAt,
        )) {
          await db.into(db.merchantRules).insertOnConflictUpdate(remote);
          applied++;
        }
      }
      for (final raw in payload['budgets'] as List? ?? const []) {
        final remote = Budget.fromJson((raw as Map).cast<String, dynamic>());
        final local = await (db.select(
          db.budgets,
        )..where((row) => row.id.equals(remote.id))).getSingleOrNull();
        if (_remoteWins(
          remote.syncStamp,
          remote.updatedAt,
          local?.syncStamp,
          local?.updatedAt,
        )) {
          await db.into(db.budgets).insertOnConflictUpdate(remote);
          applied++;
        }
      }
      for (final raw in payload['installmentPlans'] as List? ?? const []) {
        final remote = InstallmentPlan.fromJson(
          (raw as Map).cast<String, dynamic>(),
        );
        final local = await (db.select(
          db.installmentPlans,
        )..where((row) => row.id.equals(remote.id))).getSingleOrNull();
        if (_remoteWins(
          remote.syncStamp,
          remote.updatedAt,
          local?.syncStamp,
          local?.updatedAt,
        )) {
          await db.into(db.installmentPlans).insertOnConflictUpdate(remote);
          applied++;
        }
      }
      for (final raw in payload['assets'] as List? ?? const []) {
        final remote = Asset.fromJson((raw as Map).cast<String, dynamic>());
        final local = await (db.select(
          db.assets,
        )..where((row) => row.id.equals(remote.id))).getSingleOrNull();
        if (_remoteWins(
          remote.syncStamp,
          remote.updatedAt,
          local?.syncStamp,
          local?.updatedAt,
        )) {
          await db.into(db.assets).insertOnConflictUpdate(remote);
          applied++;
        }
      }
      for (final raw in payload['aiMessages'] as List? ?? const []) {
        final remote = AiMessage.fromJson((raw as Map).cast<String, dynamic>());
        final local = await (db.select(
          db.aiMessages,
        )..where((row) => row.id.equals(remote.id))).getSingleOrNull();
        if (_remoteWins(
          remote.syncStamp,
          remote.updatedAt,
          local?.syncStamp,
          local?.updatedAt,
        )) {
          await db.into(db.aiMessages).insertOnConflictUpdate(remote);
          applied++;
        }
      }
    });
    return applied;
  }

  bool _remoteWins(
    String remoteStamp,
    DateTime remoteUpdatedAt,
    String? localStamp,
    DateTime? localUpdatedAt,
  ) {
    if (localStamp == null || localUpdatedAt == null) return true;
    if (remoteStamp != SyncColumns.initialStamp ||
        localStamp != SyncColumns.initialStamp) {
      return HybridClock.compare(remoteStamp, localStamp) > 0;
    }
    return remoteUpdatedAt.isAfter(localUpdatedAt);
  }

  Future<int> _uploadLocalOperations(drive.DriveApi api) async {
    final operations = await (db.select(
      db.syncOperations,
    )..orderBy([(row) => OrderingTerm.asc(row.createdAt)])).get();
    if (operations.isEmpty) return 0;

    final grouped = <String, List<SyncOperation>>{};
    for (final operation in operations) {
      final month =
          '${operation.createdAt.year.toString().padLeft(4, '0')}-'
          '${operation.createdAt.month.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(month, () => []).add(operation);
    }

    final deviceId = await db.getSetting('deviceId') ?? 'unknown-device';
    var uploaded = 0;
    for (final entry in grouped.entries) {
      final name = 'floosy-ops-$deviceId-${entry.key}.jsonl.gz';
      final body = entry.value
          .map(
            (operation) => jsonEncode({
              'id': operation.id,
              'deviceId': operation.deviceId,
              'entityType': operation.entityType,
              'entityId': operation.entityId,
              'action': operation.action,
              'stamp': operation.stamp,
              'payload': jsonDecode(operation.payloadJson),
              'createdAt': operation.createdAt.toUtc().toIso8601String(),
            }),
          )
          .join('\n');
      final bytes = Uint8List.fromList(gzip.encode(utf8.encode(body)));
      await _upsertAppDataFile(api, name, bytes, 'application/gzip');
      final ids = entry.value.map((operation) => operation.id).toList();
      await (db.update(
        db.syncOperations,
      )..where((row) => row.id.isIn(ids))).write(
        SyncOperationsCompanion(uploadedAt: Value(DateTime.now().toUtc())),
      );
      uploaded += entry.value
          .where((operation) => operation.uploadedAt == null)
          .length;
    }
    return uploaded;
  }

  Future<(int, int, int)> _downloadAndApplyOperations(
    drive.DriveApi api,
  ) async {
    final files = await _listAppDataFiles(api, "name contains 'floosy-ops-'");
    var applied = 0;
    var conflicts = 0;
    for (final file in files) {
      final id = file.id;
      if (id == null) continue;
      final bytes = await _download(api, id);
      final decoded = utf8.decode(gzip.decode(bytes));
      for (final line in const LineSplitter().convert(decoded)) {
        if (line.trim().isEmpty) continue;
        final operation = jsonDecode(line) as Map<String, dynamic>;
        final outcome = await _applyOperation(operation);
        if (outcome == _ApplyOutcome.applied) applied++;
        if (outcome == _ApplyOutcome.conflict) conflicts++;
      }
    }
    return (files.length, applied, conflicts);
  }

  Future<_ApplyOutcome> _applyOperation(Map<String, dynamic> operation) async {
    final operationId = operation['id'] as String;
    final alreadyApplied = await (db.select(
      db.appliedOperations,
    )..where((row) => row.id.equals(operationId))).getSingleOrNull();
    if (alreadyApplied != null) return _ApplyOutcome.ignored;

    if (operation['entityType'] != 'transaction') {
      await _markApplied(operationId);
      return _ApplyOutcome.ignored;
    }

    final entityId = operation['entityId'] as String;
    final remoteStamp = operation['stamp'] as String;
    final payload = (operation['payload'] as Map).cast<String, dynamic>();
    final local = await (db.select(
      db.financeTransactions,
    )..where((row) => row.id.equals(entityId))).getSingleOrNull();
    if (local != null &&
        HybridClock.compare(remoteStamp, local.syncStamp) <= 0) {
      await db
          .into(db.syncConflicts)
          .insert(
            SyncConflictsCompanion.insert(
              id: _uuid.v7(),
              entityType: 'transaction',
              entityId: entityId,
              winningStamp: local.syncStamp,
              losingPayloadJson: jsonEncode(operation),
              createdAt: DateTime.now().toUtc(),
            ),
          );
      await _markApplied(operationId);
      return _ApplyOutcome.conflict;
    }

    final action = operation['action'] as String;
    if (action == 'delete') {
      if (local != null) {
        await (db.update(
          db.financeTransactions,
        )..where((row) => row.id.equals(entityId))).write(
          FinanceTransactionsCompanion(
            deletedAt: Value(
              DateTime.tryParse(
                    payload['deletedAt'] as String? ?? '',
                  )?.toUtc() ??
                  DateTime.now().toUtc(),
            ),
            updatedAt: Value(DateTime.now().toUtc()),
            syncStamp: Value(remoteStamp),
          ),
        );
      }
    } else {
      await db
          .into(db.financeTransactions)
          .insertOnConflictUpdate(
            FinanceTransactionsCompanion.insert(
              id: entityId,
              kind: payload['kind'] as String,
              amountMinor: (payload['amountMinor'] as num).toInt(),
              currencyCode: Value(payload['currencyCode'] as String? ?? 'EGP'),
              accountId: payload['accountId'] as String,
              destinationAccountId: Value(
                payload['destinationAccountId'] as String?,
              ),
              transferGroupId: Value(payload['transferGroupId'] as String?),
              cardId: Value(payload['cardId'] as String?),
              categoryId: Value(payload['categoryId'] as String?),
              merchant: Value(payload['merchant'] as String?),
              note: Value(payload['note'] as String?),
              tagsJson: Value(jsonEncode(payload['tags'] ?? const [])),
              source: Value(payload['source'] as String? ?? 'sync'),
              sourceFingerprint: Value(payload['sourceFingerprint'] as String?),
              status: Value(payload['status'] as String? ?? 'posted'),
              exchangeRateToBase: Value(
                (payload['exchangeRateToBase'] as num?)?.toDouble() ?? 1,
              ),
              occurredAt: DateTime.parse(
                payload['occurredAt'] as String,
              ).toUtc(),
              createdAt: DateTime.parse(payload['createdAt'] as String).toUtc(),
              updatedAt: DateTime.parse(payload['updatedAt'] as String).toUtc(),
              syncStamp: Value(remoteStamp),
            ),
          );
    }
    await _markApplied(operationId);
    return _ApplyOutcome.applied;
  }

  Future<void> _markApplied(String id) async {
    await db
        .into(db.appliedOperations)
        .insertOnConflictUpdate(
          AppliedOperationsCompanion.insert(
            id: id,
            appliedAt: DateTime.now().toUtc(),
          ),
        );
  }

  Future<bool> _restoreBaselineIfNeeded(drive.DriveApi api) async {
    final completed = await (db.select(
      db.migrationRuns,
    )..where((row) => row.id.equals('legacy-baseline-v1'))).getSingleOrNull();
    if (completed != null) return false;
    final files = await _listAppDataFiles(api, "name = '$_baselineName'");
    if (files.isEmpty || files.first.id == null) return false;
    final bytes = await _download(api, files.first.id!);
    final baseline =
        jsonDecode(utf8.decode(gzip.decode(bytes))) as Map<String, dynamic>;
    await LegacyBaselineImporter(db).import(baseline);
    return true;
  }

  Future<List<drive.File>> _listAppDataFiles(
    drive.DriveApi api,
    String query,
  ) async {
    final result = await api.files.list(
      spaces: 'appDataFolder',
      q: '$query and trashed = false',
      $fields: 'files(id,name,modifiedTime,size)',
      pageSize: 1000,
    );
    return result.files ?? const [];
  }

  Future<void> _upsertAppDataFile(
    drive.DriveApi api,
    String name,
    Uint8List bytes,
    String contentType,
  ) async {
    final matches = await _listAppDataFiles(api, "name = '$name'");
    final media = drive.Media(
      Stream.value(bytes),
      bytes.length,
      contentType: contentType,
    );
    if (matches.isEmpty) {
      await api.files.create(
        drive.File(name: name, parents: const ['appDataFolder']),
        uploadMedia: media,
        $fields: 'id,name',
      );
    } else {
      await api.files.update(
        drive.File(name: name),
        matches.first.id!,
        uploadMedia: media,
        $fields: 'id,name',
      );
    }
  }

  Future<Uint8List> _download(drive.DriveApi api, String id) async {
    final media =
        await api.files.get(
              id,
              downloadOptions: drive.DownloadOptions.fullMedia,
            )
            as drive.Media;
    final chunks = await media.stream.toList();
    return Uint8List.fromList(chunks.expand((chunk) => chunk).toList());
  }
}

class LegacyBaselineImporter {
  LegacyBaselineImporter(this.db);

  final AppDatabase db;

  Future<void> import(Map<String, dynamic> baseline) async {
    final fingerprint = baseline['sourceFingerprint'] as String? ?? 'unknown';
    final accounts = (baseline['accounts'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    final categories = (baseline['categories'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    final transactions = (baseline['transactions'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    final now = DateTime.now().toUtc();

    await db.transaction(() async {
      final localTransactions = await db.select(db.financeTransactions).get();
      if (localTransactions.isEmpty) {
        await (db.delete(
          db.accounts,
        )..where((row) => row.id.equals('account-cash'))).go();
        await (db.delete(
          db.categories,
        )..where((row) => row.isSystem.equals(true))).go();
      }
      for (final item in accounts) {
        await db
            .into(db.accounts)
            .insertOnConflictUpdate(
              AccountsCompanion.insert(
                id: item['id'] as String,
                name: item['name'] as String,
                type: Value(item['type'] as String? ?? 'cash'),
                currencyCode: Value(item['currencyCode'] as String? ?? 'EGP'),
                initialBalanceMinor: Value(
                  (item['initialBalanceMinor'] as num?)?.toInt() ?? 0,
                ),
                includeInNetWorth: Value(
                  item['includeInNetWorth'] as bool? ?? true,
                ),
                createdAt: _date(item['createdAt'], now),
                updatedAt: _date(item['updatedAt'], now),
                deletedAt: Value(_nullableDate(item['deletedAt'])),
                syncStamp: Value(
                  item['syncStamp'] as String? ?? '0-0-migration',
                ),
              ),
            );
      }
      for (final item in categories) {
        await db
            .into(db.categories)
            .insertOnConflictUpdate(
              CategoriesCompanion.insert(
                id: item['id'] as String,
                name: item['name'] as String,
                kind: Value(item['kind'] as String? ?? 'expense'),
                colorValue: Value(
                  (item['colorValue'] as num?)?.toInt() ?? 0xFF607D8B,
                ),
                iconName: Value(item['iconName'] as String? ?? 'category'),
                legacyId: Value(item['legacyId'] as String?),
                createdAt: _date(item['createdAt'], now),
                updatedAt: _date(item['updatedAt'], now),
                deletedAt: Value(_nullableDate(item['deletedAt'])),
                syncStamp: Value(
                  item['syncStamp'] as String? ?? '0-0-migration',
                ),
              ),
            );
      }
      for (final item in transactions) {
        await db
            .into(db.financeTransactions)
            .insertOnConflictUpdate(
              FinanceTransactionsCompanion.insert(
                id: item['id'] as String,
                kind: item['kind'] as String,
                amountMinor: (item['amountMinor'] as num).toInt(),
                currencyCode: Value(item['currencyCode'] as String? ?? 'EGP'),
                accountId: item['accountId'] as String,
                categoryId: Value(item['categoryId'] as String?),
                merchant: Value(item['merchant'] as String?),
                note: Value(item['note'] as String?),
                tagsJson: Value(jsonEncode(item['tags'] ?? const [])),
                source: Value(item['source'] as String? ?? 'legacy'),
                status: Value(item['status'] as String? ?? 'posted'),
                occurredAt: _date(item['occurredAt'], now),
                createdAt: _date(item['createdAt'], now),
                updatedAt: _date(item['updatedAt'], now),
                deletedAt: Value(_nullableDate(item['deletedAt'])),
                legacyId: Value(item['legacyId'] as String?),
                legacyTransferId: Value(item['legacyTransferId'] as String?),
                syncStamp: Value(
                  item['syncStamp'] as String? ?? '0-0-migration',
                ),
              ),
            );
      }
      await db
          .into(db.migrationRuns)
          .insertOnConflictUpdate(
            MigrationRunsCompanion.insert(
              id: 'legacy-baseline-v1',
              sourceFingerprint: fingerprint,
              importedCount: transactions.length,
              reportJson: jsonEncode(baseline['report'] ?? const {}),
              completedAt: now,
            ),
          );
    });
  }

  static DateTime _date(Object? value, DateTime fallback) =>
      _nullableDate(value) ?? fallback;

  static DateTime? _nullableDate(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toUtc() : null;
}

enum _ApplyOutcome { applied, conflict, ignored }

class _HeaderClient extends http.BaseClient {
  _HeaderClient(this.headers);

  final Map<String, String> headers;
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(headers);
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}
