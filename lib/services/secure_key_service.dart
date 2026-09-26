import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureKeyService {
  SecureKeyService([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _openAiKey = 'openai_api_key';
  final FlutterSecureStorage _storage;

  Future<String?> readOpenAiKey() => _storage.read(key: _openAiKey);

  Future<void> saveOpenAiKey(String value) async {
    final trimmed = value.trim();
    if (!trimmed.startsWith('sk-') || trimmed.length < 20) {
      throw const FormatException('This does not look like an OpenAI API key.');
    }
    await _storage.write(key: _openAiKey, value: trimmed);
  }

  Future<void> removeOpenAiKey() => _storage.delete(key: _openAiKey);
}
