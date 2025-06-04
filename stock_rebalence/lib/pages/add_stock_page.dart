// lib/pages/add_stock_page.dart
import 'package:flutter/material.dart';
import 'package:stock_rebalence/models/stock_holding.dart';
import 'package:stock_rebalence/service/stock_repository.dart';

class AddStockPage extends StatefulWidget {
  const AddStockPage({super.key});

  @override
  State<AddStockPage> createState() => _AddStockPageState();
}

class _AddStockPageState extends State<AddStockPage> {
  final _formKey = GlobalKey<FormState>();
  final _symbolController = TextEditingController();
  final _quantityController = TextEditingController();
  final _purchasePriceController = TextEditingController();

  final StockRepository _repository = StockRepository(); // Repository 인스턴스

  @override
  void dispose() {
    _symbolController.dispose();
    _quantityController.dispose();
    _purchasePriceController.dispose();
    super.dispose();
  }

  Future<void> _saveStock() async {
    if (_formKey.currentState!.validate()) {
      final symbol = _symbolController.text.toUpperCase();
      final quantity = double.tryParse(_quantityController.text) ?? 0;
      final purchasePrice = double.tryParse(_purchasePriceController.text) ?? 0;

      if (quantity > 0 && purchasePrice > 0) {
        final newHolding = StockHolding(
          symbol: symbol,
          quantity: quantity,
          purchasePrice: purchasePrice,
        );

        // 로컬에 저장
        List<StockHolding> currentHoldings = await _repository.getHoldings();
        currentHoldings.add(newHolding);
        await _repository.saveHoldings(currentHoldings);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${newHolding.symbol} 추가됨')),
          );
          Navigator.pop(context, true); // true를 반환하여 이전 페이지에서 목록을 새로고침하도록 함
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('수량과 매수가는 0보다 커야 합니다.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('보유 주식 추가'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: <Widget>[
              TextFormField(
                controller: _symbolController,
                decoration: const InputDecoration(labelText: '종목 코드 (예: AAPL)'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '종목 코드를 입력하세요.';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _quantityController,
                decoration: const InputDecoration(labelText: '보유 수량'),
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
              TextFormField(
                controller: _purchasePriceController,
                decoration: const InputDecoration(labelText: '평균 매수가'),
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
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saveStock,
                child: const Text('저장하기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}