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
      matchScore: json['9. matchScore'] ?? '0',
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
  // API 키를 환경변수나 별도 설정에서 가져오도록 수정 권장
  final String _apiKey = '3LBPRW67CKY5RG2Y';
  final String _baseUrl = 'https://www.alphavantage.co/query';

  // HTTP 클라이언트 설정
  Map<String, String> get _headers => {
    'User-Agent': 'StockRebalanceApp/1.0',
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  // 종목 검색 (Symbol Search)
  Future<List<AlphaStockSearchResult>> searchStocks(String keywords) async {
    if (keywords.trim().isEmpty || keywords.length < 2) {
      return [];
    }

    // 키워드 정리 (특수문자 제거, 공백 처리)
    final cleanKeywords = keywords.trim().replaceAll(RegExp(r'[^\w\s]'), '');

    try {
      final url = Uri.parse(
          '$_baseUrl?function=SYMBOL_SEARCH&keywords=${Uri.encodeComponent(cleanKeywords)}&apikey=$_apiKey');

      print('API 요청 URL: $url'); // 디버깅용

      final response = await http.get(url, headers: _headers).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('요청 시간이 초과되었습니다. 네트워크 연결을 확인해주세요.');
        },
      );

      print('API 응답 상태 코드: ${response.statusCode}'); // 디버깅용
      print('API 응답 바디: ${response.body}'); // 디버깅용

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        // API 에러 메시지들 확인
        if (data.containsKey('Error Message')) {
          throw Exception('API 오류: ${data['Error Message']}');
        }

        if (data.containsKey('Note')) {
          print('Alpha Vantage API Note: ${data['Note']}');
          throw Exception('API 호출 제한에 도달했습니다. 잠시 후 다시 시도해주세요.');
        }

        if (data.containsKey('Information')) {
          throw Exception('API 제한: ${data['Information']}');
        }

        // 빈 결과 처리
        if (!data.containsKey('bestMatches')) {
          print('bestMatches 키가 없습니다. 응답 데이터: $data');
          return [];
        }

        final List<dynamic> bestMatches = data['bestMatches'];

        if (bestMatches.isEmpty) {
          return [];
        }

        return bestMatches
            .map((item) {
          try {
            return AlphaStockSearchResult.fromJson(item);
          } catch (e) {
            print('개별 항목 파싱 오류: $e, 데이터: $item');
            return null;
          }
        })
            .where((stock) => stock != null)
            .cast<AlphaStockSearchResult>()
            .where((stock) =>
        stock.region.toLowerCase().contains('united states') ||
            stock.currency.toUpperCase() == 'USD' ||
            stock.type.toLowerCase().contains('equity'))
            .toList();
      } else {
        throw Exception('HTTP 오류: ${response.statusCode} - ${response.reasonPhrase}');
      }
    } on FormatException catch (e) {
      print('JSON 파싱 오류: $e');
      throw Exception('서버 응답을 처리할 수 없습니다.');
    } catch (e, stackTrace) {
      print('===== 검색 오류 상세 정보 =====');
      print('에러 타입: ${e.runtimeType}');
      print('에러 메시지: ${e.toString()}');
      print('스택 트레이스: $stackTrace');
      print('================================');

      if (e.toString().contains('SocketException') ||
          e.toString().contains('HandshakeException')) {
        throw Exception('네트워크 연결을 확인해주세요.');
      } else if (e.toString().contains('TimeoutException')) {
        throw Exception('요청 시간이 초과되었습니다.');
      } else {
        rethrow;
      }
    }
  }

  // 주식 현재가 가져오기 (Global Quote)
  Future<StockQuote?> getStockQuote(String symbol) async {
    if (symbol.trim().isEmpty) {
      return null;
    }

    final cleanSymbol = symbol.trim().toUpperCase();

    try {
      final url = Uri.parse(
          '$_baseUrl?function=GLOBAL_QUOTE&symbol=${Uri.encodeComponent(cleanSymbol)}&apikey=$_apiKey');

      print('현재가 API 요청: $url'); // 디버깅용

      final response = await http.get(url, headers: _headers).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('현재가 조회 시간이 초과되었습니다.');
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        // API 에러 메시지들 확인
        if (data.containsKey('Error Message')) {
          throw Exception('API 오류: ${data['Error Message']}');
        }

        if (data.containsKey('Note')) {
          print('Alpha Vantage API Note: ${data['Note']}');
          throw Exception('API 호출 제한에 도달했습니다.');
        }

        if (data.containsKey('Information')) {
          throw Exception('API 제한: ${data['Information']}');
        }

        if (data.containsKey('Global Quote')) {
          final Map<String, dynamic> globalQuote = data['Global Quote'];
          if (globalQuote.isNotEmpty) {
            return StockQuote.fromJson(globalQuote);
          }
        }

        print('현재가 데이터가 없습니다: $data');
        return null;
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      print('주식 현재가 조회 오류: $e');
      rethrow;
    }
  }

  // API 상태 확인 메서드 (테스트용)
  Future<bool> testApiConnection() async {
    try {
      final url = Uri.parse(
          '$_baseUrl?function=SYMBOL_SEARCH&keywords=AAPL&apikey=$_apiKey');

      final response = await http.get(url, headers: _headers).timeout(
        const Duration(seconds: 5),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return !data.containsKey('Error Message') &&
            !data.containsKey('Note') &&
            !data.containsKey('Information');
      }
      return false;
    } catch (e) {
      print('API 연결 테스트 실패: $e');
      return false;
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