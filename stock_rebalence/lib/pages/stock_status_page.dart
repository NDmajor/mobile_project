// lib/pages/stock_status_page.dart
import 'package:flutter/material.dart';
import 'package:stock_rebalence/models/asset.dart';
import 'package:stock_rebalence/pages/add_stock_page.dart';
import 'package:stock_rebalence/service/asset_repository.dart';
import 'package:stock_rebalence/service/yahoo_finance_service.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class AccountStatusPage extends StatefulWidget {
  const AccountStatusPage({super.key});

  @override
  State<AccountStatusPage> createState() => _AccountStatusPageState();
}

class _AccountStatusPageState extends State<AccountStatusPage> {
  final AssetRepository _assetRepository = AssetRepository();
  final YahooFinanceService _yahooService = YahooFinanceService();

  List<Asset> _allAssets = [];
  List<StockAsset> _stockAssets = [];
  bool _isLoading = true;
  double _totalAssets = 0.0;
  double _totalPurchaseAmount = 0.0;
  double _totalEvaluationAmount = 0.0;
  double _totalProfitLoss = 0.0;
  double _overallProfitLossRate = 0.0;
  double _cashBalance = 0.0;

  List<_PieData> _pieData = [];

  @override
  void initState() {
    super.initState();
    _loadAssets();
  }

  Future<void> _loadAssets() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      _allAssets = await _assetRepository.getAssets();

      _stockAssets = _allAssets
          .where((asset) => asset.type == AssetType.stock)
          .cast<StockAsset>()
          .toList();

