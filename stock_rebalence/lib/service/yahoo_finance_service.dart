// lib/service/yahoo_finance_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

//검색 결과
class YahooSearchResult {
  final String symbol;
  final String name;
  final String exchange;
  final String type;

  YahooSearchResult({
    required this.symbol,
    required this.name,
    required this.exchange,
    required this.type,
  });

  factory YahooSearchResult.fromJson(Map<String, dynamic> json) {
    return YahooSearchResult(
      symbol: json['symbol'] ?? '',
      name: json['longname'] ?? json['shortname'] ?? '',
      exchange: json['exchange'] ?? '',
      type: json['typeDisp'] ?? 'EQUITY',
    );
  }
}

//주식 현재가
class YahooQuote {
  final String symbol;
  final double price;
  final double change;
  final double changePercent;
  final double open;
  final double high;
  final double low;
  final double previousClose;
  final int volume;
  final String currency;

  YahooQuote({
    required this.symbol,
    required this.price,
    required this.change,
    required this.changePercent,
    required this.open,
    required this.high,
    required this.low,
    required this.previousClose,
    required this.volume,
    required this.currency,
  });

  factory YahooQuote.fromJson(String symbol, Map<String, dynamic> json) {
    final result = json['result']?[0] ?? {};

    return YahooQuote(
      symbol: symbol,
      price: (result['regularMarketPrice'] ?? 0.0).toDouble(),
      change: (result['regularMarketChange'] ?? 0.0).toDouble(),
      changePercent: (result['regularMarketChangePercent'] ?? 0.0).toDouble(),
      open: (result['regularMarketOpen'] ?? 0.0).toDouble(),
      high: (result['regularMarketDayHigh'] ?? 0.0).toDouble(),
      low: (result['regularMarketDayLow'] ?? 0.0).toDouble(),
      previousClose: (result['regularMarketPreviousClose'] ?? 0.0).toDouble(),
      volume: (result['regularMarketVolume'] ?? 0).toInt(),
      currency: result['currency'] ?? 'USD',
    );
  }
}

class YahooFinanceService {
  final String _baseUrl = 'https://query1.finance.yahoo.com';
  final String _searchUrl = 'https://query2.finance.yahoo.com';

  Map<String, String> get _headers => {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };
  //검색
  Future<List<YahooSearchResult>> searchStocks(String query) async {
    if (query.trim().isEmpty || query.length < 1) {
      return [];
    }

    try {
      final url = Uri.parse(
          '$_searchUrl/v1/finance/search?q=${Uri.encodeComponent(query)}&lang=en-US&region=US&quotesCount=10&newsCount=0');

      print('검색 요청: $url');

      final response = await http.get(url, headers: _headers).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('요청 시간이 초과');
        },
      );

      print('응답 상태: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (!data.containsKey('quotes')) {
          return [];
        }

        final List<dynamic> quotes = data['quotes'] as List<dynamic>? ?? [];

