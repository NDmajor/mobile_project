import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart'; // 차트 사용을 위한 import (WODS-master의 pubspec.yaml 참고)


class AccountStatusPage extends StatefulWidget {
  const AccountStatusPage({super.key});

  @override
  State<AccountStatusPage> createState() => _AccountStatusPageState();
}

class _AccountStatusPageState extends State<AccountStatusPage> {
  // WODS-master/lib/MyApp.dart 에서 아이디어 가져옴
  int _selectedNavigationBarIndex = 0;

  // 샘플 데이터
  final double totalAssets = 12345678.0;
  final double investmentPrincipal = 10000000.0;
  final double profitRate = 23.45;
  final double cashBalance = 500000.0;

  // 샘플 보유 종목 데이터 (WODS-master/lib/tabs/Watchlists.dart 의 데이터 구조 참고)
  final List<Map<String, dynamic>> holdings = [
    {'name': '삼성전자', 'currentPrice': 75000.0, 'evalAmount': 3000000.0, 'profitRate': 10.5, 'quantity': 40},
    {'name': '카카오', 'currentPrice': 55000.0, 'evalAmount': 2200000.0, 'profitRate': -5.2, 'quantity': 40},
    {'name': 'NAVER', 'currentPrice': 220000.0, 'evalAmount': 1100000.0, 'profitRate': 15.0, 'quantity': 5},
    // ... 추가 보유 종목
  ];

  // 샘플 포트폴리오 차트 데이터 (WODS-master/lib/markets_tabs/Overview.dart 의 차트 데이터 구조 참고)
  final List<ChartData> portfolioChartData = [
    ChartData('주식', 70, Colors.blue),
    ChartData('펀드', 20, Colors.green),
    ChartData('현금', 10, Colors.grey),
  ];