      await _updateStockPricesWithYahoo();
      _calculateTotals();
    } catch (e) {
      print('자산 로딩 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('자산 로딩 중 오류가 발생: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _updateStockPricesWithYahoo() async {
    if (_stockAssets.isEmpty) return;

    try {
      List<String> symbols = _stockAssets.map((stock) => stock.symbol).toList();
      Map<String, YahooQuote?> quotes = await _yahooService.getMultipleQuotes(symbols);

      for (var stockAsset in _stockAssets) {
        final quote = quotes[stockAsset.symbol.toUpperCase()];
        if (quote != null) {
          stockAsset.currentPrice = quote.price;
          print('${stockAsset.symbol} 현재가 업데이트: ${quote.price}');
        } else {
          print('${stockAsset.symbol} 현재가 조회 실패');
        }
      }

      await _assetRepository.saveAssets(_allAssets);

    } catch (e) {
      print('가격 업데이트 실패: $e');

      // 개별 조회 fallback
      for (var stockAsset in _stockAssets) {
        try {
          final quote = await _yahooService.getStockQuote(stockAsset.symbol);
          if (quote != null) {
            stockAsset.currentPrice = quote.price;
          } //혹시 몰라 딜레이
          await Future.delayed(const Duration(milliseconds: 200));
        } catch (e) {
          print('${stockAsset.symbol} 개별 가격 업데이트 실패: $e');
        }
      }

      await _assetRepository.saveAssets(_allAssets);
    }
  }

  void _calculateTotals() {
    _totalPurchaseAmount = 0.0;
    _totalEvaluationAmount = 0.0;
    _cashBalance = 0.0;

    for (var asset in _allAssets) {
      if (asset.type == AssetType.cash) {
        _cashBalance += asset.quantity; // 현금은 수량==금액
      } else {
        _totalPurchaseAmount += asset.purchasePrice * asset.quantity;
        _totalEvaluationAmount += asset.currentPrice * asset.quantity;
      }
    }

    _totalProfitLoss = _totalEvaluationAmount - _totalPurchaseAmount;
    _overallProfitLossRate = (_totalPurchaseAmount > 0)
        ? (_totalProfitLoss / _totalPurchaseAmount) * 100
        : 0.0;
    _totalAssets = _totalEvaluationAmount + _cashBalance;

    _updatePieData();
  }

  void _updatePieData() {
    if (_totalAssets <= 0) {
      _pieData = [];
      return;
    }

    _pieData = [];

    if (_cashBalance > 0) {
      _pieData.add(_PieData('현금', _cashBalance, Colors.green));
    }

    Map<AssetType, double> assetTypeAmounts = {};
    Map<AssetType, Color> assetTypeColors = {
      AssetType.stock: Colors.blue,
      AssetType.bond: Colors.orange,
      AssetType.gold: Colors.amber,
    };

    for (var asset in _allAssets) {
      if (asset.type != AssetType.cash) {
        double amount = asset.currentPrice * asset.quantity;
        assetTypeAmounts[asset.type] = (assetTypeAmounts[asset.type] ?? 0.0) + amount;
      }
    }

    assetTypeAmounts.forEach((type, amount) {
      if (amount > 0) {
        _pieData.add(_PieData(
          type.displayName,
          amount,
          assetTypeColors[type] ?? Colors.grey,
        ));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDarkMode = theme.brightness == Brightness.dark;
    final Color? cardBackgroundColor = isDarkMode ? Colors.grey[850] : Colors.white;
    final Color? textColor = isDarkMode ? Colors.white70 : Colors.black87;
    final Color? titleColor = isDarkMode ? Colors.white : Colors.black;

    return Scaffold(
      appBar: AppBar(
        title: Text('나의 투자 현황', style: TextStyle(color: titleColor)),
        backgroundColor: cardBackgroundColor,
        elevation: 1.0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: titleColor),
            onPressed: _isLoading ? null : _loadAssets,
            tooltip: '데이터 새로고침',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAssets,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildAccountSummary(theme, cardBackgroundColor, textColor, titleColor),
            const SizedBox(height: 24),
            _buildPortfolioChart(theme, cardBackgroundColor, textColor, titleColor),
            const SizedBox(height: 24),
            _buildAssetOverview(theme, cardBackgroundColor, textColor, titleColor),
            const SizedBox(height: 24),
            _buildStockHoldingsList(theme, cardBackgroundColor, textColor, titleColor),
            const SizedBox(height: 100), // 여백
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddStockPage()),
          );
          if (result == true && mounted) {
            _loadAssets();
          }
        },
        tooltip: '주식 추가',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildAccountSummary(ThemeData theme, Color? cardColor, Color? textColor, Color? titleColor) {
    return Card(
      color: cardColor,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isLoading
            ? const Center(child: SizedBox(height:150, child: Center(child: CircularProgressIndicator())))
            : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '총 자산',
                  style: theme.textTheme.titleMedium?.copyWith(color: textColor),
                ),
                if (_isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                ,
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${_totalAssets.toStringAsFixed(2)}',
              style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: titleColor),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('투자 원금', style: theme.textTheme.bodySmall?.copyWith(color: textColor)),
                    Text('${_totalPurchaseAmount.toStringAsFixed(2)}', style: theme.textTheme.titleSmall?.copyWith(color: titleColor)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('평가 손익', style: theme.textTheme.bodySmall?.copyWith(color: textColor)),
                    Text(
                      '${_totalProfitLoss >= 0 ? '+' : ''}${_totalProfitLoss.toStringAsFixed(2)} (${_overallProfitLossRate.toStringAsFixed(2)}%)',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: _totalProfitLoss >= 0 ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('현금 잔고', style: theme.textTheme.bodyMedium?.copyWith(color: textColor)),
                Text('${_cashBalance.toStringAsFixed(2)}', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: titleColor)),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildPortfolioChart(ThemeData theme, Color? cardColor, Color? textColor, Color? titleColor) {
    return Card(
      color: cardColor,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('포트폴리오 현황', style: theme.textTheme.titleLarge?.copyWith(color: titleColor)),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: (_isLoading || _pieData.isEmpty)
                  ? Center(child: _isLoading ? const CircularProgressIndicator() : Text('데이터가 없습니다.', style: TextStyle(color: textColor)))
                  : SfCircularChart(
                legend: Legend(isVisible: true, overflowMode: LegendItemOverflowMode.wrap, textStyle: TextStyle(color: textColor)),
                series: <CircularSeries>[
                  PieSeries<_PieData, String>(
                    dataSource: _pieData,
                    xValueMapper: (_PieData data, _) => data.xData,
                    yValueMapper: (_PieData data, _) => data.yData,
                    pointColorMapper: (_PieData data, _) => data.color,
                    dataLabelMapper: (_PieData data, _) => '${(data.yData / _totalAssets * 100).toStringAsFixed(1)}%',
                    dataLabelSettings: const DataLabelSettings(isVisible: true, textStyle: TextStyle(fontSize: 10, color: Colors.black)),
                    enableTooltip: true,
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssetOverview(ThemeData theme, Color? cardColor, Color? textColor, Color? titleColor) {
    Map<AssetType, int> assetCounts = {};
    Map<AssetType, double> assetAmounts = {};

    for (var asset in _allAssets) {
      assetCounts[asset.type] = (assetCounts[asset.type] ?? 0) + 1;
      if (asset.type == AssetType.cash) {
        assetAmounts[asset.type] = (assetAmounts[asset.type] ?? 0.0) + asset.quantity;
      } else {
        assetAmounts[asset.type] = (assetAmounts[asset.type] ?? 0.0) + (asset.currentPrice * asset.quantity);
      }
    }

    return Card(
      color: cardColor,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('자산 현황', style: theme.textTheme.titleLarge?.copyWith(color: titleColor)),
            const SizedBox(height: 16),
            if (assetCounts.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text('보유 자산이 없음', style: theme.textTheme.bodyMedium?.copyWith(color: textColor)),
                ),
              )
            else
              ...AssetType.values.map((type) {
                final count = assetCounts[type] ?? 0;
                final amount = assetAmounts[type] ?? 0.0;
                if (count == 0) return const SizedBox.shrink();

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _getAssetTypeColor(type).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(_getAssetIcon(type), color: _getAssetTypeColor(type)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(type.displayName, style: theme.textTheme.titleMedium?.copyWith(color: titleColor)),
                            Text('$count개 보유', style: theme.textTheme.bodySmall?.copyWith(color: textColor)),
                          ],
                        ),
                      ),
                      Text(
                        '${amount.toStringAsFixed(2)}',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: titleColor),
                      ),
                    ],
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }

  Color _getAssetTypeColor(AssetType type) {
    switch (type) {
      case AssetType.stock:
        return Colors.blue;
      case AssetType.cash:
        return Colors.green;
      case AssetType.bond:
        return Colors.orange;
      case AssetType.gold:
        return Colors.amber;
    }
  }

  IconData _getAssetIcon(AssetType type) {
    switch (type) {
      case AssetType.stock:
        return Icons.trending_up;
      case AssetType.cash:
        return Icons.attach_money;
      case AssetType.bond:
        return Icons.receipt_long;
      case AssetType.gold:
        return Icons.stars;
    }
  }

  Widget _buildStockHoldingsList(ThemeData theme, Color? cardColor, Color? textColor, Color? titleColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('주식 보유 현황', style: theme.textTheme.titleLarge?.copyWith(color: titleColor)),
            if (_stockAssets.isNotEmpty)
              TextButton.icon(
                onPressed: _loadAssets,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('새로고침', style: TextStyle(fontSize: 12)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        _isLoading
            ? const Center(child: Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator()))
            : _stockAssets.isEmpty
            ? Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.trending_up, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text('보유 중인 주식이 없음', style: theme.textTheme.bodyMedium?.copyWith(color: textColor)),
                const SizedBox(height: 8),
                Text('+ 버튼을 눌러 첫 번째 주식을 추가', style: theme.textTheme.bodySmall?.copyWith(color: textColor)),
              ],
            ),
          ),
        )
            : ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _stockAssets.length,
          itemBuilder: (context, index) {
            final stock = _stockAssets[index];
            return Card(
              color: cardColor,
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.withOpacity(0.2),
                  child: Text(
                    stock.symbol.substring(0, stock.symbol.length > 2 ? 2 : stock.symbol.length),
                    style: const TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(
                    stock.name.isNotEmpty ? stock.name : stock.symbol,
                    style: theme.textTheme.titleMedium?.copyWith(color: titleColor)
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        '${stock.quantity.toStringAsFixed(0)}주 × ${stock.purchasePrice.toStringAsFixed(2)}',
                        style: theme.textTheme.bodySmall?.copyWith(color: textColor)
                    ),
                    Text(
                        '평가금액: ${stock.evaluationAmount.toStringAsFixed(2)}',
                        style: theme.textTheme.bodySmall?.copyWith(color: textColor, fontSize: 11)
                    ),
                  ],
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                        '${stock.currentPrice.toStringAsFixed(2)}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: titleColor,
                        )
                    ),
                    Text(
                      '${stock.profitLoss >= 0 ? '+' : ''}${stock.profitLoss.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: stock.profitLoss >= 0 ? Colors.green : Colors.red,
                      ),
                    ),
                    Text(
                      '${stock.profitLossRate.toStringAsFixed(2)}%',
                      style: TextStyle(
                        fontSize: 10,
                        color: stock.profitLoss >= 0 ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
                onTap: () {
                  _showStockDetail(stock);
                },
                onLongPress: () {
                  _showDeleteDialog(stock);
                },
              ),
            );
          },
        ),
      ],
    );
  }

  void _showStockDetail(StockAsset stock) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('${stock.symbol} 상세 정보'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('종목명: ${stock.name.isNotEmpty ? stock.name : stock.symbol}'),
              Text('보유수량: ${stock.quantity.toStringAsFixed(0)}주'),
              Text('평균매수가: ${stock.purchasePrice.toStringAsFixed(2)}'),
              Text('현재가: ${stock.currentPrice.toStringAsFixed(2)} (Yahoo Finance)'),
              Text('평가금액: ${stock.evaluationAmount.toStringAsFixed(2)}'),
              Text('평가손익: ${stock.profitLoss >= 0 ? '+' : ''}${stock.profitLoss.toStringAsFixed(2)}'),
              Text('수익률: ${stock.profitLossRate.toStringAsFixed(2)}%'),
              const SizedBox(height: 8),
              Text('거래소: ${stock.exchange}', style: Theme.of(context).textTheme.bodySmall),
              const Divider(),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('닫기'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteDialog(StockAsset stock) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('종목 삭제'),
          content: Text('${stock.symbol}을(를) 포트폴리오에서 삭제하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _assetRepository.deleteAsset(stock.id);
                _loadAssets();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${stock.symbol}이(가) 삭제되었습니다.')),
                  );
                }
              },
              child: const Text('삭제', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}

class _PieData {
  _PieData(this.xData, this.yData, [this.color = Colors.transparent]);
  final String xData;
  final double yData;
  final Color color;
}