        return quotes
            .map((item) {
          try {
            return YahooSearchResult.fromJson(item);
          } catch (e) {
            print('검색 결과 파싱 오류: $e');
            return null;
          }
        })
            .where((stock) => stock != null)
            .cast<YahooSearchResult>()
            .where((stock) =>
        stock.symbol.isNotEmpty &&
            stock.name.isNotEmpty &&
            (stock.exchange.contains('NAS') ||
                stock.exchange.contains('NYQ') ||
                stock.exchange.contains('NCM')))
            .toList();

      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      print('검색 오류: $e');
      if (e.toString().contains('SocketException')) {
        throw Exception('네트워크 연결 확인');
      } else if (e.toString().contains('TimeoutException')) {
        throw Exception('요청 시간이 초과');
      } else {
        rethrow;
      }
    }
  }

  //현재가 조회
  Future<YahooQuote?> getStockQuote(String symbol) async {
    if (symbol.trim().isEmpty) {
      return null;
    }

    final cleanSymbol = symbol.trim().toUpperCase();

    try {
      final url = Uri.parse(
          '$_baseUrl/v8/finance/chart/$cleanSymbol?interval=1d&range=1d&includePrePost=false');

      print('현재가 요청: $url');

      final response = await http.get(url, headers: _headers).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('현재가 조회 시간 초과');
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data.containsKey('chart') &&
            data['chart']['result'] != null &&
            (data['chart']['result'] as List).isNotEmpty) {

          final result = data['chart']['result'][0];
          final meta = result['meta'];

          if (meta != null) {
            return YahooQuote(
              symbol: cleanSymbol,
              price: (meta['regularMarketPrice'] ?? 0.0).toDouble(),
              change: ((meta['regularMarketPrice'] ?? 0.0) - (meta['previousClose'] ?? 0.0)).toDouble(),
              changePercent: (((meta['regularMarketPrice'] ?? 0.0) - (meta['previousClose'] ?? 0.0)) / (meta['previousClose'] ?? 1.0) * 100).toDouble(),
              open: (meta['regularMarketOpen'] ?? 0.0).toDouble(),
              high: (meta['regularMarketDayHigh'] ?? 0.0).toDouble(),
              low: (meta['regularMarketDayLow'] ?? 0.0).toDouble(),
              previousClose: (meta['previousClose'] ?? 0.0).toDouble(),
              volume: (meta['regularMarketVolume'] ?? 0).toInt(),
              currency: meta['currency'] ?? 'USD',
            );
          }
        }

        print('데이터 없음: $data');
        return null;
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      print('현재가 조회 오류: $e');
      return null; //오류시 null 값 반환
    }
  }

  Future<Map<String, YahooQuote?>> getMultipleQuotes(List<String> symbols) async {
    Map<String, YahooQuote?> results = {};

    if (symbols.isEmpty) return results;

    try {
      final symbolsStr = symbols.map((s) => s.toUpperCase()).join(',');
      final url = Uri.parse(
          '$_baseUrl/v7/finance/quote?symbols=$symbolsStr');

      final response = await http.get(url, headers: _headers).timeout(
        const Duration(seconds: 15),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data.containsKey('quoteResponse') &&
            data['quoteResponse']['result'] != null) {

          final List<dynamic> quotes = data['quoteResponse']['result'];

          for (final quote in quotes) {
            final symbol = quote['symbol'];
            if (symbol != null) {
              results[symbol] = YahooQuote(
                symbol: symbol,
                price: (quote['regularMarketPrice'] ?? 0.0).toDouble(),
                change: (quote['regularMarketChange'] ?? 0.0).toDouble(),
                changePercent: (quote['regularMarketChangePercent'] ?? 0.0).toDouble(),
                open: (quote['regularMarketOpen'] ?? 0.0).toDouble(),
                high: (quote['regularMarketDayHigh'] ?? 0.0).toDouble(),
                low: (quote['regularMarketDayLow'] ?? 0.0).toDouble(),
                previousClose: (quote['regularMarketPreviousClose'] ?? 0.0).toDouble(),
                volume: (quote['regularMarketVolume'] ?? 0).toInt(),
                currency: quote['currency'] ?? 'USD',
              );
            }
          }
        }
      }
    } catch (e) {
      print('Yahoo Finance 일괄 조회 오류: $e');
    }

    for (final symbol in symbols) {
      if (!results.containsKey(symbol.toUpperCase())) {
        results[symbol.toUpperCase()] = null;
      }
    }

    return results;
  }

  Future<bool> testApiConnection() async {
    try {
      final quote = await getStockQuote('AAPL');
      return quote != null;
    } catch (e) {
      print('Yahoo Finance API 연결 테스트 실패: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> fetchStockData(String symbol) async {
    try {
      final quote = await getStockQuote(symbol);
      if (quote != null) {
        return {
          'symbol': quote.symbol,
          'name': symbol,
          'currentPrice': quote.price,
          'previousClose': quote.previousClose,
          'changePercent': '${quote.changePercent.toStringAsFixed(2)}%',
          'change': quote.change,
          'volume': quote.volume,
          'open': quote.open,
          'high': quote.high,
          'low': quote.low,
          'currency': quote.currency,
        };
      }
      return {'currentPrice': 0.0, 'name': symbol, 'error': 'No data found'};
    } catch (e) {
      return {'currentPrice': 0.0, 'name': symbol, 'error': e.toString()};
    }
  }

  Future<List<YahooSearchResult>> getTrendingStocks() async {
    try {
      final trendingSymbols = ['AAPL', 'MSFT', 'GOOGL', 'AMZN', 'TSLA', 'META', 'NVDA', 'NFLX'];
      List<YahooSearchResult> results = [];

      for (final symbol in trendingSymbols) {
        final quote = await getStockQuote(symbol);
        if (quote != null) {
          results.add(YahooSearchResult(
            symbol: symbol,
            name: _getCompanyName(symbol),
            exchange: 'NASDAQ',
            type: 'EQUITY',
          ));
        }
      }

      return results;
    } catch (e) {
      print('인기 종목 조회 오류: $e');
      return [];
    }
  }

  String _getCompanyName(String symbol) {
    final Map<String, String> names = {
      'AAPL': 'Apple Inc.',
      'MSFT': 'Microsoft Corporation',
      'GOOGL': 'Alphabet Inc.',
      'AMZN': 'Amazon.com Inc.',
      'TSLA': 'Tesla Inc.',
      'META': 'Meta Platforms Inc.',
      'NVDA': 'NVIDIA Corporation',
      'NFLX': 'Netflix Inc.',
    };
    return names[symbol] ?? symbol;
  }
}