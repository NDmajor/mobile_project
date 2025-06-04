// lib/pages/main_page.dart
import 'package:flutter/material.dart';
import 'package:stock_rebalence/pages/stock_status_page.dart';
import 'package:stock_rebalence/pages/my_assets_page.dart';
import 'package:stock_rebalence/pages/rebalence_page.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const AccountStatusPage(), // 홈
    const MyAssetsPage(),      // 나의 자산
    const RebalancePage(),     // 리밸런싱
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          selectedItemColor: theme.colorScheme.primary,
          unselectedItemColor: Colors.grey[600],
          showUnselectedLabels: true,
          elevation: 0,
          backgroundColor: isDarkMode ? Colors.grey[850] : Colors.white,
          selectedLabelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
          items: [
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  _selectedIndex == 0 ? Icons.home : Icons.home_outlined,
                  size: 24,
                ),
              ),
              label: '홈',
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  _selectedIndex == 1 ? Icons.account_balance_wallet : Icons.account_balance_wallet_outlined,
                  size: 24,
                ),
              ),
              label: '나의 자산',
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  _selectedIndex == 2 ? Icons.pie_chart : Icons.pie_chart_outline,
                  size: 24,
                ),
              ),
              label: '리밸런싱',
            ),
          ],
        ),
      ),
    );
  }
}