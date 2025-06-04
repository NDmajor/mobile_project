// lib/pages/stock_status_page.dart
import 'package:flutter/material.dart';
import 'package:stock_rebalence/models/stock_holding.dart';
import 'package:stock_rebalence/pages/add_stock_page.dart';
import 'package:stock_rebalence/service/stock_repository.dart';
import 'package:stock_rebalence/service/alpha_vantage_service.dart';
import 'package:syncfusion_flutter_charts/charts.dart'; // 차트 사용을 위한 import

class AccountStatusPage extends StatefulWidget {
  const AccountStatusPage({super.key});

  @override
  State<AccountStatusPage> createState() => _AccountStatusPageState();
}

class _AccountStatusPageState extends State<AccountStatusPage> {
  int _selectedNavigationBarIndex = 0;

  final StockRepository _repository = StockRepository();
  final YahooFinanceService _financeService = YahooFinanceService();

  List<StockHolding> _holdings = []; // 실제 보유 주식 목록
  bool _isLoading = true;
  double _totalAssets = 0.0;
  double _totalPurchaseAmount = 0.0;
  double _totalEvaluationAmount = 0.0;
  double _totalProfitLoss = 0.0;
  double _overallProfitLossRate = 0.0;
  double _cashBalance = 500000.0; // 현금은 사용자가 입력하거나 다른 방식으로 관리 가능

  // 파이 차트 데이터
  List<_PieData> _pieData = [];

  @override
  void initState() {
    super.initState();
    _loadHoldingsAndUpdate();
  }

  Future<void> _loadHoldingsAndUpdate() async {
    if (!mounted) return; // 위젯이 마운트되지 않은 경우 상태 업데이트 방지
    setState(() {
      _isLoading = true;
    });

    List<StockHolding> localHoldings = await _repository.getHoldings();
    if (localHoldings.isNotEmpty) {
      _holdings = await _financeService.updateStockHoldings(localHoldings);
    } else {
      _holdings = [];
    }
    _calculateTotals();

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }

  void _calculateTotals() {
    _totalPurchaseAmount = 0.0;
    _totalEvaluationAmount = 0.0;

    for (var holding in _holdings) {
      // API 호출로 currentPrice가 업데이트 되었다고 가정하고 계산
      // updateStockHoldings에서 calculateProfitLoss가 이미 호출되었을 수 있음
      // 명시적으로 여기서도 호출하거나, 해당 함수 내에서만 호출하도록 구조화
      holding.calculateProfitLoss(); // currentPrice 기준으로 평가금액 및 손익 재계산
      _totalPurchaseAmount += holding.purchasePrice * holding.quantity;
      _totalEvaluationAmount += holding.evaluationAmount;
    }

    _totalProfitLoss = _totalEvaluationAmount - _totalPurchaseAmount;
    _overallProfitLossRate = (_totalPurchaseAmount > 0)
        ? (_totalProfitLoss / _totalPurchaseAmount) * 100
        : 0.0;
    _totalAssets = _totalEvaluationAmount + _cashBalance;

    _updatePieData();
  }

  void _updatePieData() {
    if (_totalAssets <= 0) { // 총 자산이 0 이하면 빈 데이터
      _pieData = [];
      return;
    }
    _pieData = [
      if (_cashBalance > 0) _PieData('현금', _cashBalance, Colors.grey[400]!),
      ..._holdings.where((h) => h.evaluationAmount > 0).map((h) => _PieData(
          h.name.isNotEmpty ? h.name : h.symbol,
          h.evaluationAmount,
          _getColorForStock(h.symbol)))
    ];
    // 0 이하의 값은 차트에서 제외 (이미 where 필터로 처리)
  }

  final Map<String, Color> _stockColors = {};
  int _colorIndex = 0;
  final List<Color> _availableColors = [
    Colors.blueAccent, Colors.greenAccent, Colors.orangeAccent, Colors.purpleAccent,
    Colors.redAccent, Colors.tealAccent, Colors.pinkAccent, Colors.amberAccent,
  ];

