// lib/service/polygon_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

// 검색 결과를 담을 모델
class PolygonTickerResult {
  final String ticker;
  final String name;
  final String market;
  final String locale;
  final String primaryExchange;
  final String type;
  final bool active;
  final String? currencyName;
  final String? cik;
  final String? compositeFigi;
  final String? shareClassFigi;

  PolygonTickerResult({
    required this.ticker,
    required this.name,
    required this.market,
    required this.locale,
    required this.primaryExchange,
    required this.type,
    required this.active,
    this.currencyName,
    this.cik,
    this.compositeFigi,
    this.shareClassFigi,
  });

  factory PolygonTickerResult.fromJson(Map<String, dynamic> json) {
    return PolygonTickerResult(
      ticker: json['ticker'] ?? '',
      name: json['name'] ?? '',
      market: json['market'] ?? '',
      locale: json['locale'] ?? '',
      primaryExchange: json['primary_exchange'] ?? '',
      type: json['type'] ?? '',
      active: json['active'] ?? false,
      currencyName: json['currency_name'],
      cik: json['cik'],
      compositeFigi: json['composite_figi'],
      shareClassFigi: json['share_class_figi'],
    );
  }
}

// 주식 현재가 정보를 담을 모델
class PolygonQuote {
  final String ticker;
  final double price;
  final double changeAmount;
  final double changePercent;
  final int volume;
  final DateTime timestamp;
  final double? open;
  final double? high;
  final double? low;
  final double? previousClose;

  PolygonQuote({
    required this.ticker,
    required this.price,
    required this.changeAmount,
    required this.changePercent,
    required this.volume,
    required this.timestamp,
    this.open,
    this.high,
    this.low,
    this.previousClose,
  });

  factory PolygonQuote.fromJson(String ticker, Map<String, dynamic> json) {
    Map<String, dynamic> data;
    if (json['results'] is List && (json['results'] as List).isNotEmpty) {
      data = (json['results'] as List)[0];
    } else if (json['results'] is Map) {
      data = json['results'];
    } else {
      data = json;
    }

    return PolygonQuote(
      ticker: ticker,
      price: (data['c'] ?? data['close'] ?? 0.0).toDouble(),
      changeAmount: ((data['c'] ?? 0.0) - (data['pc'] ?? data['previous_close'] ?? 0.0)).toDouble(),
      changePercent: data['dp'] ?? 0.0,
      volume: (data['v'] ?? data['volume'] ?? 0).toInt(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (data['t'] ?? data['timestamp'] ?? DateTime.now().millisecondsSinceEpoch).toInt(),
      ),
      open: data['o']?.toDouble() ?? data['open']?.toDouble(),
      high: data['h']?.toDouble() ?? data['high']?.toDouble(),
      low: data['l']?.toDouble() ?? data['low']?.toDouble(),
      previousClose: data['pc']?.toDouble() ?? data['previous_close']?.toDouble(),
    );
  }
}

class PolygonService {
  final String _apiKey = 'Ux5z14pBDU0mmhi86wdUve1BU7qOIGAd';
  final String _baseUrl = 'https://api.polygon.io';

