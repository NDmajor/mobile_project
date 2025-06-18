// lib/models/asset.dart
import 'package:flutter/foundation.dart';

enum AssetType {
  stock('주식'),
  cash('현금'),
  bond('채권'),
  gold('금');

  const AssetType(this.displayName);
  final String displayName;
}

abstract class Asset {
  final String id;
  final AssetType type;
  final String name;
  final double quantity;
  final double purchasePrice;
  final DateTime purchaseDate;
  double currentPrice;

  Asset({
    required this.id,
    required this.type,
    required this.name,
    required this.quantity,
    required this.purchasePrice,
    required this.purchaseDate,
    this.currentPrice = 0.0,
  });

  // 평가금액
  double get evaluationAmount => quantity * currentPrice;

  // 평가손익
  double get profitLoss => (currentPrice - purchasePrice) * quantity;

  // 수익률
  double get profitLossRate => purchasePrice > 0 ? (currentPrice / purchasePrice - 1) * 100 : 0.0;

  Map<String, dynamic> toJson();

  static Asset fromJson(Map<String, dynamic> json) {
    final type = AssetType.values.firstWhere(
          (e) => e.name == json['type'],
      orElse: () => AssetType.stock,
    );

    switch (type) {
      case AssetType.stock:
        return StockAsset.fromJson(json);
      case AssetType.cash:
        return CashAsset.fromJson(json);
      case AssetType.bond:
        return BondAsset.fromJson(json);
      case AssetType.gold:
        return GoldAsset.fromJson(json);
    }
  }
}

// 주식 자산
class StockAsset extends Asset {
  final String symbol;
  final String exchange;

  StockAsset({
    required super.id,
    required this.symbol,
    required super.name,
    required super.quantity,
    required super.purchasePrice,
    required super.purchaseDate,
    super.currentPrice = 0.0,
    this.exchange = 'NASDAQ',
  }) : super(type: AssetType.stock);

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'symbol': symbol,
    'name': name,
    'quantity': quantity,
    'purchasePrice': purchasePrice,
    'purchaseDate': purchaseDate.toIso8601String(),
    'currentPrice': currentPrice,
    'exchange': exchange,
  };

  factory StockAsset.fromJson(Map<String, dynamic> json) {
    return StockAsset(
      id: json['id'] ?? '',
      symbol: json['symbol'] ?? '',
      name: json['name'] ?? '',
      quantity: (json['quantity'] ?? 0).toDouble(),
      purchasePrice: (json['purchasePrice'] ?? 0).toDouble(),
      purchaseDate: DateTime.parse(json['purchaseDate'] ?? DateTime.now().toIso8601String()),
      currentPrice: (json['currentPrice'] ?? 0).toDouble(),
      exchange: json['exchange'] ?? 'NASDAQ',
    );
  }
}

// 현금 자산
class CashAsset extends Asset {
  final String currency;
  final String accountType;

  CashAsset({
    required super.id,
    required super.name,
    required super.quantity,
    required super.purchaseDate,
    this.currency = 'USD',
    this.accountType = '예금',
  }) : super(
    type: AssetType.cash,
    purchasePrice: 1.0,
    currentPrice: 1.0,
  );

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'name': name,
    'quantity': quantity,
    'purchasePrice': purchasePrice,
    'purchaseDate': purchaseDate.toIso8601String(),
    'currentPrice': currentPrice,
    'currency': currency,
    'accountType': accountType,
  };

  factory CashAsset.fromJson(Map<String, dynamic> json) {
    return CashAsset(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      quantity: (json['quantity'] ?? 0).toDouble(),
      purchaseDate: DateTime.parse(json['purchaseDate'] ?? DateTime.now().toIso8601String()),
      currency: json['currency'] ?? 'USD',
      accountType: json['accountType'] ?? '예금',
    );
  }
}

// 채권 자산
class BondAsset extends Asset {
  final String issuer;
  final double interestRate;
  final DateTime maturityDate;

  BondAsset({
    required super.id,
    required super.name,
    required super.quantity,
    required super.purchasePrice,
    required super.purchaseDate,
    super.currentPrice = 0.0,
    required this.issuer,
    required this.interestRate,
    required this.maturityDate,
  }) : super(type: AssetType.bond);

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'name': name,
    'quantity': quantity,
    'purchasePrice': purchasePrice,
    'purchaseDate': purchaseDate.toIso8601String(),
    'currentPrice': currentPrice,
    'issuer': issuer,
    'interestRate': interestRate,
    'maturityDate': maturityDate.toIso8601String(),
  };

  factory BondAsset.fromJson(Map<String, dynamic> json) {
    return BondAsset(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      quantity: (json['quantity'] ?? 0).toDouble(),
      purchasePrice: (json['purchasePrice'] ?? 0).toDouble(),
      purchaseDate: DateTime.parse(json['purchaseDate'] ?? DateTime.now().toIso8601String()),
      currentPrice: (json['currentPrice'] ?? 0).toDouble(),
      issuer: json['issuer'] ?? '',
      interestRate: (json['interestRate'] ?? 0).toDouble(),
      maturityDate: DateTime.parse(json['maturityDate'] ?? DateTime.now().toIso8601String()),
    );
  }
}

// 금 자산
class GoldAsset extends Asset {
  final String unit;
  final String storageLocation;

  GoldAsset({
    required super.id,
    required super.name,
    required super.quantity,
    required super.purchasePrice,
    required super.purchaseDate,
    super.currentPrice = 0.0,
    this.unit = '온스',
    this.storageLocation = '은행 금고',
  }) : super(type: AssetType.gold);

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'name': name,
    'quantity': quantity,
    'purchasePrice': purchasePrice,
    'purchaseDate': purchaseDate.toIso8601String(),
    'currentPrice': currentPrice,
    'unit': unit,
    'storageLocation': storageLocation,
  };

  factory GoldAsset.fromJson(Map<String, dynamic> json) {
    return GoldAsset(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      quantity: (json['quantity'] ?? 0).toDouble(),
      purchasePrice: (json['purchasePrice'] ?? 0).toDouble(),
      purchaseDate: DateTime.parse(json['purchaseDate'] ?? DateTime.now().toIso8601String()),
      currentPrice: (json['currentPrice'] ?? 0).toDouble(),
      unit: json['unit'] ?? '온스',
      storageLocation: json['storageLocation'] ?? '은행 금고',
    );
  }
}