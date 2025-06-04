// lib/models/stock_holding.dart
import 'package:flutter/foundation.dart';

class StockHolding {
  final String symbol; // 종목 코드 (예: "AAPL")
  String name; // 종목명 (예: "Apple Inc.") - API를 통해 가져올 수 있음
  final double quantity; // 보유 수량
  final double purchasePrice; // 평균 매수 단가
  double currentPrice; // 현재가 (API를 통해 업데이트)
  double profitLoss; // 평가 손익
  double profitLossRate; // 수익률

  StockHolding({
    required this.symbol,
    this.name = '', // 초기에는 비워두거나 symbol로 설정 가능
    required this.quantity,
    required this.purchasePrice,
    this.currentPrice = 0.0,
    this.profitLoss = 0.0,
    this.profitLossRate = 0.0,
  });

  // JSON 직렬화/역직렬화를 위한 메서드
  Map<String, dynamic> toJson() => {
    'symbol': symbol,
    'name': name,
    'quantity': quantity,
    'purchasePrice': purchasePrice,
    'currentPrice': currentPrice, // 현재가는 저장 시점의 값, 로드 후 업데이트 필요
  };

  factory StockHolding.fromJson(Map<String, dynamic> json) {
    return StockHolding(
      symbol: json['symbol'],
      name: json['name'] ?? '',
      quantity: json['quantity'],
      purchasePrice: json['purchasePrice'],
      currentPrice: json['currentPrice'] ?? 0.0, // 로드 후 API로 업데이트
    );
  }

  // 평가금액 계산
  double get evaluationAmount => quantity * currentPrice;

  // 평가손익 및 수익률 계산 (현재가 업데이트 후 호출)
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