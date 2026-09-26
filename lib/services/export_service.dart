import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../core/money.dart';
import '../data/database/app_database.dart';

class ExportService {
  ExportService(this.db);

  final AppDatabase db;

  Future<File> createCsv() async {
    final rows = await db.transactionExportRows();
    final values = <List<Object?>>[
      const [
        'Date',
        'Kind',
        'Amount',
        'Currency',
        'Merchant',
        'Note',
        'Account ID',
        'Category ID',
        'Source',
      ],
      ...rows.map(
        (row) => [
          row['occurredAt'],
          row['kind'],
          (row['amountMinor'] as int) / 100,
          row['currencyCode'],
          row['merchant'],
          row['note'],
          row['accountId'],
          row['categoryId'],
          row['source'],
        ],
      ),
    ];
    return _write(
      'floosy-transactions.csv',
      const ListToCsvConverter().convert(values),
    );
  }

  Future<File> createJsonBackup() async {
    final snapshot = {
      'format': 'floosy-backup-v1',
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'transactions': await db.transactionExportRows(),
      'accounts': (await db.select(db.accounts).get())
          .map((row) => row.toJson())
          .toList(),
      'categories': (await db.select(db.categories).get())
          .map((row) => row.toJson())
          .toList(),
    };
    return _write(
      'floosy-backup.json',
      const JsonEncoder.withIndent('  ').convert(snapshot),
    );
  }

  Future<File> createPdfSummary() async {
    final summary = await db.dashboardSnapshot();
    final recent = await db.watchRecentTransactions(limit: 20).first;
    final currency = summary['currency']! as String;
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        build: (_) => [
          pw.Text('Floosy monthly summary', style: pw.TextStyle(fontSize: 24)),
          pw.SizedBox(height: 16),
          pw.Text(
            'Balance: ${Money(summary['balanceMinor']! as int, currency).format()}',
          ),
          pw.Text(
            'Income: ${Money(summary['incomeMinor']! as int, currency).format()}',
          ),
          pw.Text(
            'Expenses: ${Money(summary['expenseMinor']! as int, currency).format()}',
          ),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: const ['Date', 'Type', 'Description', 'Amount'],
            data: recent
                .map(
                  (row) => [
                    row.occurredAt.toLocal().toString().split(' ').first,
                    row.kind,
                    row.merchant ?? row.note ?? '—',
                    Money(row.amountMinor, row.currencyCode).format(),
                  ],
                )
                .toList(),
          ),
        ],
      ),
    );
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/floosy-summary.pdf');
    await file.writeAsBytes(await document.save(), flush: true);
    return file;
  }

  Future<void> share(File file) {
    return SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], title: 'Floosy export'),
    );
  }

  Future<File> _write(String name, String content) async {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$name');
    await file.writeAsString(content, flush: true);
    return file;
  }
}
