// lib/models/stock_holding.dart
import 'package:flutter/foundation.dart';

class StockHolding {
  final String symbol; // 종목 코드
  String name; // 종목명
  final double quantity; // 보유 수량
  final double purchasePrice; // 평균매수단가
  double currentPrice; // 현재가
  double profitLoss; // 평가손익
  double profitLossRate; // 수익률

  StockHolding({
    required this.symbol,
    this.name = '',
    required this.quantity,
    required this.purchasePrice,
    this.currentPrice = 0.0,
    this.profitLoss = 0.0,
    this.profitLossRate = 0.0,
  });

  Map<String, dynamic> toJson() => {
    'symbol': symbol,
    'name': name,
    'quantity': quantity,
    'purchasePrice': purchasePrice,
    'currentPrice': currentPrice,
  };

  factory StockHolding.fromJson(Map<String, dynamic> json) {
    return StockHolding(
      symbol: json['symbol'],
      name: json['name'] ?? '',
      quantity: json['quantity'],
      purchasePrice: json['purchasePrice'],
      currentPrice: json['currentPrice'] ?? 0.0,
    );
  }

  // 평가금액
  double get evaluationAmount => quantity * currentPrice;

  // 평가손익이랑 수익률
  void calculateProfitLoss() {
    if (currentPrice > 0 && purchasePrice > 0) {
      profitLoss = (currentPrice - purchasePrice) * quantity;
      profitLossRate = (currentPrice / purchasePrice - 1) * 100;
    } else {
      profitLoss = 0.0;
      profitLossRate = 0.0;
    }
  }
}