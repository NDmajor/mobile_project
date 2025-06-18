// lib/pages/rebalance_page.dart
import 'package:flutter/material.dart';
import 'package:stock_rebalence/models/asset.dart';
import 'package:stock_rebalence/service/asset_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
//호에엥
class RebalancePage extends StatefulWidget {
  const RebalancePage({super.key});

  @override
  State<RebalancePage> createState() => _RebalancePageState();
}

class _RebalancePageState extends State<RebalancePage> {
  final AssetRepository _assetRepository = AssetRepository();

  List<Asset> _assets = [];
  Map<String, dynamic> _statistics = {};
  bool _isLoading = true;

  // 목표 배분 비율 기본값
  Map<AssetType, double> _targetAllocation = {
    AssetType.stock: 60.0,
    AssetType.bond: 30.0,
    AssetType.cash: 5.0,
    AssetType.gold: 5.0,
  };

  @override
  void initState() {
    super.initState();
    _loadTargetAllocation();
    _loadData();
  }

  Future<void> _loadTargetAllocation() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _targetAllocation[AssetType.stock] = prefs.getDouble('target_stock') ?? 60.0;
      _targetAllocation[AssetType.bond] = prefs.getDouble('target_bond') ?? 30.0;
      _targetAllocation[AssetType.cash] = prefs.getDouble('target_cash') ?? 5.0;
      _targetAllocation[AssetType.gold] = prefs.getDouble('target_gold') ?? 5.0;
    });
  }

  Future<void> _saveTargetAllocation() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('target_stock', _targetAllocation[AssetType.stock] ?? 60.0);
    await prefs.setDouble('target_bond', _targetAllocation[AssetType.bond] ?? 30.0);
    await prefs.setDouble('target_cash', _targetAllocation[AssetType.cash] ?? 5.0);
    await prefs.setDouble('target_gold', _targetAllocation[AssetType.gold] ?? 5.0);
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _assets = await _assetRepository.getAssets();
      _statistics = await _assetRepository.getAssetStatistics();
    } catch (e) {
      print('데이터 로딩 오류: $e');
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Map<AssetType, double> _getCurrentAllocation() {
    final distribution = _statistics['assetTypeDistribution'] as Map<AssetType, double>? ?? {};
    final totalAmount = _statistics['totalCurrentAmount'] as double? ?? 0.0;

    Map<AssetType, double> currentAllocation = {};

    for (final type in AssetType.values) {
      final amount = distribution[type] ?? 0.0;
      currentAllocation[type] = totalAmount > 0 ? (amount / totalAmount) * 100 : 0.0;
    }

    return currentAllocation;
  }

  Map<AssetType, double> _getRebalanceAmounts() {
    final currentAllocation = _getCurrentAllocation();
    final totalAmount = _statistics['totalCurrentAmount'] as double? ?? 0.0;

    Map<AssetType, double> rebalanceAmounts = {};

    for (final type in AssetType.values) {
      final currentPercent = currentAllocation[type] ?? 0.0;
      final targetPercent = _targetAllocation[type] ?? 0.0;
      final difference = targetPercent - currentPercent;
      rebalanceAmounts[type] = (difference / 100) * totalAmount;
    }

    return rebalanceAmounts;
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
        title: Text('포트폴리오 리밸런싱', style: TextStyle(color: titleColor)),
        backgroundColor: cardBackgroundColor,
        elevation: 1,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: titleColor),
            onPressed: _loadData,
            tooltip: '새로고침',
          ),
          IconButton(
            icon: Icon(Icons.tune, color: titleColor),
            onPressed: _showTargetAllocationSettings,
            tooltip: '목표 비율 설정',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildPortfolioOverview(theme, cardBackgroundColor, textColor, titleColor),
            const SizedBox(height: 24),
            _buildTargetAllocationCard(theme, cardBackgroundColor, textColor, titleColor),
            const SizedBox(height: 24),
            _buildAllocationComparison(theme, cardBackgroundColor, textColor, titleColor),
            const SizedBox(height: 24),
            _buildRebalanceRecommendations(theme, cardBackgroundColor, textColor, titleColor),
            const SizedBox(height: 24),
            const SizedBox(height: 100), // 추가 여백 오류방지용
          ],
        ),
      ),
    );
  }

  Widget _buildPortfolioOverview(ThemeData theme, Color? cardColor, Color? textColor, Color? titleColor) {
    final totalAmount = _statistics['totalCurrentAmount'] as double? ?? 0.0;
    final totalProfitLoss = _statistics['totalProfitLoss'] as double? ?? 0.0;
    final profitLossRate = _statistics['totalProfitLossRate'] as double? ?? 0.0;

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
                  style: theme.textTheme.titleMedium?.copyWith(color: textColor),
                ),
                Icon(Icons.pie_chart, color: textColor),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '총 자산: \$${totalAmount.toStringAsFixed(2)}',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('평가손익', style: theme.textTheme.bodySmall?.copyWith(color: textColor)),
                    Text(
                      '${totalProfitLoss >= 0 ? '+' : ''}\$${totalProfitLoss.toStringAsFixed(2)}',
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
          ],
        ),
      ),
    );
  }

  Widget _buildTargetAllocationCard(ThemeData theme, Color? cardColor, Color? textColor, Color? titleColor) {
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
                  '목표 자산 배분',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                ),
                TextButton.icon(
                  onPressed: _showTargetAllocationSettings,
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('편집'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...AssetType.values.map((type) {
              final target = _targetAllocation[type] ?? 0.0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _getAssetTypeColor(type),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        type.displayName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: titleColor,
                        ),
                      ),
                    ),
                    Text(
                      '${target.toStringAsFixed(1)}%',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: titleColor,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '목표 배분은 개인의 투자 성향과 목표에 따라 설정할 것',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllocationComparison(ThemeData theme, Color? cardColor, Color? textColor, Color? titleColor) {
    final currentAllocation = _getCurrentAllocation();

    return Card(
      color: cardColor,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '자산 배분 비교',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 16),
            ...AssetType.values.map((type) {
              final current = currentAllocation[type] ?? 0.0;
              final target = _targetAllocation[type] ?? 0.0;
              return _buildAllocationBar(type, current, target, theme, textColor, titleColor);
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildAllocationBar(AssetType type, double current, double target, ThemeData theme, Color? textColor, Color? titleColor) {
    final difference = current - target;
    final isOverweight = difference > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                type.displayName,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: titleColor,
                ),
              ),
              Text(
                '현재 ${current.toStringAsFixed(1)}% / 목표 ${target.toStringAsFixed(1)}%',
                style: theme.textTheme.bodySmall?.copyWith(color: textColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Stack(
            children: [
              Container(
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Container(
                height: 20,
                width: (current / 100) * MediaQuery.of(context).size.width * 0.8,
                decoration: BoxDecoration(
                  color: _getAssetTypeColor(type).withOpacity(0.7),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Positioned(
                left: (target / 100) * MediaQuery.of(context).size.width * 0.8 - 1,
                child: Container(
                  height: 20,
                  width: 2,
                  color: _getAssetTypeColor(type),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${isOverweight ? '초과' : '부족'}: ${difference.abs().toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 12,
              color: isOverweight ? Colors.red[600] : Colors.blue[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
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

  Widget _buildRebalanceRecommendations(ThemeData theme, Color? cardColor, Color? textColor, Color? titleColor) {
    final rebalanceAmounts = _getRebalanceAmounts();

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
              children: [
                Icon(Icons.lightbulb_outline, color: theme.colorScheme.secondary),
                const SizedBox(width: 8),
                Text(
                  '리밸런싱 권장사항',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...rebalanceAmounts.entries.map((entry) {
              final type = entry.key;
              final amount = entry.value;

              if (amount.abs() < 10) return const SizedBox.shrink(); // 소액 무시

              final isIncrease = amount > 0;

              return Container(
                margin: const EdgeInsets.only(bottom: 12.0),
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: (isIncrease ? Colors.green : Colors.red).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (isIncrease ? Colors.green : Colors.red).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isIncrease ? Icons.arrow_upward : Icons.arrow_downward,
                      color: isIncrease ? Colors.green : Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${type.displayName}을(를) ${isIncrease ? '추가 매수' : '일부 판매'}: ${amount.abs().toStringAsFixed(2)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: titleColor,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            if (rebalanceAmounts.values.every((amount) => amount.abs() < 10)) ...[
              Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '포트폴리오가 목표 배분에 근접합니다. 리밸런싱이 필요하지 않습니다.',
                        style: theme.textTheme.bodyMedium?.copyWith(color: titleColor),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showTargetAllocationSettings() {
    showDialog(
      context: context,
      builder: (context) {
        Map<AssetType, double> tempAllocation = Map.from(_targetAllocation);

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final total = tempAllocation.values.fold(0.0, (sum, value) => sum + value);
            final isValid = (total - 100).abs() < 0.1;

            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.tune, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  const Text('목표 자산 배분 설정'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue.shade700, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '슬라이더를 조정하여 각 자산 유형의 목표 비율을 설정',
                              style: TextStyle(
                                color: Colors.blue.shade700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    ...AssetType.values.map((type) {
                      return Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: _getAssetTypeColor(type),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Text(type.displayName)),
                              Container(
                                width: 60,
                                child: TextField(
                                  decoration: const InputDecoration(
                                    suffixText: '%',
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  ),
                                  keyboardType: TextInputType.number,
                                  controller: TextEditingController(
                                    text: tempAllocation[type]?.toStringAsFixed(1) ?? '0.0',
                                  ),
                                  onChanged: (value) {
                                    final newValue = double.tryParse(value) ?? 0.0;
                                    if (newValue >= 0 && newValue <= 100) {
                                      setDialogState(() {
                                        tempAllocation[type] = newValue;
                                      });
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          Slider(
                            value: tempAllocation[type] ?? 0,
                            min: 0,
                            max: 100,
                            divisions: 100,
                            activeColor: _getAssetTypeColor(type),
                            onChanged: (value) {
                              setDialogState(() {
                                tempAllocation[type] = value;
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                        ],
                      );
                    }).toList(),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '총합:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '${total.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isValid ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                    if (!isValid) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning, color: Colors.red.shade700, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '총합이 100%가 되어야 함',
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('취소'),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () {
                        // 기본값으로 리셋
                        setDialogState(() {
                          tempAllocation = {
                            AssetType.stock: 60.0,
                            AssetType.bond: 30.0,
                            AssetType.cash: 5.0,
                            AssetType.gold: 5.0,
                          };
                        });
                      },
                      child: const Text('기본값'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: isValid ? () {
                        setState(() {
                          _targetAllocation = tempAllocation;
                        });
                        _saveTargetAllocation();
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('목표 배분 저장 완료')),
                        );
                      } : null,
                      child: const Text('저장'),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }
}