// lib/pages/add_stock_page.dart
import 'package:flutter/material.dart';
import 'package:stock_rebalence/models/asset.dart';
import 'package:stock_rebalence/service/asset_repository.dart';
import 'package:stock_rebalence/service/alpha_vantage_service.dart';

class AddStockPage extends StatefulWidget {
  const AddStockPage({super.key});

  @override
  State<AddStockPage> createState() => _AddStockPageState();
}

class _AddStockPageState extends State<AddStockPage> {
  final _formKey = GlobalKey<FormState>();
  final _searchController = TextEditingController();
  final _quantityController = TextEditingController();
  final _purchasePriceController = TextEditingController();

  final AssetRepository _assetRepository = AssetRepository(); // 통합 자산 저장소 사용
  final AlphaVantageService _alphaVantageService = AlphaVantageService();

  List<AlphaStockSearchResult> _searchResults = [];
  AlphaStockSearchResult? _selectedStock;
  bool _isSearching = false;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _searchController.dispose();
    _quantityController.dispose();
    _purchasePriceController.dispose();
    super.dispose();
  }

  Future<void> _searchStocks(String query) async {
    if (query.length < 2) {
      setState(() {
        _searchResults = [];
        _errorMessage = null;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });

    try {
      // API 연결 테스트 (선택사항)
      final isApiWorking = await _alphaVantageService.testApiConnection();
      if (!isApiWorking) {
        throw Exception('API 서버에 연결할 수 없습니다. 나중에 다시 시도해주세요.');
      }

      final results = await _alphaVantageService.searchStocks(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
          if (results.isEmpty) {
            _errorMessage = '검색 결과가 없습니다. 다른 키워드로 검색해보세요.';
          }
        });
      }
    } catch (e, s) {
      if (mounted) {
        print('주식 검색 상세 오류: $e');
        print('StackTrace: $s');

        String userMessage;
        if (e.toString().contains('네트워크')) {
          userMessage = '인터넷 연결을 확인해주세요.';
        } else if (e.toString().contains('API 호출 제한') || e.toString().contains('API 제한')) {
          userMessage = 'API 호출 한도에 도달했습니다. 잠시 후 다시 시도해주세요.';
        } else if (e.toString().contains('시간이 초과')) {
          userMessage = '요청 시간이 초과되었습니다. 다시 시도해주세요.';
        } else {
          userMessage = '검색 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.';
        }

        setState(() {
          _isSearching = false;
          _errorMessage = userMessage;
          _searchResults = [];
        });
      }
    }
  }

  void _selectStock(AlphaStockSearchResult stock) {
    setState(() {
      _selectedStock = stock;
      _searchController.text = '${stock.symbol} - ${stock.name}';
      _searchResults = [];
    });
  }

  Future<void> _saveStock() async {
    if (_formKey.currentState!.validate() && _selectedStock != null) {
      setState(() {
        _isSaving = true;
        _errorMessage = null;
      });

      try {
        final quantity = double.tryParse(_quantityController.text) ?? 0;
        final purchasePrice = double.tryParse(_purchasePriceController.text) ?? 0;

        if (quantity > 0 && purchasePrice > 0) {
          // 현재가 가져오기 (선택사항)
          double currentPrice = purchasePrice; // 기본값은 매수가
          try {
            final quote = await _alphaVantageService.getStockQuote(_selectedStock!.symbol);
            currentPrice = quote?.price ?? purchasePrice;
          } catch (e) {
            print('현재가 조회 실패: $e');
            // 현재가 조회 실패해도 저장은 진행
          }

          // StockAsset 생성
          final newStockAsset = StockAsset(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            symbol: _selectedStock!.symbol,
            name: _selectedStock!.name,
            quantity: quantity,
            purchasePrice: purchasePrice,
            purchaseDate: DateTime.now(),
            currentPrice: currentPrice,
            exchange: 'NASDAQ', // 기본값
          );

          // 중복 종목 체크
          List<Asset> currentAssets = await _assetRepository.getAssets();
          bool isDuplicate = currentAssets.any((asset) =>
          asset.type == AssetType.stock &&
              (asset as StockAsset).symbol.toLowerCase() == newStockAsset.symbol.toLowerCase());

          if (isDuplicate) {
            if (mounted) {
              setState(() {
                _isSaving = false;
                _errorMessage = '이미 보유 중인 종목입니다.';
              });
            }
            return;
          }

          // 통합 자산 저장소에 저장
          await _assetRepository.addAsset(newStockAsset);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${newStockAsset.symbol} (${newStockAsset.name}) 추가됨'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pop(context, true);
          }
        } else {
          setState(() {
            _isSaving = false;
            _errorMessage = '수량과 매수가는 0보다 커야 합니다.';
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isSaving = false;
            _errorMessage = '저장 중 오류가 발생했습니다: ${e.toString()}';
          });
        }
      }
    } else if (_selectedStock == null) {
      setState(() {
        _errorMessage = '종목을 선택해주세요.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('주식 추가'),
        backgroundColor: isDarkMode ? Colors.grey[850] : Colors.white,
        elevation: 1,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: <Widget>[
              // 종목 검색
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '종목 검색',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          labelText: '종목명 또는 심볼 검색 (예: Apple, AAPL)',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _isSearching
                              ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                              : null,
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          if (value.isNotEmpty) {
                            _searchStocks(value);
                          } else {
                            setState(() {
                              _searchResults = [];
                              _selectedStock = null;
                            });
                          }
                        },
                        validator: (value) {
                          if (_selectedStock == null) {
                            return '종목을 선택해주세요.';
                          }
                          return null;
                        },
                      ),

                      // 검색 결과
                      if (_searchResults.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _searchResults.length > 5 ? 5 : _searchResults.length,
                            itemBuilder: (context, index) {
                              final stock = _searchResults[index];
                              return ListTile(
                                dense: true,
                                title: Text(
                                  '${stock.symbol} - ${stock.name}',
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                                subtitle: Text(
                                  '${stock.type} | ${stock.region} | ${stock.currency}',
                                  style: theme.textTheme.bodySmall,
                                ),
                                trailing: Text(
                                  '${(double.tryParse(stock.matchScore) ?? 0 * 100).toStringAsFixed(0)}%',
                                  style: theme.textTheme.bodySmall,
                                ),
                                onTap: () => _selectStock(stock),
                              );
                            },
                          ),
                        ),
                      ],

                      // 선택된 종목 표시
                      if (_selectedStock != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: theme.colorScheme.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '선택된 종목: ${_selectedStock!.symbol}',
                                      style: theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      _selectedStock!.name,
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  setState(() {
                                    _selectedStock = null;
                                    _searchController.clear();
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // 매수 정보 입력
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '매수 정보',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _quantityController,
                        decoration: const InputDecoration(
                          labelText: '보유 수량',
                          suffixText: '주',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '보유 수량을 입력하세요.';
                          }
                          if (double.tryParse(value) == null || double.parse(value) <= 0) {
                            return '유효한 수량을 입력하세요.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _purchasePriceController,
                        decoration: const InputDecoration(
                          labelText: '평균 매수가',
                          prefixText: '\$ ',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '평균 매수가를 입력하세요.';
                          }
                          if (double.tryParse(value) == null || double.parse(value) <= 0) {
                            return '유효한 매수가를 입력하세요.';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // 오류 메시지
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    border: Border.all(color: Colors.red.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // 저장 버튼
              ElevatedButton(
                onPressed: _isSaving ? null : _saveStock,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                ),
                child: _isSaving
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                    : const Text(
                  '포트폴리오에 추가하기',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),

              const SizedBox(height: 16),

              // 도움말
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  border: Border.all(color: Colors.blue.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          '도움말',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• 종목명이나 심볼로 검색할 수 있습니다\n• 미국 주식만 지원됩니다\n• 추가한 주식은 홈과 나의 자산에서 확인 가능합니다',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}