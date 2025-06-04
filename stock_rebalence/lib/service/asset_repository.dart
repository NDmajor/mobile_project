// lib/service/asset_repository.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stock_rebalence/models/asset.dart';

class AssetRepository {
  static const String _assetsKey = 'user_assets';

  // 모든 자산 저장
  Future<void> saveAssets(List<Asset> assets) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> assetsJson = assets.map((asset) => jsonEncode(asset.toJson())).toList();
    await prefs.setStringList(_assetsKey, assetsJson);
  }

  // 모든 자산 조회
  Future<List<Asset>> getAssets() async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? assetsJson = prefs.getStringList(_assetsKey);
    if (assetsJson == null) {
      return [];
    }
    return assetsJson
        .map((assetJson) => Asset.fromJson(jsonDecode(assetJson)))
        .toList();
  }

  // 자산 유형별 조회
  Future<List<Asset>> getAssetsByType(AssetType type) async {
    final assets = await getAssets();
    return assets.where((asset) => asset.type == type).toList();
  }

  // 특정 자산 조회
  Future<Asset?> getAssetById(String id) async {
    final assets = await getAssets();
    try {
      return assets.firstWhere((asset) => asset.id == id);
    } catch (e) {
      return null;
    }
  }

  // 자산 추가
  Future<void> addAsset(Asset asset) async {
    List<Asset> assets = await getAssets();
    assets.add(asset);
    await saveAssets(assets);
  }

  // 자산 업데이트
  Future<void> updateAsset(Asset updatedAsset) async {
    List<Asset> assets = await getAssets();
    int index = assets.indexWhere((asset) => asset.id == updatedAsset.id);
    if (index != -1) {
      assets[index] = updatedAsset;
      await saveAssets(assets);
    }
  }

  // 자산 삭제
  Future<void> deleteAsset(String id) async {
    List<Asset> assets = await getAssets();
    assets.removeWhere((asset) => asset.id == id);
    await saveAssets(assets);
  }

  // 자산 일부 판매 (수량 감소)
  Future<void> sellAsset(String id, double quantityToSell, double sellPrice) async {
    List<Asset> assets = await getAssets();
    int index = assets.indexWhere((asset) => asset.id == id);

    if (index != -1) {
      Asset asset = assets[index];
      if (asset.quantity >= quantityToSell) {
        // 판매 기록을 위한 새로운 자산 생성 (판매 이력 관리용)
        Asset soldAsset = _createSoldAsset(asset, quantityToSell, sellPrice);

        // 기존 자산의 수량 감소
        Asset updatedAsset = _updateAssetQuantity(asset, asset.quantity - quantityToSell);

        if (updatedAsset.quantity <= 0) {
          // 수량이 0이 되면 자산 삭제
          assets.removeAt(index);
        } else {
          // 수량이 남아있으면 업데이트
          assets[index] = updatedAsset;
        }

        // 판매 이력 저장 (별도 구현 가능)
        await _saveSaleHistory(soldAsset, sellPrice);

        await saveAssets(assets);
      }
    }
  }

  // 자산 수량 업데이트를 위한 헬퍼 메서드
  Asset _updateAssetQuantity(Asset asset, double newQuantity) {
    switch (asset.type) {
      case AssetType.stock:
        final stockAsset = asset as StockAsset;
        return StockAsset(
          id: stockAsset.id,
          symbol: stockAsset.symbol,
          name: stockAsset.name,
          quantity: newQuantity,
          purchasePrice: stockAsset.purchasePrice,
          purchaseDate: stockAsset.purchaseDate,
          currentPrice: stockAsset.currentPrice,
          exchange: stockAsset.exchange,
        );
      case AssetType.cash:
        final cashAsset = asset as CashAsset;
        return CashAsset(
          id: cashAsset.id,
          name: cashAsset.name,
          quantity: newQuantity,
          purchaseDate: cashAsset.purchaseDate,
          currency: cashAsset.currency,
          accountType: cashAsset.accountType,
        );
      case AssetType.bond:
        final bondAsset = asset as BondAsset;
        return BondAsset(
          id: bondAsset.id,
          name: bondAsset.name,
          quantity: newQuantity,
          purchasePrice: bondAsset.purchasePrice,
          purchaseDate: bondAsset.purchaseDate,
          currentPrice: bondAsset.currentPrice,
          issuer: bondAsset.issuer,
          interestRate: bondAsset.interestRate,
          maturityDate: bondAsset.maturityDate,
        );
      case AssetType.gold:
        final goldAsset = asset as GoldAsset;
        return GoldAsset(
          id: goldAsset.id,
          name: goldAsset.name,
          quantity: newQuantity,
          purchasePrice: goldAsset.purchasePrice,
          purchaseDate: goldAsset.purchaseDate,
          currentPrice: goldAsset.currentPrice,
          unit: goldAsset.unit,
          storageLocation: goldAsset.storageLocation,
        );
    }
  }

  // 판매된 자산 생성 (판매 이력용)
  Asset _createSoldAsset(Asset asset, double soldQuantity, double sellPrice) {
    switch (asset.type) {
      case AssetType.stock:
        final stockAsset = asset as StockAsset;
        return StockAsset(
          id: '${stockAsset.id}_sold_${DateTime.now().millisecondsSinceEpoch}',
          symbol: stockAsset.symbol,
          name: '${stockAsset.name} (판매)',
          quantity: soldQuantity,
          purchasePrice: stockAsset.purchasePrice,
          purchaseDate: stockAsset.purchaseDate,
          currentPrice: sellPrice,
          exchange: stockAsset.exchange,
        );
      case AssetType.cash:
        final cashAsset = asset as CashAsset;
        return CashAsset(
          id: '${cashAsset.id}_sold_${DateTime.now().millisecondsSinceEpoch}',
          name: '${cashAsset.name} (출금)',
          quantity: soldQuantity,
          purchaseDate: cashAsset.purchaseDate,
          currency: cashAsset.currency,
          accountType: cashAsset.accountType,
        );
      case AssetType.bond:
        final bondAsset = asset as BondAsset;
        return BondAsset(
          id: '${bondAsset.id}_sold_${DateTime.now().millisecondsSinceEpoch}',
          name: '${bondAsset.name} (판매)',
          quantity: soldQuantity,
          purchasePrice: bondAsset.purchasePrice,
          purchaseDate: bondAsset.purchaseDate,
          currentPrice: sellPrice,
          issuer: bondAsset.issuer,
          interestRate: bondAsset.interestRate,
          maturityDate: bondAsset.maturityDate,
        );
      case AssetType.gold:
        final goldAsset = asset as GoldAsset;
        return GoldAsset(
          id: '${goldAsset.id}_sold_${DateTime.now().millisecondsSinceEpoch}',
          name: '${goldAsset.name} (판매)',
          quantity: soldQuantity,
          purchasePrice: goldAsset.purchasePrice,
          purchaseDate: goldAsset.purchaseDate,
          currentPrice: sellPrice,
          unit: goldAsset.unit,
          storageLocation: goldAsset.storageLocation,
        );
    }
  }

  // 판매 이력 저장 (향후 확장 가능)
  Future<void> _saveSaleHistory(Asset soldAsset, double sellPrice) async {
    // 판매 이력을 별도로 저장하는 로직
    // 현재는 간단히 로그만 출력
    print('판매 완료: ${soldAsset.name}, 수량: ${soldAsset.quantity}, 판매가: $sellPrice');
  }

  // 모든 자산 삭제
  Future<void> clearAllAssets() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_assetsKey);
  }

  // 자산 통계 계산
  Future<Map<String, dynamic>> getAssetStatistics() async {
    final assets = await getAssets();

    double totalPurchaseAmount = 0.0;
    double totalCurrentAmount = 0.0;
    Map<AssetType, double> assetTypeDistribution = {};
    Map<AssetType, int> assetTypeCount = {};

    for (final asset in assets) {
      totalPurchaseAmount += asset.purchasePrice * asset.quantity;
      totalCurrentAmount += asset.currentPrice * asset.quantity;

      assetTypeDistribution[asset.type] =
          (assetTypeDistribution[asset.type] ?? 0.0) + (asset.currentPrice * asset.quantity);
      assetTypeCount[asset.type] =
          (assetTypeCount[asset.type] ?? 0) + 1;
    }

    return {
      'totalAssets': assets.length,
      'totalPurchaseAmount': totalPurchaseAmount,
      'totalCurrentAmount': totalCurrentAmount,
      'totalProfitLoss': totalCurrentAmount - totalPurchaseAmount,
      'totalProfitLossRate': totalPurchaseAmount > 0
          ? ((totalCurrentAmount - totalPurchaseAmount) / totalPurchaseAmount) * 100
          : 0.0,
      'assetTypeDistribution': assetTypeDistribution,
      'assetTypeCount': assetTypeCount,
    };
  }
}