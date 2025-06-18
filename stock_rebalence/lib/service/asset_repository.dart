// lib/service/asset_repository.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stock_rebalence/models/asset.dart';

class AssetRepository {
  static const String _assetsKey = 'user_assets';

  Future<void> saveAssets(List<Asset> assets) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> assetsJson = assets.map((asset) => jsonEncode(asset.toJson())).toList();
    await prefs.setStringList(_assetsKey, assetsJson);
  }

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

  Future<List<Asset>> getAssetsByType(AssetType type) async {
    final assets = await getAssets();
    return assets.where((asset) => asset.type == type).toList();
  }

  Future<Asset?> getAssetById(String id) async {
    final assets = await getAssets();
    try {
      return assets.firstWhere((asset) => asset.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<bool> addAsset(Asset asset) async {
    List<Asset> assets = await getAssets();

    if (asset.type == AssetType.stock) {
      final stockAsset = asset as StockAsset;
      final existingIndex = assets.indexWhere((existingAsset) =>
      existingAsset.type == AssetType.stock &&
          (existingAsset as StockAsset).symbol.toLowerCase() == stockAsset.symbol.toLowerCase()
      );

      if (existingIndex != -1) {
        final existingStock = assets[existingIndex] as StockAsset;
        final totalQuantity = existingStock.quantity + stockAsset.quantity;
        final totalValue = (existingStock.quantity * existingStock.purchasePrice) +
            (stockAsset.quantity * stockAsset.purchasePrice);
        final newAveragePrice = totalValue / totalQuantity;

        final updatedStock = StockAsset(
          id: existingStock.id,
          symbol: existingStock.symbol,
          name: existingStock.name.isNotEmpty ? existingStock.name : stockAsset.name,
          quantity: totalQuantity,
          purchasePrice: newAveragePrice,
          purchaseDate: existingStock.purchaseDate,
          currentPrice: stockAsset.currentPrice,
          exchange: existingStock.exchange,
        );

        assets[existingIndex] = updatedStock;
        await saveAssets(assets);
        return false;
      }
    }

    assets.add(asset);
    await saveAssets(assets);
    return true;
  }

  Future<void> updateAsset(Asset updatedAsset) async {
    List<Asset> assets = await getAssets();
    int index = assets.indexWhere((asset) => asset.id == updatedAsset.id);
    if (index != -1) {
      assets[index] = updatedAsset;
      await saveAssets(assets);
    }
  }

  Future<void> deleteAsset(String id) async {
    List<Asset> assets = await getAssets();
    assets.removeWhere((asset) => asset.id == id);
    await saveAssets(assets);
  }

  Future<void> sellAsset(String id, double quantityToSell, double sellPrice) async {
    List<Asset> assets = await getAssets();
    int index = assets.indexWhere((asset) => asset.id == id);

    if (index != -1) {
      Asset asset = assets[index];
      if (asset.quantity >= quantityToSell) {
        Asset soldAsset = _createSoldAsset(asset, quantityToSell, sellPrice);

        Asset updatedAsset = _updateAssetQuantity(asset, asset.quantity - quantityToSell);

        if (updatedAsset.quantity <= 0) {
          assets.removeAt(index);
        } else {
          assets[index] = updatedAsset;
        }

        await _saveSaleHistory(soldAsset, sellPrice);
        await saveAssets(assets);
      }
    }
  }

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

  Future<void> _saveSaleHistory(Asset soldAsset, double sellPrice) async {
    print('판매 완료: ${soldAsset.name}, 수량: ${soldAsset.quantity}, 판매가: $sellPrice');
  }

  Future<void> clearAllAssets() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_assetsKey);
  }

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