  @override
  Widget build(BuildContext context) {
    // WODS-master/lib/main.dart 의 테마 설정을 참고할 수 있습니다.
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        // WODS-master/lib/main.dart 의 AppBarTheme 참고
        title: const Text('나의 자산 현황'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              // 설정 페이지로 이동하는 로직 (WODS-master/lib/RouteGenerator.dart 참고)
            },
          ),
        ],
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(), // WODS-master/lib/markets_tabs/Overview.dart 참고
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildAccountSummary(theme),
          const SizedBox(height: 24),
          _buildPortfolioChart(theme),
          const SizedBox(height: 24),
          _buildHoldingsList(theme),
          const SizedBox(height: 24),
          _buildRebalanceButton(theme), // WODS-master/lib/main.dart 의 ElevatedButtonThemeData 참고
        ],
      ),
      // WODS-master/lib/MyApp.dart 의 BottomNavigationBar 참고
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home_filled),
            label: '홈',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.pie_chart_outline), // 리밸런싱 아이콘 예시
            label: '리밸런싱',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics_outlined),
            label: '투자 분석',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline), // WODS-master/lib/MyApp.dart 의 Profile 아이콘 참고
            label: '프로필',
          ),
        ],
        currentIndex: _selectedNavigationBarIndex,
        selectedItemColor: theme.colorScheme.primary, // WODS-master/lib/MyApp.dart 의 selectedItemColor 참고
        unselectedItemColor: Colors.grey, // WODS-master/lib/MyApp.dart 의 unselectedItemColor 참고
        showUnselectedLabels: true,
        onTap: (index) {
          setState(() {
            _selectedNavigationBarIndex = index;
            // TODO: 각 탭에 따른 페이지 전환 로직 구현 (WODS-master/lib/RouteGenerator.dart 또는 TabBarView 참고)
          });
        },
        type: BottomNavigationBarType.fixed, // WODS-master/lib/MyApp.dart 참고
      ),
    );
  }

  Widget _buildAccountSummary(ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '총 자산',
              style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey[700]),
            ),
            const SizedBox(height: 8),
            Text(
              '₩${totalAssets.toStringAsFixed(0)}', // 실제 앱에서는 NumberFormat 사용 고려 (WODS-master/lib/common_widgets/QuateListTile.dart)
              style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('투자원금', style: theme.textTheme.bodySmall),
                    Text('₩${investmentPrincipal.toStringAsFixed(0)}', style: theme.textTheme.titleSmall),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('수익률', style: theme.textTheme.bodySmall),
                    Text(
                      '${profitRate > 0 ? '+' : ''}${profitRate.toStringAsFixed(2)}%',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: profitRate > 0 ? Colors.redAccent : Colors.blueAccent, // WODS-master/lib/common_widgets/QuateListTile.dart 의 색상 참고
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
                Text('현금/예수금', style: theme.textTheme.bodyMedium),
                Text('₩${cashBalance.toStringAsFixed(0)}', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildPortfolioChart(ThemeData theme) {
    // WODS-master/lib/markets_tabs/Overview.dart 의 SfCartesianChart/IndicesDistibution 참고
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('포트폴리오 현황', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              // syncfusion_flutter_charts 예시
              child: SfCircularChart(
                legend: Legend(isVisible: true, overflowMode: LegendItemOverflowMode.wrap),
                series: <CircularSeries>[
                  PieSeries<ChartData, String>(
                    dataSource: portfolioChartData,
                    xValueMapper: (ChartData data, _) => data.x,
                    yValueMapper: (ChartData data, _) => data.y,
                    pointColorMapper: (ChartData data, _) => data.color,
                    dataLabelSettings: const DataLabelSettings(isVisible: true),
                    enableTooltip: true,
                  )
                ],
              ),
            ),
            // WODS-master/lib/common_widgets/IntervalSelector.dart 참고하여 기간/종류 선택 UI 추가 가능
          ],
        ),
      ),
    );
  }

  Widget _buildHoldingsList(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('보유 종목', style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        if (holdings.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20.0),
            child: Center(child: Text('보유 중인 종목이 없습니다.', style: theme.textTheme.bodyMedium)),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(), // 중첩 스크롤 방지
            itemCount: holdings.length,
            itemBuilder: (context, index) {
              final holding = holdings[index];
              // WODS-master/lib/common_widgets/QuateListTile.dart 를 참고하여 커스텀 ListTile 생성
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4.0),
                child: ListTile(
                  title: Text(holding['name'], style: theme.textTheme.titleMedium),
                  subtitle: Text('수량: ${holding['quantity']}주  | 현재가: ₩${(holding['currentPrice'] as double).toStringAsFixed(0)}'),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('₩${(holding['evalAmount'] as double).toStringAsFixed(0)}', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                      Text(
                        '${(holding['profitRate'] as double) > 0 ? '+' : ''}${(holding['profitRate'] as double).toStringAsFixed(2)}%',
                        style: TextStyle(
                          color: (holding['profitRate'] as double) > 0 ? Colors.redAccent : Colors.blueAccent,
                        ),
                      ),
                    ],
                  ),
                  onTap: () {
                    // 종목 상세 페이지로 이동 (WODS-master/lib/pages/SymbolDetail.dart 참고)
                  },
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildRebalanceButton(ThemeData theme) {
    // WODS-master/lib/main.dart 의 ElevatedButtonThemeData 참고
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 50), // 버튼 크기
        // WODS-master/lib/main.dart 의 버튼 스타일 참고
        // backgroundColor: theme.primaryColor,
        // foregroundColor: Colors.white,
      ),
      onPressed: () {
        // 리밸런싱 페이지로 이동 또는 기능 실행
      },
      child: const Text('포트폴리오 리밸런싱 하기', style: TextStyle(fontSize: 16)),
    );
  }
}

// 차트 데이터 클래스 (WODS-master/lib/markets_tabs/Overview.dart 참고)
class ChartData {
  ChartData(this.x, this.y, [this.color]);
  final String x;
  final double y;
  final Color? color;
}

// 이 페이지를 앱에 통합하려면 main.dart 또는 라우팅 설정 파일을 수정해야 합니다.
// 예시:
// WODS-master/lib/main.dart 의 MaterialApp 설정을 참고하여 initialRoute 또는 home 설정
/*
void main() {
  // WODS-master/lib/main.dart 처럼 초기화 코드 필요 시 추가
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '주식 계좌 앱',
      theme: ThemeData( // WODS-master/lib/main.dart 의 테마 설정 참고
        primarySwatch: Colors.blue,
        // ... 기타 테마 설정
      ),
      darkTheme: ThemeData.dark(), // WODS-master/lib/main.dart 의 다크 테마 설정 참고
      themeMode: ThemeMode.system, // WODS-master/lib/main.dart 의 테마 모드 설정 참고
      home: AccountStatusPage(), // 이 페이지를 홈으로 설정
      // onGenerateRoute: RouteGenerator.generateRoute, // WODS-master/lib/RouteGenerator.dart 참고하여 라우팅 설정
    );
  }
}
*/