  Color _getColorForStock(String symbol) {
    if (!_stockColors.containsKey(symbol)) {
      _stockColors[symbol] = _availableColors[_colorIndex % _availableColors.length];
      _colorIndex++;
    }
    return _stockColors[symbol]!;
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
            icon: Icon(Icons.settings_outlined, color: titleColor),
            onPressed: () {
              // 설정 페이지로 이동하는 로직
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadHoldingsAndUpdate,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildAccountSummary(theme, cardBackgroundColor, textColor, titleColor),
            const SizedBox(height: 24),
            _buildPortfolioChart(theme, cardBackgroundColor, textColor, titleColor),
            const SizedBox(height: 24),
            _buildHoldingsList(theme, cardBackgroundColor, textColor, titleColor),
            const SizedBox(height: 24),
            _buildRebalanceButton(theme),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: '홈'),
          BottomNavigationBarItem(icon: Icon(Icons.pie_chart_outline), label: '리밸런싱'),
          BottomNavigationBarItem(icon: Icon(Icons.analytics_outlined), label: '투자 분석'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: '프로필'),
        ],
        currentIndex: _selectedNavigationBarIndex,
        selectedItemColor: theme.colorScheme.primary,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        onTap: (index) {
          if (!mounted) return;
          setState(() {
            _selectedNavigationBarIndex = index;
            // TODO: 각 탭에 따른 페이지 전환 로직 구현
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: cardBackgroundColor,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddStockPage()),
          );
          if (result == true && mounted) {
            _loadHoldingsAndUpdate();
          }
        },
        tooltip: '보유 주식 추가',
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
            Text(
              '총 자산',
              style: theme.textTheme.titleMedium?.copyWith(color: textColor),
            ),
            const SizedBox(height: 8),
            Text(
              '₩${_totalAssets.toStringAsFixed(0)}',
              style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: titleColor),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('총 투자원금', style: theme.textTheme.bodySmall?.copyWith(color: textColor)),
                    Text('₩${_totalPurchaseAmount.toStringAsFixed(0)}', style: theme.textTheme.titleSmall?.copyWith(color: titleColor)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('총 평가손익', style: theme.textTheme.bodySmall?.copyWith(color: textColor)),
                    Text(
                      '${_totalProfitLoss >= 0 ? '+' : ''}${_totalProfitLoss.toStringAsFixed(0)} (${_overallProfitLossRate.toStringAsFixed(2)}%)',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: _totalProfitLoss >= 0 ? Colors.redAccent : Colors.blueAccent,
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
                Text('₩${_cashBalance.toStringAsFixed(0)}', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: titleColor)),
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
                    dataLabelSettings: const DataLabelSettings(isVisible: true, textStyle: TextStyle(fontSize: 10, color: Colors.black)), // 데이터 레이블 색상 고정
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

  Widget _buildHoldingsList(ThemeData theme, Color? cardColor, Color? textColor, Color? titleColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('보유 종목', style: theme.textTheme.titleLarge?.copyWith(color: titleColor)),
        const SizedBox(height: 8),
        _isLoading
            ? const Center(child: Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator()))
            : _holdings.isEmpty
            ? Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0),
          child: Center(child: Text('보유 중인 종목이 없습니다.', style: theme.textTheme.bodyMedium?.copyWith(color: textColor))),
        )
            : ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _holdings.length,
          itemBuilder: (context, index) {
            final stock = _holdings[index];
            return Card(
              color: cardColor,
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              child: ListTile(
                title: Text(stock.name.isNotEmpty ? stock.name : stock.symbol, style: theme.textTheme.titleMedium?.copyWith(color: titleColor)),
                subtitle: Text(
                    '수량: ${stock.quantity.toStringAsFixed(0)}주 · 평단: ${stock.purchasePrice.toStringAsFixed(0)}원',
                    style: theme.textTheme.bodySmall?.copyWith(color: textColor)),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('₩${stock.currentPrice.toStringAsFixed(0)}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: stock.profitLoss >= 0 ? Colors.redAccent : Colors.blueAccent,
                        )),
                    Text(
                      '${stock.profitLoss >= 0 ? '+' : ''}${stock.profitLoss.toStringAsFixed(0)} (${stock.profitLossRate.toStringAsFixed(2)}%)',
                      style: TextStyle(
                        fontSize: 12,
                        color: stock.profitLoss >= 0 ? Colors.redAccent : Colors.blueAccent,
                      ),
                    ),
                  ],
                ),
                onTap: () {
                  // 종목 상세 페이지로 이동 (구현 필요)
                  print('Tapped on ${stock.symbol}');
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRebalanceButton(ThemeData theme) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 50),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      onPressed: _isLoading ? null : () {
        // 리밸런싱 페이지로 이동 또는 기능 실행
        print('리밸런싱 버튼 클릭됨');
        // 예: Navigator.push(context, MaterialPageRoute(builder: (context) => RebalancePage()));
      },
      child: const Text('포트폴리오 리밸런싱 하기', style: TextStyle(fontSize: 16)),
    );
  }
}

// 차트 데이터 클래스
class _PieData {
  _PieData(this.xData, this.yData, [this.color = Colors.transparent]);
  final String xData;
  final double yData;
  final Color color;
}