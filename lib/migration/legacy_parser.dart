import 'dart:convert';

import 'package:crypto/crypto.dart';

class LegacyParseResult {
  const LegacyParseResult({required this.baseline, required this.report});

  final Map<String, Object?> baseline;
  final Map<String, Object?> report;
}

List<Object?> decodeConcatenatedJson(String source) {
  final documents = <Object?>[];
  var start = -1;
  var depth = 0;
  var inString = false;
  var escaped = false;
  for (var index = 0; index < source.length; index++) {
    final char = source[index];
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (char == r'\') {
        escaped = true;
      } else if (char == '"') {
        inString = false;
      }
      continue;
    }
    if (char == '"') {
      inString = true;
      continue;
    }
    if (char == '{' || char == '[') {
      if (depth == 0) start = index;
      depth++;
    } else if (char == '}' || char == ']') {
      depth--;
      if (depth == 0 && start >= 0) {
        documents.add(jsonDecode(source.substring(start, index + 1)));
        start = -1;
      }
      if (depth < 0) throw const FormatException('Unexpected closing bracket.');
    }
  }
  if (depth != 0 || inString) {
    throw const FormatException('The legacy export ends inside a JSON value.');
  }
  return documents;
}

LegacyParseResult buildLegacyBaseline(
  String source, {
  bool requireKnownDataset = true,
}) {
  final roots = decodeConcatenatedJson(source);
  final documents = <String, Map<String, dynamic>>{};

  void walk(Object? value) {
    if (value is List) {
      for (final item in value) {
        walk(item);
      }
      return;
    }
    if (value is! Map) {
      return;
    }
    final map = value.cast<String, dynamic>();
    final model = map['reservedModelType'];
    final id = map['_id'];
    if (model is String && id is String) {
      final previous = documents[id];
      final currentDate = _date(map['reservedUpdatedAt']);
      final previousDate = _date(previous?['reservedUpdatedAt']);
      if (previous == null ||
          currentDate != null &&
              (previousDate == null || currentDate.isAfter(previousDate))) {
        documents[id] = map;
      }
      return;
    }
    for (final item in map.values) {
      walk(item);
    }
  }

  for (final root in roots) {
    walk(root);
  }

  final sourceFingerprint = sha256.convert(utf8.encode(source)).toString();
  final currencyCodes = <String, String>{};
  for (final item in documents.values) {
    if (item['reservedModelType'] == 'Currency') {
      currencyCodes[item['_id'] as String] = item['code'] as String? ?? 'EGP';
    }
  }

  final accounts = documents.values
      .where((item) => item['reservedModelType'] == 'Account')
      .map(
        (item) => <String, Object?>{
          'id': item['_id'],
          'name': item['name'] ?? 'Account',
          'type': _accountType(item['accountType']),
          'currencyCode': currencyCodes[item['currencyId']] ?? 'EGP',
          'initialBalanceMinor': _minor(
            item,
            'decimalInitAmount',
            'initAmount',
          ),
          'includeInNetWorth': item['excludeFromStats'] != true,
          'createdAt': _iso(item['reservedCreatedAt']),
          'updatedAt': _iso(item['reservedUpdatedAt']),
          'deletedAt': _iso(item['deletedAt']),
          'syncStamp': '0-0-migration',
        },
      )
      .toList();

  final categories = documents.values
      .where((item) => item['reservedModelType'] == 'Category')
      .map(
        (item) => <String, Object?>{
          'id': item['_id'],
          'legacyId': item['_id'],
          'name': item['name'] ?? 'Unknown',
          'kind': 'both',
          'colorValue': _color(item['color']),
          'iconName': item['iconName'] ?? item['icon'] ?? 'category',
          'createdAt': _iso(item['reservedCreatedAt']),
          'updatedAt': _iso(item['reservedUpdatedAt']),
          'deletedAt': _iso(item['deletedAt']),
          'syncStamp': '0-0-migration',
        },
      )
      .toList();

  final records = documents.values
      .where((item) => item['reservedModelType'] == 'Record')
      .map(
        (item) => <String, Object?>{
          'id': item['_id'],
          'legacyId': item['_id'],
          'kind': item['type'] == 0 ? 'income' : 'expense',
          'amountMinor': _minor(item, 'decimalAmount', 'amount').abs(),
          'currencyCode': currencyCodes[item['currencyId']] ?? 'EGP',
          'accountId': item['accountId'],
          'categoryId': item['categoryId'],
          'merchant': item['payee'],
          'note': item['note'],
          'tags': (item['labels'] as List?)?.cast<Object?>() ?? const [],
          'source': 'legacy',
          'status': item['recordState'] == 0 ? 'pending' : 'posted',
          'occurredAt':
              _iso(item['recordDate']) ?? _iso(item['reservedCreatedAt']),
          'createdAt': _iso(item['reservedCreatedAt']),
          'updatedAt': _iso(item['reservedUpdatedAt']),
          'deletedAt': _iso(item['deletedAt']),
          'legacyTransferId': item['transferId']?.toString(),
          'syncStamp': '0-0-migration',
        },
      )
      .toList();

  final activeRecords = records
      .where((item) => item['deletedAt'] == null)
      .toList();
  final activeIncome = activeRecords.where((item) => item['kind'] == 'income');
  final activeExpense = activeRecords.where(
    (item) => item['kind'] == 'expense',
  );
  final report = <String, Object?>{
    'sourceJsonDocuments': roots.length,
    'uniqueDocuments': documents.length,
    'accounts': accounts.length,
    'categories': categories.length,
    'records': records.length,
    'activeRecords': activeRecords.length,
    'deletedRecords': records.length - activeRecords.length,
    'activeIncomeRecords': activeIncome.length,
    'activeExpenseRecords': activeExpense.length,
    'incomeMinor': activeIncome.fold<int>(
      0,
      (total, item) => total + (item['amountMinor']! as int),
    ),
    'expenseMinor': activeExpense.fold<int>(
      0,
      (total, item) => total + (item['amountMinor']! as int),
    ),
    'sourceFingerprint': sourceFingerprint,
    'generatedAt': DateTime.now().toUtc().toIso8601String(),
  };

  if (requireKnownDataset) {
    const expected = {
      'accounts': 1,
      'categories': 74,
      'records': 2436,
      'activeRecords': 2396,
      'deletedRecords': 40,
      'activeIncomeRecords': 154,
      'activeExpenseRecords': 2242,
      'incomeMinor': 138999900,
      'expenseMinor': 147684238,
    };
    for (final entry in expected.entries) {
      if (report[entry.key] != entry.value) {
        throw StateError(
          'Legacy validation failed for ${entry.key}: '
          'expected ${entry.value}, got ${report[entry.key]}.',
        );
      }
    }
  }

  final baseline = <String, Object?>{
    'format': 'floosy-baseline-v1',
    'sourceFingerprint': sourceFingerprint,
    'createdAt': DateTime.now().toUtc().toIso8601String(),
    'accounts': accounts,
    'categories': categories,
    'transactions': records,
    'report': report,
  };
  return LegacyParseResult(baseline: baseline, report: report);
}

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value)?.toUtc() : null;

String? _iso(Object? value) => _date(value)?.toIso8601String();

int _minor(Map<String, dynamic> item, String decimalKey, String integerKey) {
  final decimal = item[decimalKey];
  if (decimal is String) {
    final parsed = double.tryParse(decimal.replaceAll(',', ''));
    if (parsed != null) return (parsed * 100).round();
  }
  if (decimal is num) return (decimal * 100).round();
  return (item[integerKey] as num?)?.round() ?? 0;
}

int _color(Object? value) {
  final text = value?.toString().replaceFirst('#', '') ?? '';
  final parsed = int.tryParse(text, radix: 16) ?? 0x607D8B;
  return text.length <= 6 ? 0xFF000000 | parsed : parsed;
}

String _accountType(Object? value) => switch (value) {
  2 => 'bank',
  3 => 'credit',
  4 => 'wallet',
  _ => 'cash',
};
