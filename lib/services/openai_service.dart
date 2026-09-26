import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import 'ai_gateway.dart';
import 'secure_key_service.dart';

class OpenAiService implements AiGateway {
  OpenAiService(this._keys, [Dio? dio])
    : _dio = dio ?? Dio(BaseOptions(baseUrl: 'https://api.openai.com/v1'));

  final SecureKeyService _keys;
  final Dio _dio;

  Future<Options> _options({String? contentType}) async {
    final key = await _keys.readOpenAiKey();
    if (key == null || key.isEmpty) throw const MissingApiKeyException();
    return Options(
      headers: {
        HttpHeaders.authorizationHeader: 'Bearer $key',
        HttpHeaders.contentTypeHeader: ?contentType,
      },
    );
  }

  @override
  Future<bool> validateKey() async {
    try {
      await _dio.post<Map<String, Object?>>(
        '/responses',
        options: await _options(contentType: Headers.jsonContentType),
        data: {
          'model': 'gpt-4o-mini',
          'store': false,
          'max_output_tokens': 8,
          'input': 'Reply with OK.',
        },
      );
      return true;
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) return false;
      rethrow;
    }
  }

  @override
  Future<List<ExtractedTransaction>> extractTransactions({
    required String input,
    required String source,
    required String locale,
    required List<String> categoryNames,
    required List<String> accountNames,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final response = await _dio.post<Map<String, Object?>>(
      '/responses',
      options: await _options(contentType: Headers.jsonContentType),
      data: {
        'model': 'gpt-4o-mini',
        'store': false,
        'temperature': 0,
        'input': [
          {
            'role': 'system',
            'content':
                'Extract personal-finance transactions. The input may mix Arabic and English. '
                'Never invent an amount. Resolve relative dates using UTC now=$now. '
                'Use ISO 4217 currency codes, default EGP only when no currency is stated. '
                'Known categories: ${categoryNames.join(', ')}. '
                'Known accounts: ${accountNames.join(', ')}. '
                'Put every uncertainty in review_reasons. Source=$source; locale=$locale.',
          },
          {'role': 'user', 'content': input},
        ],
        'text': {
          'format': {
            'type': 'json_schema',
            'name': 'floosy_transaction_batch',
            'strict': true,
            'schema': {
              'type': 'object',
              'additionalProperties': false,
              'properties': {
                'transactions': {
                  'type': 'array',
                  'items': {
                    'type': 'object',
                    'additionalProperties': false,
                    'properties': {
                      'kind': {
                        'type': 'string',
                        'enum': ['expense', 'income', 'transfer'],
                      },
                      'amount': {'type': 'number'},
                      'currency_code': {'type': 'string'},
                      'description': {'type': 'string'},
                      'occurred_at': {
                        'anyOf': [
                          {'type': 'string'},
                          {'type': 'null'},
                        ],
                      },
                      'merchant': {
                        'anyOf': [
                          {'type': 'string'},
                          {'type': 'null'},
                        ],
                      },
                      'category_hint': {
                        'anyOf': [
                          {'type': 'string'},
                          {'type': 'null'},
                        ],
                      },
                      'account_hint': {
                        'anyOf': [
                          {'type': 'string'},
                          {'type': 'null'},
                        ],
                      },
                      'tags': {
                        'type': 'array',
                        'items': {'type': 'string'},
                      },
                      'review_reasons': {
                        'type': 'array',
                        'items': {'type': 'string'},
                      },
                    },
                    'required': [
                      'kind',
                      'amount',
                      'currency_code',
                      'description',
                      'occurred_at',
                      'merchant',
                      'category_hint',
                      'account_hint',
                      'tags',
                      'review_reasons',
                    ],
                  },
                },
              },
              'required': ['transactions'],
            },
          },
        },
      },
    );
    final decoded =
        jsonDecode(_outputText(response.data!)) as Map<String, Object?>;
    return (decoded['transactions']! as List)
        .cast<Map<String, Object?>>()
        .map(ExtractedTransaction.fromJson)
        .toList(growable: false);
  }

  @override
  Future<String> transcribe(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) throw ArgumentError.value(filePath, 'filePath');
    final form = FormData.fromMap({
      'model': 'gpt-transcribe',
      'file': await MultipartFile.fromFile(filePath),
      'prompt':
          'A personal expense or income note, possibly mixing Egyptian Arabic and English.',
      'keywords[]': ['EGP', 'جنيه', 'مصروف', 'دخل', 'تحويل', 'قسط'],
      'languages[]': ['ar', 'en'],
    });
    final response = await _dio.post<Map<String, Object?>>(
      '/audio/transcriptions',
      data: form,
      options: await _options(contentType: 'multipart/form-data'),
    );
    return response.data?['text'] as String? ?? '';
  }

  @override
  Future<String> answer({
    required String question,
    required Map<String, Object?> financialContext,
    required String locale,
  }) async {
    final response = await _dio.post<Map<String, Object?>>(
      '/responses',
      options: await _options(contentType: Headers.jsonContentType),
      data: {
        'model': 'gpt-4o-mini',
        'store': false,
        'input': [
          {
            'role': 'system',
            'content':
                'You are Floosy, a private personal-finance assistant. Answer only from the '
                'provided computed data. Never claim to be a financial adviser. Be concise. '
                'Answer in ${locale == 'ar' ? 'Arabic' : 'English'}.',
          },
          {
            'role': 'user',
            'content':
                'Question: $question\nComputed data: ${jsonEncode(financialContext)}',
          },
        ],
      },
    );
    return _outputText(response.data!).trim();
  }

  String _outputText(Map<String, Object?> data) {
    final direct = data['output_text'];
    if (direct is String) return direct;
    final output = data['output'];
    if (output is! List) {
      throw const FormatException('OpenAI response has no output.');
    }
    for (final item in output) {
      if (item is! Map) continue;
      final content = item['content'];
      if (content is! List) continue;
      for (final part in content) {
        if (part is Map &&
            part['type'] == 'output_text' &&
            part['text'] is String) {
          return part['text'] as String;
        }
      }
    }
    throw const FormatException('OpenAI response has no text output.');
  }
}
