// lib/services/stock_repository.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stock_rebalence/models/stock_holding.dart';

class StockRepository {
  static const String _holdingsKey = 'stock_holdings';

  Future<void> saveHoldings(List<StockHolding> holdings) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> holdingsJson =
    holdings.map((h) => jsonEncode(h.toJson())).toList();
    await prefs.setStringList(_holdingsKey, holdingsJson);
  }

  Future<List<StockHolding>> getHoldings() async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? holdingsJson = prefs.getStringList(_holdingsKey);
    if (holdingsJson == null) {
      return []; // 저장된 데이터가 없으면 빈 리스트 반환
    }
    return holdingsJson
        .map((hJson) => StockHolding.fromJson(jsonDecode(hJson)))
        .toList();
  }

  // 특정 종목 삭제 기능 (필요 시)
  Future<void> deleteHolding(String symbol) async {
    List<StockHolding> holdings = await getHoldings();
    holdings.removeWhere((holding) => holding.symbol == symbol);
    await saveHoldings(holdings);
  }

  // 모든 종목 삭제 기능 (필요 시)
  Future<void> clearAllHoldings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_holdingsKey);
  }
}