  // HTTP 설정
  Map<String, String> get _headers => {
    'Authorization': 'Bearer $_apiKey',
    'User-Agent': 'StockRebalanceApp/1.0',
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  // 종목 검색
  Future<List<PolygonTickerResult>> searchStocks(String query) async {
    if (query.trim().isEmpty || query.length < 1) {
      return [];
    }

    // 검색어 정리
    final cleanQuery = query.trim().replaceAll(RegExp(r'[^\w\s]'), '');

    try {
      final url = Uri.parse(
          '$_baseUrl/v3/reference/tickers?search=$cleanQuery&market=stocks&active=true&limit=20&apikey=$_apiKey');

      print('Polygon API 요청 URL: $url');

      final response = await http.get(url, headers: _headers).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('요청 시간이 초과되었습니다. 네트워크 연결을 확인해주세요.');
        },
      );

      print('Polygon API 응답 상태 코드: ${response.statusCode}');
      print('Polygon API 응답 바디: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data.containsKey('error')) {
          throw Exception('API 오류: ${data['error']}');
        }

        if (data.containsKey('message') && data['message'].toString().contains('limit')) {
          print('Polygon API 호출 제한: ${data['message']}');
          throw Exception('API 호출 제한에 도달했습니다. 잠시 후 다시 시도해주세요.');
        }

        if (!data.containsKey('results') || data['results'] == null) {
          print('results 키가 없습니다. 응답 데이터: $data');
          return [];
        }

        final List<dynamic> results = data['results'] as List<dynamic>? ?? [];

        if (results.isEmpty) {
          return [];
        }

        return results
            .map((item) {
          try {
            return PolygonTickerResult.fromJson(item);
          } catch (e) {
            print('개별 항목 파싱 오류: $e, 데이터: $item');
            return null;
          }
        })
            .where((stock) => stock != null)
            .cast<PolygonTickerResult>()
            .where((stock) =>
        stock.market.toLowerCase() == 'stocks' &&
            stock.locale.toLowerCase() == 'us' &&
            stock.active)
            .toList();
      } else if (response.statusCode == 401) {
        throw Exception('API 키가 유효하지 않음');
      } else if (response.statusCode == 429) {
        throw Exception('API 호출 제한에 도달');
      } else {
        throw Exception('HTTP 오류: ${response.statusCode} - ${response.reasonPhrase}');
      }
    } on FormatException catch (e) {
      print('JSON 파싱 오류: $e');
      throw Exception('서버 응답을 처리 불가');
    } catch (e, stackTrace) {
      print('에러 타입: ${e.runtimeType}');
      print('에러 메시지: ${e.toString()}');
      print('스택 트레이스: $stackTrace');

      if (e.toString().contains('SocketException') ||
          e.toString().contains('HandshakeException')) {
        throw Exception('네트워크 연결을 확인');
      } else if (e.toString().contains('TimeoutException')) {
        throw Exception('요청 시간이 초과');
      } else {
        rethrow;
      }
    }
  }

  // 주식 현재가
  Future<PolygonQuote?> getStockQuote(String symbol) async {
    if (symbol.trim().isEmpty) {
      return null;
    }

    final cleanSymbol = symbol.trim().toUpperCase();

    try {
      final url = Uri.parse(
          '$_baseUrl/v2/aggs/ticker/$cleanSymbol/prev?adjusted=true&apikey=$_apiKey');

      print('Polygon 현재가 API 요청: $url');

      final response = await http.get(url, headers: _headers).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('현재가 조회 시간이 초과');
        },
      );

      print('Polygon 현재가 응답: ${response.statusCode} - ${response.body}'); // 디버깅용

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data.containsKey('error')) {
          throw Exception('API 오류: ${data['error']}');
        }

        if (data.containsKey('message') && data['message'].toString().contains('limit')) {
          print('Polygon API 호출 제한: ${data['message']}');
          throw Exception('API 호출 제한에 도달');
        }

        if (data.containsKey('results') && data['results'] != null) {
          final results = data['results'];
          if (results is List && results.isNotEmpty) {
            return PolygonQuote.fromJson(cleanSymbol, {'results': results[0]});
          } else if (results is Map) {
            return PolygonQuote.fromJson(cleanSymbol, {'results': results});
          }
        }

        print('현재가 데이터가 없음: $data');
        return null;
      } else if (response.statusCode == 401) {
        throw Exception('API 키가 유효하지 않음');
      } else if (response.statusCode == 429) {
        throw Exception('API 호출 제한에 도달');
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      print('Polygon 현재가 조회 오류: $e');
      return null; //오류시 null 값 반환
    }
  }

  // API 상태 확인
  Future<bool> testApiConnection() async {
    try {
      final url = Uri.parse(
          '$_baseUrl/v3/reference/tickers?search=AAPL&market=stocks&active=true&limit=1&apikey=$_apiKey');

      final response = await http.get(url, headers: _headers).timeout(
        const Duration(seconds: 5),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return !data.containsKey('error') && data.containsKey('results');
      }
      return false;
    } catch (e) {
      print('Polygon API 연결 테스트 실패: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> fetchStockData(String symbol) async {
    try {
      final quote = await getStockQuote(symbol);
      if (quote != null) {
        return {
          'symbol': quote.ticker,
          'name': symbol,
          'currentPrice': quote.price,
          'previousClose': quote.previousClose ?? quote.price,
          'changePercent': quote.changePercent.toStringAsFixed(2) + '%',
          'change': quote.changeAmount,
          'volume': quote.volume,
          'open': quote.open,
          'high': quote.high,
          'low': quote.low,
        };
      }
      return {'currentPrice': 0.0, 'name': symbol, 'error': 'No data found'};
    } catch (e) {
      return {'currentPrice': 0.0, 'name': symbol, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>?> getDailyBars(String symbol, {String? date}) async {
    final cleanSymbol = symbol.trim().toUpperCase();
    final targetDate = date ?? _getYesterdayDate();

    try {
      final url = Uri.parse(
          '$_baseUrl/v1/open-close/$cleanSymbol/$targetDate?adjusted=true&apikey=$_apiKey');

      final response = await http.get(url, headers: _headers).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (!data.containsKey('error')) {
          return data;
        }
      }
      return null;
    } catch (e) {
      print('Polygon 일별 데이터 조회 오류: $e');
      return null;
    }
  }

  String _getYesterdayDate() {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
  }
}