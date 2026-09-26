import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/database/app_database.dart';
import 'data/repositories/finance_repository.dart';
import 'services/ai_gateway.dart';
import 'services/capture_service.dart';
import 'services/export_service.dart';
import 'services/google_drive_sync_service.dart';
import 'services/market_data_service.dart';
import 'services/notification_service.dart';
import 'services/openai_service.dart';
import 'services/secure_key_service.dart';
import 'services/widget_service.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final financeRepositoryProvider = Provider<FinanceRepository>(
  (ref) => DriftFinanceRepository(ref.watch(databaseProvider)),
);
final secureKeyProvider = Provider((ref) => SecureKeyService());
final aiGatewayProvider = Provider<AiGateway>(
  (ref) => OpenAiService(ref.watch(secureKeyProvider)),
);
final driveSyncProvider = Provider(
  (ref) => GoogleDriveSyncService(ref.watch(databaseProvider)),
);
final exportServiceProvider = Provider(
  (ref) => ExportService(ref.watch(databaseProvider)),
);
final marketDataProvider = Provider(
  (ref) => MarketDataService(ref.watch(databaseProvider)),
);
final notificationServiceProvider = Provider(
  (ref) => NotificationService(ref.watch(databaseProvider)),
);
final widgetServiceProvider = Provider(
  (ref) => WidgetService(ref.watch(databaseProvider)),
);
final captureServiceProvider = Provider((ref) {
  final service = CaptureService(
    ref.watch(databaseProvider),
    ref.watch(financeRepositoryProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

final transactionsProvider = StreamProvider(
  (ref) => ref.watch(financeRepositoryProvider).watchTransactions(),
);
final accountsProvider = StreamProvider(
  (ref) => ref.watch(financeRepositoryProvider).watchAccounts(),
);
final categoriesProvider = StreamProvider(
  (ref) => ref.watch(financeRepositoryProvider).watchCategories(),
);
final budgetsProvider = StreamProvider(
  (ref) => ref.watch(financeRepositoryProvider).watchBudgets(),
);
final installmentsProvider = StreamProvider(
  (ref) => ref.watch(financeRepositoryProvider).watchInstallments(),
);
final assetsProvider = StreamProvider(
  (ref) => ref.watch(financeRepositoryProvider).watchAssets(),
);
final pendingCapturesProvider = StreamProvider(
  (ref) => ref.watch(financeRepositoryProvider).watchPendingCaptures(),
);
