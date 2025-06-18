// lib/pages/my_assets_page.dart
import 'package:flutter/material.dart';
import 'package:stock_rebalence/models/asset.dart';
import 'package:stock_rebalence/service/asset_repository.dart';
import 'package:stock_rebalence/service/yahoo_finance_service.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class MyAssetsPage extends StatefulWidget {
  const MyAssetsPage({super.key});

  @override
  State<MyAssetsPage> createState() => _MyAssetsPageState();
}

class _MyAssetsPageState extends State<MyAssetsPage> with TickerProviderStateMixin {
  late TabController _tabController;
  final AssetRepository _assetRepository = AssetRepository();
  final YahooFinanceService _yahooService = YahooFinanceService();

  List<Asset> _allAssets = [];
  Map<String, dynamic> _statistics = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this); // 전체, 주식, 현금, 채권, 금
    _loadAssets();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAssets() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _allAssets = await _assetRepository.getAssets();
      _statistics = await _assetRepository.getAssetStatistics();

      await _updateStockPricesWithYahoo();
    } catch (e) {
      print('자산 로딩 오류: $e');
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateStockPricesWithYahoo() async {
    final stockAssets = _allAssets.where((asset) => asset.type == AssetType.stock).cast<StockAsset>().toList();

    if (stockAssets.isEmpty) return;

    try {
      List<String> symbols = stockAssets.map((stock) => stock.symbol).toList();
      Map<String, YahooQuote?> quotes = await _yahooService.getMultipleQuotes(symbols);

      for (var stockAsset in stockAssets) {
        final quote = quotes[stockAsset.symbol.toUpperCase()];
        if (quote != null) {
          stockAsset.currentPrice = quote.price;
          print('${stockAsset.symbol} 현재가 업데이트: ${quote.price}');
        } else {
          print('${stockAsset.symbol} 현재가 조회 실패');
        }
      }

      await _assetRepository.saveAssets(_allAssets);
      _statistics = await _assetRepository.getAssetStatistics();

    } catch (e) {
      print('가격 업데이트 실패: $e');

      for (var stockAsset in stockAssets) {
        try {
          final quote = await _yahooService.getStockQuote(stockAsset.symbol);
          if (quote != null) {
            stockAsset.currentPrice = quote.price;
          }
          await Future.delayed(const Duration(milliseconds: 200)); // 혹시몰라 딜딜딜딜레이
        } catch (e) {
          print('${stockAsset.symbol} 개별 가격 업데이트 실패: $e');
        }
      }

      await _assetRepository.saveAssets(_allAssets);
      _statistics = await _assetRepository.getAssetStatistics();
    }
  }

  List<Asset> _getFilteredAssets(int tabIndex) {
    switch (tabIndex) {
      case 0: return _allAssets;
      case 1: return _allAssets.where((a) => a.type == AssetType.stock).toList();
      case 2: return _allAssets.where((a) => a.type == AssetType.cash).toList();
      case 3: return _allAssets.where((a) => a.type == AssetType.bond).toList();
      case 4: return _allAssets.where((a) => a.type == AssetType.gold).toList();
      default: return _allAssets;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final cardBackgroundColor = isDarkMode ? Colors.grey[850] : Colors.white;
    final textColor = isDarkMode ? Colors.white70 : Colors.black87;
    final titleColor = isDarkMode ? Colors.white : Colors.black;

    return Scaffold(
      appBar: AppBar(
        title: Text('나의 자산', style: TextStyle(color: titleColor)),
        backgroundColor: cardBackgroundColor,
        elevation: 1,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: titleColor),
            onPressed: _loadAssets,
            tooltip: '새로고침',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'export':

                  break;
                case 'settings':

                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'export', child: Text('자산 내보내기')),
              const PopupMenuItem(value: 'settings', child: Text('설정')),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadAssets,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildSummaryCard(theme, cardBackgroundColor, textColor, titleColor),
            const SizedBox(height: 24),
            _buildAssetDistributionChart(theme, cardBackgroundColor, textColor, titleColor),
            const SizedBox(height: 24),
            _buildTabBar(theme, cardBackgroundColor, textColor, titleColor),
            const SizedBox(height: 16),
            _buildAssetList(),
            const SizedBox(height: 100),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'my_assets_fab_tag',
        onPressed: _showAddAssetBottomSheet,
        tooltip: '자산 추가',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSummaryCard(ThemeData theme, Color? cardColor, Color? textColor, Color? titleColor) {
    final totalAmount = _statistics['totalCurrentAmount'] ?? 0.0;
    final totalProfitLoss = _statistics['totalProfitLoss'] ?? 0.0;
    final profitLossRate = _statistics['totalProfitLossRate'] ?? 0.0;

    return Card(
      color: cardColor,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '총 자산',
                  style: theme.textTheme.titleMedium?.copyWith(color: textColor),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${totalAmount.toStringAsFixed(2)}',
              style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: titleColor
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('총 평가손익', style: theme.textTheme.bodySmall?.copyWith(color: textColor)),
                    Text(
                      '${totalProfitLoss >= 0 ? '+' : ''}${totalProfitLoss.toStringAsFixed(2)}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: totalProfitLoss >= 0 ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('수익률', style: theme.textTheme.bodySmall?.copyWith(color: textColor)),
                    Text(
                      '${profitLossRate >= 0 ? '+' : ''}${profitLossRate.toStringAsFixed(2)}%',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: profitLossRate >= 0 ? Colors.green : Colors.red,
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
                _buildStatItem('보유 종목', '${_allAssets.length}개', theme, textColor, titleColor),
                _buildStatItem('자산 유형', '${(_statistics['assetTypeCount'] as Map? ?? {}).length}개', theme, textColor, titleColor),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, ThemeData theme, Color? textColor, Color? titleColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(color: textColor),
        ),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            color: titleColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildAssetDistributionChart(ThemeData theme, Color? cardColor, Color? textColor, Color? titleColor) {
    final distribution = _statistics['assetTypeDistribution'] as Map<AssetType, double>? ?? {};

    if (distribution.isEmpty) {
      return const SizedBox.shrink();
    }

    final chartData = distribution.entries
        .map((entry) => _ChartData(
        entry.key.displayName,
        entry.value,
        _getAssetTypeColor(entry.key)))
        .toList();

    return Card(
      color: cardColor,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '포트폴리오 현황',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: SfCircularChart(
                legend: Legend(
                  isVisible: true,
                  position: LegendPosition.right,
                  overflowMode: LegendItemOverflowMode.wrap,
                  textStyle: TextStyle(color: textColor),
                ),
                series: <CircularSeries>[
                  PieSeries<_ChartData, String>(
                    dataSource: chartData,
                    xValueMapper: (_ChartData data, _) => data.category,
                    yValueMapper: (_ChartData data, _) => data.value,
                    pointColorMapper: (_ChartData data, _) => data.color,
                    dataLabelMapper: (_ChartData data, _) =>
                    '${(data.value / (_statistics['totalCurrentAmount'] ?? 1) * 100).toStringAsFixed(1)}%',
                    dataLabelSettings: const DataLabelSettings(
                      isVisible: true,
                      textStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
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

  Widget _buildTabBar(ThemeData theme, Color? cardColor, Color? textColor, Color? titleColor) {
    return Card(
      color: cardColor,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(child: Text('전체')),
            Tab(child: Text('주식')),
            Tab(child: Text('현금')),
            Tab(child: Text('채권')),
            Tab(child: Text('금')),
          ],
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: textColor,
          indicatorColor: theme.colorScheme.primary,
          dividerColor: Colors.transparent,
        ),
      ),
    );
  }

  Widget _buildAssetList() {
    return SizedBox(
      height: 400,
      child: TabBarView(
        controller: _tabController,
        children: [
          _buildAssetListView(0), // 전체
          _buildAssetListView(1), // 주식
          _buildAssetListView(2), // 현금
          _buildAssetListView(3), // 채권
          _buildAssetListView(4), // 금
        ],
      ),
    );
  }

  Widget _buildAssetListView(int tabIndex) {
    final assets = _getFilteredAssets(tabIndex);
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final cardBackgroundColor = isDarkMode ? Colors.grey[850] : Colors.white;
    final textColor = isDarkMode ? Colors.white70 : Colors.black87;
    final titleColor = isDarkMode ? Colors.white : Colors.black;

    if (assets.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _getTabIcon(tabIndex),
                size: 64,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              Text(
                '${_getTabName(tabIndex)} 자산이 없습니다.',
                style: theme.textTheme.titleMedium?.copyWith(color: textColor),
              ),
              const SizedBox(height: 8),
              Text(
                '+ 버튼을 눌러 자산을 추가',
                style: theme.textTheme.bodyMedium?.copyWith(color: textColor),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: assets.length,
      itemBuilder: (context, index) {
        return _buildAssetCard(assets[index], cardBackgroundColor, textColor, titleColor);
      },
    );
  }

  Widget _buildAssetCard(Asset asset, Color? cardColor, Color? textColor, Color? titleColor) {
    final theme = Theme.of(context);
    final profitLoss = asset.profitLoss;
    final profitLossRate = asset.profitLossRate;

    return Card(
      color: cardColor,
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showAssetDetail(asset),
        onLongPress: () => _showAssetOptions(asset),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _getAssetTypeColor(asset.type).withOpacity(0.2),
                    child: Icon(
                      _getAssetIcon(asset.type),
                      color: _getAssetTypeColor(asset.type),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                asset.name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: titleColor,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          _getAssetSubtitle(asset),
                          style: theme.textTheme.bodySmall?.copyWith(color: textColor),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${asset.currentPrice.toStringAsFixed(2)}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: titleColor,
                        ),
                      ),
                      if (asset.type != AssetType.cash)
                        Text(
                          '${profitLoss >= 0 ? '+' : ''}${profitLoss.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: profitLoss >= 0 ? Colors.green : Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '보유: ${asset.quantity.toStringAsFixed(asset.type == AssetType.cash ? 2 : 0)}${_getQuantityUnit(asset.type)}',
                    style: theme.textTheme.bodySmall?.copyWith(color: textColor),
                  ),
                  Text(
                    '평가금액: ${asset.evaluationAmount.toStringAsFixed(2)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: titleColor,
                    ),
                  ),
                ],
              ),
              if (asset.type != AssetType.cash) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '매수가: ${asset.purchasePrice.toStringAsFixed(2)}',
                      style: theme.textTheme.bodySmall?.copyWith(color: textColor),
                    ),
                    Text(
                      '수익률: ${profitLossRate >= 0 ? '+' : ''}${profitLossRate.toStringAsFixed(2)}%',
                      style: TextStyle(
                        fontSize: 12,
                        color: profitLossRate >= 0 ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
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

  String _getAssetSubtitle(Asset asset) {
    switch (asset.type) {
      case AssetType.stock:
        final stockAsset = asset as StockAsset;
        return '${stockAsset.symbol} • ${stockAsset.exchange}';
      case AssetType.cash:
        final cashAsset = asset as CashAsset;
        return '${cashAsset.accountType} • ${cashAsset.currency}';
      case AssetType.bond:
        final bondAsset = asset as BondAsset;
        return '${bondAsset.issuer} • ${bondAsset.interestRate.toStringAsFixed(2)}%';
      case AssetType.gold:
        final goldAsset = asset as GoldAsset;
        return '${goldAsset.unit} • ${goldAsset.storageLocation}';
    }
  }

  String _getQuantityUnit(AssetType type) {
    switch (type) {
      case AssetType.stock:
        return '주';
      case AssetType.cash:
        return '';
      case AssetType.bond:
        return '계약';
      case AssetType.gold:
        return '온스';
    }
  }

  IconData _getTabIcon(int tabIndex) {
    switch (tabIndex) {
      case 0: return Icons.account_balance_wallet;
      case 1: return Icons.trending_up;
      case 2: return Icons.attach_money;
      case 3: return Icons.receipt_long;
      case 4: return Icons.stars;
      default: return Icons.account_balance_wallet;
    }
  }

  String _getTabName(int tabIndex) {
    switch (tabIndex) {
      case 0: return '전체';
      case 1: return '주식';
      case 2: return '현금';
      case 3: return '채권';
      case 4: return '금';
      default: return '전체';
    }
  }

  void _showAssetDetail(Asset asset) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(asset.name),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('자산 유형', asset.type.displayName),
              _buildDetailRow('보유 수량', '${asset.quantity.toStringAsFixed(2)}${_getQuantityUnit(asset.type)}'),
              if (asset.type != AssetType.cash) ...[
                _buildDetailRow('매수가', '${asset.purchasePrice.toStringAsFixed(2)}'),
                _buildDetailRow('현재가', '${asset.currentPrice.toStringAsFixed(2)}'),
                _buildDetailRow('평가손익', '${asset.profitLoss >= 0 ? '+' : ''}${asset.profitLoss.toStringAsFixed(2)}'),
                _buildDetailRow('수익률', '${asset.profitLossRate >= 0 ? '+' : ''}${asset.profitLossRate.toStringAsFixed(2)}%'),
              ],
              _buildDetailRow('평가금액', '${asset.evaluationAmount.toStringAsFixed(2)}'),
              _buildDetailRow('매수일', '${asset.purchaseDate.year}-${asset.purchaseDate.month.toString().padLeft(2, '0')}-${asset.purchaseDate.day.toString().padLeft(2, '0')}'),
              ..._buildAssetSpecificDetails(asset),
              if (asset.type == AssetType.stock) ...[
                const Divider(),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('닫기'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showAssetOptions(asset);
            },
            child: const Text('관리'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value),
        ],
      ),
    );
  }

  List<Widget> _buildAssetSpecificDetails(Asset asset) {
    switch (asset.type) {
      case AssetType.stock:
        final stockAsset = asset as StockAsset;
        return [
          _buildDetailRow('종목 코드', stockAsset.symbol),
          _buildDetailRow('거래소', stockAsset.exchange),
        ];
      case AssetType.cash:
        final cashAsset = asset as CashAsset;
        return [
          _buildDetailRow('통화', cashAsset.currency),
          _buildDetailRow('계좌 유형', cashAsset.accountType),
        ];
      case AssetType.bond:
        final bondAsset = asset as BondAsset;
        return [
          _buildDetailRow('발행기관', bondAsset.issuer),
          _buildDetailRow('금리', '${bondAsset.interestRate.toStringAsFixed(2)}%'),
          _buildDetailRow('만기일', '${bondAsset.maturityDate.year}-${bondAsset.maturityDate.month.toString().padLeft(2, '0')}-${bondAsset.maturityDate.day.toString().padLeft(2, '0')}'),
        ];
      case AssetType.gold:
        final goldAsset = asset as GoldAsset;
        return [
          _buildDetailRow('단위', goldAsset.unit),
          _buildDetailRow('보관 장소', goldAsset.storageLocation),
        ];
    }
  }

  void _showAssetOptions(Asset asset) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${asset.name} 관리',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.sell, color: Colors.orange),
              title: const Text('일부 판매'),
              subtitle: const Text('보유 수량의 일부를 판매'),
              onTap: () {
                Navigator.pop(context);
                _showSellAssetDialog(asset);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.blue),
              title: const Text('정보 수정'),
              subtitle: const Text('자산 정보를 수정'),
              onTap: () {
                Navigator.pop(context);
                _showEditAssetDialog(asset);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('완전 삭제'),
              subtitle: const Text('이 자산을 완전히 삭제'),
              onTap: () {
                Navigator.pop(context);
                _showDeleteAssetDialog(asset);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showSellAssetDialog(Asset asset) {
    final quantityController = TextEditingController();
    final priceController = TextEditingController(text: asset.currentPrice.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${asset.name} 일부 판매'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('현재 보유: ${asset.quantity.toStringAsFixed(2)}${_getQuantityUnit(asset.type)}'),
            const SizedBox(height: 16),
            TextField(
              controller: quantityController,
              decoration: InputDecoration(
                labelText: '판매 수량',
                suffixText: _getQuantityUnit(asset.type),
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            if (asset.type != AssetType.cash)
              TextField(
                controller: priceController,
                decoration: const InputDecoration(
                  labelText: '판매가',
                  prefixText: ' ',
                  border: OutlineInputBorder(),
                  helperText: '현재가 기준',
                ),
                keyboardType: TextInputType.number,
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              final quantity = double.tryParse(quantityController.text) ?? 0;
              final price = double.tryParse(priceController.text) ?? asset.currentPrice;

              if (quantity > 0 && quantity <= asset.quantity) {
                await _assetRepository.sellAsset(asset.id, quantity, price);
                Navigator.of(context).pop();
                _loadAssets();

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${asset.name} ${quantity.toStringAsFixed(2)}${_getQuantityUnit(asset.type)} 판매 완료')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('올바른 수량을 입력하세요')),
                );
              }
            },
            child: const Text('판매'),
          ),
        ],
      ),
    );
  }

  void _showEditAssetDialog(Asset asset) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('자산 정보 수정 기능은 개발 중입니다')),
    );
  }

  void _showDeleteAssetDialog(Asset asset) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('자산 삭제'),
        content: Text('${asset.name}을(를) 완전히 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await _assetRepository.deleteAsset(asset.id);
              Navigator.of(context).pop();
              _loadAssets();

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${asset.name}이(가) 삭제되었습니다')),
              );
            },
            child: const Text('삭제', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddAssetBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: DraggableScrollableSheet(
          expand: false,
          builder: (context, scrollController) => SingleChildScrollView(
            controller: scrollController,
            child: Container(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(
                        '자산 추가',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                    ],
                  ),
                  const SizedBox(height: 20),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildAssetTypeCard(AssetType.stock, Icons.trending_up, Colors.blue),
                      _buildAssetTypeCard(AssetType.cash, Icons.attach_money, Colors.green),
                      _buildAssetTypeCard(AssetType.bond, Icons.receipt_long, Colors.orange),
                      _buildAssetTypeCard(AssetType.gold, Icons.stars, Colors.amber),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAssetTypeCard(AssetType type, IconData icon, Color color) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.pop(context);
          _showAddAssetForm(type);
        },
        child: Container(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 12),
              Text(
                type.displayName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddAssetForm(AssetType type) {
    if (type == AssetType.stock) {
      Navigator.pushNamed(context, '/add_stock').then((result) {
        if (result == true) {
          _loadAssets();
        }
      });
    } else {
      _showNonStockAssetForm(type);
    }
  }

  void _showNonStockAssetForm(AssetType type) {
    final nameController = TextEditingController();
    final quantityController = TextEditingController();
    final priceController = TextEditingController();
    final additionalController1 = TextEditingController();
    final additionalController2 = TextEditingController();
    final additionalController3 = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${type.displayName} 추가'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: '${type.displayName} 이름',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: quantityController,
                decoration: InputDecoration(
                  labelText: '수량',
                  suffixText: _getQuantityUnit(type),
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              if (type != AssetType.cash)
                TextField(
                  controller: priceController,
                  decoration: const InputDecoration(
                    labelText: '매수가',
                    prefixText: ' ',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              const SizedBox(height: 16),
              ..._buildAdditionalFields(type, additionalController1, additionalController2, additionalController3),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final quantity = double.tryParse(quantityController.text) ?? 0;
              final price = type == AssetType.cash ? 1.0 : (double.tryParse(priceController.text) ?? 0);

              if (name.isNotEmpty && quantity > 0 && price > 0) {
                final asset = _createAsset(type, name, quantity, price, additionalController1, additionalController2, additionalController3);
                await _assetRepository.addAsset(asset);
                Navigator.of(context).pop();
                _loadAssets();

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${type.displayName} 추가 완료')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('모든 필드를 올바르게 입력해주세요')),
                );
              }
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildAdditionalFields(AssetType type, TextEditingController controller1, TextEditingController controller2, TextEditingController controller3) {
    switch (type) {
      case AssetType.cash:
        return [
          TextField(
            controller: controller1,
            decoration: const InputDecoration(
              labelText: '통화 (예: USD, KRW)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller2,
            decoration: const InputDecoration(
              labelText: '계좌 유형 (예: 예금, 적금)',
              border: OutlineInputBorder(),
            ),
          ),
        ];
      case AssetType.bond:
        return [
          TextField(
            controller: controller1,
            decoration: const InputDecoration(
              labelText: '발행기관',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller2,
            decoration: const InputDecoration(
              labelText: '금리 (%)',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller3,
            decoration: const InputDecoration(
              labelText: '만기일 (YYYY-MM-DD)',
              border: OutlineInputBorder(),
            ),
          ),
        ];
      case AssetType.gold:
        return [
          TextField(
            controller: controller1,
            decoration: const InputDecoration(
              labelText: '단위 (예: 그램, 온스)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller2,
            decoration: const InputDecoration(
              labelText: '보관 장소',
              border: OutlineInputBorder(),
            ),
          ),
        ];
      default:
        return [];
    }
  }

  Asset _createAsset(AssetType type, String name, double quantity, double price, TextEditingController controller1, TextEditingController controller2, TextEditingController controller3) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final now = DateTime.now();

    switch (type) {
      case AssetType.cash:
        return CashAsset(
          id: id,
          name: name,
          quantity: quantity,
          purchaseDate: now,
          currency: controller1.text.isEmpty ? 'USD' : controller1.text,
          accountType: controller2.text.isEmpty ? '예금' : controller2.text,
        );
      case AssetType.bond:
        return BondAsset(
          id: id,
          name: name,
          quantity: quantity,
          purchasePrice: price,
          purchaseDate: now,
          currentPrice: price,
          issuer: controller1.text,
          interestRate: double.tryParse(controller2.text) ?? 0.0,
          maturityDate: DateTime.tryParse(controller3.text) ?? now.add(const Duration(days: 365)),
        );
      case AssetType.gold:
        return GoldAsset(
          id: id,
          name: name,
          quantity: quantity,
          purchasePrice: price,
          purchaseDate: now,
          currentPrice: price,
          unit: controller1.text.isEmpty ? '온스' : controller1.text,
          storageLocation: controller2.text.isEmpty ? '은행 금고' : controller2.text,
        );
      default:
        throw UnsupportedError('지원하지 않는 자산 유형입니다');
    }
  }
}

// 차트 데이터 클래스
class _ChartData {
  _ChartData(this.category, this.value, this.color);
  final String category;
  final double value;
  final Color color;
}