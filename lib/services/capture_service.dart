import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../core/money.dart';
import '../data/database/app_database.dart';
import '../data/repositories/finance_repository.dart';

class CaptureService {
  CaptureService(this.db, this.repository);

  static const _channel = MethodChannel('net.floosy.app/capture');

  final AppDatabase db;
  final FinanceRepository repository;
  final AudioRecorder _recorder = AudioRecorder();

  Future<String> startRecording() async {
    if (!await _recorder.hasPermission()) {
      throw StateError('Microphone permission was not granted.');
    }
    final directory = await getTemporaryDirectory();
    final path =
        '${directory.path}/floosy-${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: path,
    );
    return path;
  }

  Future<String?> stopRecording() => _recorder.stop();

  Future<int> ingestPlatformCaptures() async {
    if (!Platform.isAndroid && !Platform.isIOS) return 0;
    if (Platform.isAndroid) {
      var permission = await Permission.sms.status;
      if (!permission.isGranted) permission = await Permission.sms.request();
      if (!permission.isGranted) return 0;
    }
    final messages = await _channel.invokeListMethod<Map<dynamic, dynamic>>(
      'consumePendingSms',
    );
    var count = 0;
    for (final message in messages ?? const []) {
      final body = message['body'] as String? ?? '';
      final sender = message['sender'] as String?;
      final fingerprint = message['fingerprint'] as String?;
      final parsed = Platform.isAndroid ? _parseBankSms(body) : null;
      final duplicate = fingerprint == null
          ? null
          : await (db.select(db.financeTransactions)
                  ..where((row) => row.sourceFingerprint.equals(fingerprint)))
                .getSingleOrNull();
      if (parsed != null && duplicate == null) {
        try {
          await repository.createTransaction(
            CreateTransactionInput(
              kind: parsed.$1,
              amountMinor: parsed.$2,
              currencyCode: parsed.$3,
              accountId: 'account-cash',
              categoryId: parsed.$1 == 'income'
                  ? 'category-income'
                  : 'category-other',
              merchant: sender,
              note: body,
              source: 'sms',
              sourceFingerprint: fingerprint,
              occurredAt: DateTime.now(),
            ),
          );
        } catch (_) {
          // A uniqueness race means another ingestion already stored the SMS.
        }
      } else if (duplicate == null) {
        await db.queueCapture(
          source: Platform.isAndroid ? 'sms' : 'shortcut',
          payload: body,
          sender: sender,
          fingerprint: fingerprint,
        );
      }
      count++;
    }
    return count;
  }

  (String, int, String)? _parseBankSms(String original) {
    const arabicDigits = '٠١٢٣٤٥٦٧٨٩';
    var body = original.toLowerCase();
    for (var index = 0; index < arabicDigits.length; index++) {
      body = body.replaceAll(arabicDigits[index], '$index');
    }
    final amountPattern = RegExp(
      r'(?:(egp|le|جنيه)\s*([0-9,]+(?:\.[0-9]{1,2})?)|([0-9,]+(?:\.[0-9]{1,2})?)\s*(egp|le|جنيه))',
      caseSensitive: false,
    );
    final matches = amountPattern.allMatches(body).toList();
    if (matches.length != 1) return null;
    final value = matches.single.group(2) ?? matches.single.group(3);
    if (value == null) return null;
    final income = RegExp(
      r'credited|deposit|received|refund|ايداع|إيداع|تم اضافة|تم إضافة',
    ).hasMatch(body);
    final expense = RegExp(
      r'debited|purchase|payment|withdraw|used|خصم|شراء|دفع|سحب',
    ).hasMatch(body);
    if (income == expense) return null;
    return (income ? 'income' : 'expense', Money.parseMinor(value), 'EGP');
  }

  Future<void> dispose() => _recorder.dispose();
}
