import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../data/database/app_database.dart';

const _uuid = Uuid();

class MarketDataService {
  MarketDataService(this.db, [Dio? dio]) : _dio = dio ?? Dio();

  final AppDatabase db;
  final Dio _dio;

  Future<double> exchangeRate({
    required String base,
    required String quote,
    bool refresh = false,
  }) async {
    if (base == quote) return 1;
    final symbol = '$base/$quote';
    final cached = await _cached(symbol, maxAge: const Duration(hours: 12));
    if (!refresh && cached != null) return cached.rate;
    try {
      final response = await _dio.get<List<dynamic>>(
        'https://api.frankfurter.dev/v2/rates',
        queryParameters: {'base': base, 'quotes': quote},
      );
      final rate = ((response.data?.first as Map)['rate'] as num).toDouble();
      await _save(symbol, base, quote, rate, 'frankfurter.dev');
      return rate;
    } catch (_) {
      final anyCache = await _cached(symbol);
      if (anyCache != null) return anyCache.rate;
      rethrow;
    }
  }

  Future<double> goldOunceUsd({bool refresh = false}) async {
    const symbol = 'XAU/USD';
    final cached = await _cached(symbol, maxAge: const Duration(hours: 6));
    if (!refresh && cached != null) return cached.rate;
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'https://api.gold-api.com/price/XAU',
      );
      final rate = (response.data?['price'] as num).toDouble();
      await _save(symbol, 'XAU', 'USD', rate, 'gold-api.com');
      return rate;
    } catch (_) {
      final anyCache = await _cached(symbol);
      if (anyCache != null) return anyCache.rate;
      rethrow;
    }
  }

  Future<MarketQuote?> _cached(String symbol, {Duration? maxAge}) async {
    final query = db.select(db.marketQuotes)
      ..where((row) => row.symbol.equals(symbol))
      ..orderBy([(row) => OrderingTerm.desc(row.fetchedAt)])
      ..limit(1);
    final quote = await query.getSingleOrNull();
    if (quote == null) return null;
    if (maxAge != null &&
        DateTime.now().toUtc().difference(quote.fetchedAt) > maxAge) {
      return null;
    }
    return quote;
  }

  Future<void> _save(
    String symbol,
    String base,
    String quote,
    double rate,
    String source,
  ) {
    return db
        .into(db.marketQuotes)
        .insert(
          MarketQuotesCompanion.insert(
            id: _uuid.v7(),
            symbol: symbol,
            baseCurrency: base,
            quoteCurrency: quote,
            rate: rate,
            source: source,
            fetchedAt: DateTime.now().toUtc(),
          ),
        );
  }
}
