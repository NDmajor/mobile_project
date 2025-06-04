// lib/services/alpha_vantage_service.dart
import 'dart:convert';
import 'package:alpha_vantage_api/alpha_vantage_api.dart' as alpha_api;
import 'package:stock_rebalence/models/stock_holding.dart'; // StockHolding 모델 필요 시

// Alpha Vantage 검색 결과를 담을 모델
class AlphaStockSearchResult {
  final String symbol;
  final String name;
  final String region;
  final String currency;

  AlphaStockSearchResult({
    required this.symbol,
    required this.name,
    required this.region,
    required this.currency,
  });

  // Alpha Vantage API의 SYMBOL_SEARCH 응답 구조에 맞춰 수정
  factory AlphaStockSearchResult.fromMap(Map<String, dynamic> map) {
    return AlphaStockSearchResult(
      symbol: map['1. symbol'] ?? '',
      name: map['2. name'] ?? '',
      region: map['4. region'] ?? '',
      currency: map['8. currency'] ?? '',
    );
  }
}

class AlphaVantageService {
  final String _apiKey = '3LBPRW67CKY5RG2Y';
  late final alpha_api.AlphaVantageAPI _alphaVantageAPI;

  AlphaVantageService() {
    _alphaVantageAPI = alpha_api.AlphaVantageAPI(apiKey: _apiKey);
  }

  // 종목 검색 (Symbol Search)
  Future<List<AlphaStockSearchResult>> searchStocks(String keywords) async {
    if (keywords.isEmpty) {
      return [];
    }
    try {
      final response = await _alphaVantageAPI.symbolSearch(keywords); // 패키지에서 제공하는 함수 호출

      // 패키지의 응답 타입과 구조를 확인해야 합니다.
      // 아래는 일반적인 Map<String, dynamic> 리스트를 가정하고 처리하는 예시입니다.
      // 실제 패키지가 SearchResult 객체 리스트를 반환한다면, 그에 맞게 수정해야 합니다.
      if (response is Map<String, dynamic> && response.containsKey('bestMatches')) {
        final List<dynamic> bestMatches = response['bestMatches'];
        return bestMatches
            .map((item) => AlphaStockSearchResult.fromMap(item as Map<String, dynamic>))
            .where((stock) => stock.region.toLowerCase().contains("united states") && stock.currency == "USD") // 미국 주식, USD 통화 필터링 (예시)
            .toList();
      } else if (response is Map<String, dynamic> && response.containsKey('Note')) {
        print('Alpha Vantage API Note (Symbol Search): ${response['Note']}');
        // API 호출 빈도 제한에 걸렸을 수 있습니다. 사용자에게 알리거나 재시도 로직을 고려하세요.
        return [];
      }
      print('Unexpected response format from Alpha Vantage symbol search: $response');
      return [];
    } catch (e) {
      print('Error searching stocks (Alpha Vantage): $e');
      return []; // 오류 발생 시 빈 리스트 반환
    }
  }

  // 주식 현재가 및 정보 가져오기 (Global Quote)
  Future<Map<String, dynamic>> fetchStockData(String symbol) async {
    if (symbol.isEmpty) {
      return {'currentPrice': 0.0, 'name': symbol, 'error': 'Symbol is empty'};
    }
    try {
      final response = await _alphaVantageAPI.globalQuote(symbol); // 패키지 함수 호출

      // 패키지의 응답 타입과 구조 확인 필요
      // 아래는 Map<String, dynamic> 형태의 응답을 가정
      if (response is Map<String, dynamic> && response.containsKey('Global Quote')) {
        final Map<String, dynamic> globalQuote = response['Global Quote'];
        if (globalQuote.isNotEmpty) {
          return {
            'symbol': globalQuote['01. symbol'] ?? symbol,
            'name': symbol, // GLOBAL_QUOTE는 종목명을 주지 않으므로, 검색 시 가져온 이름을 사용하거나 symbol로 대체
            'currentPrice': double.tryParse(globalQuote['05. price'] ?? '0.0') ?? 0.0,
            'previousClose': double.tryParse(globalQuote['08. previous close'] ?? '0.0') ?? 0.0,
            'changePercent': globalQuote['10. change percent'] ?? '0.00%',
          };
        }
      } else if (response is Map<String, dynamic> && response.containsKey('Note')) {
        print('Alpha Vantage API Note (Global Quote for $symbol): ${response['Note']}');
        return {'currentPrice': 0.0, 'name': symbol, 'error': response['Note']};
      }
      print('Unexpected response format or empty quote for $symbol: $response');
      return {'currentPrice': 0.0, 'name': symbol, 'error': 'No quote data found'};
    } catch (e) {
      print('Error fetching stock data (Alpha Vantage for $symbol): $e');
      return {'currentPrice': 0.0, 'name': symbol, 'error': 'Exception occurred'};
    }
  }
}