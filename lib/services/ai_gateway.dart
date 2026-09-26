class ExtractedTransaction {
  const ExtractedTransaction({
    required this.kind,
    required this.amount,
    required this.currencyCode,
    required this.description,
    required this.reviewReasons,
    this.occurredAt,
    this.merchant,
    this.categoryHint,
    this.accountHint,
    this.tags = const [],
  });

  final String kind;
  final double amount;
  final String currencyCode;
  final String description;
  final DateTime? occurredAt;
  final String? merchant;
  final String? categoryHint;
  final String? accountHint;
  final List<String> tags;
  final List<String> reviewReasons;

  factory ExtractedTransaction.fromJson(Map<String, Object?> json) {
    return ExtractedTransaction(
      kind: json['kind']! as String,
      amount: (json['amount']! as num).toDouble(),
      currencyCode: json['currency_code']! as String,
      description: json['description']! as String,
      occurredAt: json['occurred_at'] == null
          ? null
          : DateTime.tryParse(json['occurred_at']! as String)?.toUtc(),
      merchant: json['merchant'] as String?,
      categoryHint: json['category_hint'] as String?,
      accountHint: json['account_hint'] as String?,
      tags: (json['tags']! as List).cast<String>(),
      reviewReasons: (json['review_reasons']! as List).cast<String>(),
    );
  }
}

abstract interface class AiGateway {
  Future<List<ExtractedTransaction>> extractTransactions({
    required String input,
    required String source,
    required String locale,
    required List<String> categoryNames,
    required List<String> accountNames,
  });

  Future<String> transcribe(String filePath);

  Future<String> answer({
    required String question,
    required Map<String, Object?> financialContext,
    required String locale,
  });

  Future<bool> validateKey();
}

class MissingApiKeyException implements Exception {
  const MissingApiKeyException();

  @override
  String toString() => 'OpenAI API key is not configured.';
}
