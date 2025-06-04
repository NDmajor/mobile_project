// lib/service/alpha_vantage_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

// Alpha Vantage 검색 결과를 담을 모델
class AlphaStockSearchResult {
  final String symbol;
  final String name;
  final String type;
  final String region;
  final String marketOpen;
  final String marketClose;
  final String timezone;
  final String currency;
  final String matchScore;

  AlphaStockSearchResult({
    required this.symbol,
    required this.name,
    required this.type,
    required this.region,
    required this.marketOpen,
    required this.marketClose,
    required this.timezone,
    required this.currency,
    required this.matchScore,
  });

  factory AlphaStockSearchResult.fromJson(Map<String, dynamic> json) {
    return AlphaStockSearchResult(
      symbol: json['1. symbol'] ?? '',
      name: json['2. name'] ?? '',
      type: json['3. type'] ?? '',
      region: json['4. region'] ?? '',
      marketOpen: json['5. marketOpen'] ?? '',
      marketClose: json['6. marketClose'] ?? '',
      timezone: json['7. timezone'] ?? '',
      currency: json['8. currency'] ?? '',
      matchScore: json['9. matchScore'] ?? '',
    );
  }
}

// 주식 현재가 정보를 담을 모델
class StockQuote {
  final String symbol;
  final double open;
  final double high;
  final double low;
  final double price;
  final int volume;
  final String latestTradingDay;
  final double previousClose;
  final double change;
  final String changePercent;

  StockQuote({
    required this.symbol,
    required this.open,
    required this.high,
    required this.low,
    required this.price,
    required this.volume,
    required this.latestTradingDay,
    required this.previousClose,
    required this.change,
    required this.changePercent,
  });

  factory StockQuote.fromJson(Map<String, dynamic> json) {
    return StockQuote(
      symbol: json['01. symbol'] ?? '',
      open: double.tryParse(json['02. open'] ?? '0') ?? 0.0,
      high: double.tryParse(json['03. high'] ?? '0') ?? 0.0,
      low: double.tryParse(json['04. low'] ?? '0') ?? 0.0,
      price: double.tryParse(json['05. price'] ?? '0') ?? 0.0,
      volume: int.tryParse(json['06. volume'] ?? '0') ?? 0,
      latestTradingDay: json['07. latest trading day'] ?? '',
      previousClose: double.tryParse(json['08. previous close'] ?? '0') ?? 0.0,
      change: double.tryParse(json['09. change'] ?? '0') ?? 0.0,
      changePercent: json['10. change percent'] ?? '0.00%',
    );
  }
}

class AlphaVantageService {
  final String _apiKey = '3LBPRW67CKY5RG2Y';
  final String _baseUrl = 'https://www.alphavantage.co/query';

  // 종목 검색 (Symbol Search)
  Future<List<AlphaStockSearchResult>> searchStocks(String keywords) async {
    if (keywords.isEmpty) {
      return [];
    }

    try {
      final url = Uri.parse(
          '$_baseUrl?function=SYMBOL_SEARCH&keywords=$keywords&apikey=$_apiKey');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        // API 제한 메시지 확인
        if (data.containsKey('Note')) {
          print('Alpha Vantage API Note: ${data['Note']}');
          throw Exception('API 호출 제한: ${data['Note']}');
        }

        if (data.containsKey('bestMatches')) {
          final List<dynamic> bestMatches = data['bestMatches'];
          return bestMatches
              .map((item) => AlphaStockSearchResult.fromJson(item))
              .where((stock) =>
          stock.region.toLowerCase().contains('united states') ||
              stock.currency == 'USD')
              .toList();
        }
      }

      throw Exception('검색 결과를 가져올 수 없습니다.');
    } catch (e, stackTrace) {
      print('===== Original Error in AlphaVantageService =====');
      print('Error Type: ${e.runtimeType}');
      print('Error Message: ${e.toString()}');
      print('Stack Trace: $stackTrace');
      print('=================================================');
      throw Exception('검색 결과를 가져올 수 없습니다.');
    }
  }

  // 주식 현재가 가져오기 (Global Quote)
  Future<StockQuote?> getStockQuote(String symbol) async {
    if (symbol.isEmpty) {
      return null;
    }

    try {
      final url = Uri.parse(
          '$_baseUrl?function=GLOBAL_QUOTE&symbol=$symbol&apikey=$_apiKey');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        // API 제한 메시지 확인
        if (data.containsKey('Note')) {
          print('Alpha Vantage API Note: ${data['Note']}');
          throw Exception('API 호출 제한: ${data['Note']}');
        }

        if (data.containsKey('Global Quote')) {
          final Map<String, dynamic> globalQuote = data['Global Quote'];
          if (globalQuote.isNotEmpty) {
            return StockQuote.fromJson(globalQuote);
          }
        }
      }

      return null;
    } catch (e) {
      print('주식 현재가 조회 오류: $e');
      rethrow;
    }
  }

  // 여러 종목의 현재가를 한번에 업데이트 (기존 코드와의 호환성을 위해)
  Future<Map<String, dynamic>> fetchStockData(String symbol) async {
    try {
      final quote = await getStockQuote(symbol);
      if (quote != null) {
        return {
          'symbol': quote.symbol,
          'name': symbol, // 종목명은 별도로 저장하거나 검색에서 가져와야 함
          'currentPrice': quote.price,
          'previousClose': quote.previousClose,
          'changePercent': quote.changePercent,
          'change': quote.change,
          'volume': quote.volume,
        };
      }
      return {'currentPrice': 0.0, 'name': symbol, 'error': 'No data found'};
    } catch (e) {
      return {'currentPrice': 0.0, 'name': symbol, 'error': e.toString()};
    }
  }
}