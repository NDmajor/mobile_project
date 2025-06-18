// lib/pages/edit_asset_page.dart
import 'package:flutter/material.dart';
import 'package:stock_rebalence/models/asset.dart';
import 'package:stock_rebalence/service/asset_repository.dart';

class EditAssetPage extends StatefulWidget {
  final Asset asset;

  const EditAssetPage({super.key, required this.asset});

  @override
  State<EditAssetPage> createState() => _EditAssetPageState();
}

class _EditAssetPageState extends State<EditAssetPage> {
  final _formKey = GlobalKey<FormState>();
  final AssetRepository _assetRepository = AssetRepository();

  late TextEditingController _nameController;
  late TextEditingController _quantityController;
  late TextEditingController _purchasePriceController;
  late TextEditingController _currentPriceController;
  late TextEditingController _additional1Controller;
  late TextEditingController _additional2Controller;
  late TextEditingController _additional3Controller;

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    _nameController = TextEditingController(text: widget.asset.name);
    _quantityController = TextEditingController(text: widget.asset.quantity.toString());
    _purchasePriceController = TextEditingController(text: widget.asset.purchasePrice.toString());
    _currentPriceController = TextEditingController(text: widget.asset.currentPrice.toString());

    _additional1Controller = TextEditingController();
    _additional2Controller = TextEditingController();
    _additional3Controller = TextEditingController();

    switch (widget.asset.type) {
      case AssetType.stock:
        final stockAsset = widget.asset as StockAsset;
        _additional1Controller.text = stockAsset.symbol;
        _additional2Controller.text = stockAsset.exchange;
        break;
      case AssetType.cash:
        final cashAsset = widget.asset as CashAsset;
        _additional1Controller.text = cashAsset.currency;
        _additional2Controller.text = cashAsset.accountType;
        break;
      case AssetType.bond:
        final bondAsset = widget.asset as BondAsset;
        _additional1Controller.text = bondAsset.issuer;
        _additional2Controller.text = bondAsset.interestRate.toString();
        _additional3Controller.text = bondAsset.maturityDate.toIso8601String().split('T')[0];
        break;
      case AssetType.gold:
        final goldAsset = widget.asset as GoldAsset;
        _additional1Controller.text = goldAsset.unit;
        _additional2Controller.text = goldAsset.storageLocation;
        break;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _purchasePriceController.dispose();
    _currentPriceController.dispose();
    _additional1Controller.dispose();
    _additional2Controller.dispose();
    _additional3Controller.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final name = _nameController.text.trim();
      final quantity = double.tryParse(_quantityController.text) ?? 0;
      final purchasePrice = double.tryParse(_purchasePriceController.text) ?? 0;
      final currentPrice = double.tryParse(_currentPriceController.text) ?? 0;

      if (name.isEmpty || quantity <= 0 || purchasePrice <= 0 || currentPrice < 0) {
        setState(() {
          _isSaving = false;
          _errorMessage = '모든 필드를 올바르게 입력';
        });
        return;
      }

      Asset updatedAsset = _createUpdatedAsset(name, quantity, purchasePrice, currentPrice);
      await _assetRepository.updateAsset(updatedAsset);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.asset.type.displayName} 정보가 수정'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = '저장 중 오류가 발생: ${e.toString()}';
        });
      }
    }
  }

  Asset _createUpdatedAsset(String name, double quantity, double purchasePrice, double currentPrice) {
    switch (widget.asset.type) {
      case AssetType.stock:
        return StockAsset(
          id: widget.asset.id,
          symbol: _additional1Controller.text.trim(),
          name: name,
          quantity: quantity,
          purchasePrice: purchasePrice,
          purchaseDate: widget.asset.purchaseDate,
          currentPrice: currentPrice,
          exchange: _additional2Controller.text.trim(),
        );
      case AssetType.cash:
        return CashAsset(
          id: widget.asset.id,
          name: name,
          quantity: quantity,
          purchaseDate: widget.asset.purchaseDate,
          currency: _additional1Controller.text.trim(),
          accountType: _additional2Controller.text.trim(),
        );
      case AssetType.bond:
        return BondAsset(
          id: widget.asset.id,
          name: name,
          quantity: quantity,
          purchasePrice: purchasePrice,
          purchaseDate: widget.asset.purchaseDate,
          currentPrice: currentPrice,
          issuer: _additional1Controller.text.trim(),
          interestRate: double.tryParse(_additional2Controller.text) ?? 0.0,
          maturityDate: DateTime.tryParse(_additional3Controller.text) ?? widget.asset.purchaseDate,
        );
      case AssetType.gold:
        return GoldAsset(
          id: widget.asset.id,
          name: name,
          quantity: quantity,
          purchasePrice: purchasePrice,
          purchaseDate: widget.asset.purchaseDate,
          currentPrice: currentPrice,
          unit: _additional1Controller.text.trim(),
          storageLocation: _additional2Controller.text.trim(),
        );
    }
  }

  List<Widget> _buildAdditionalFields() {
    switch (widget.asset.type) {
      case AssetType.stock:
        return [
          const SizedBox(height: 16),
          TextFormField(
            controller: _additional1Controller,
            decoration: const InputDecoration(
              labelText: '종목 코드',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return '종목 코드를 입력';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _additional2Controller,
            decoration: const InputDecoration(
              labelText: '거래소',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return '거래소를 입력';
              }
              return null;
            },
          ),
        ];
      case AssetType.cash:
        return [
          const SizedBox(height: 16),
          TextFormField(
            controller: _additional1Controller,
            decoration: const InputDecoration(
              labelText: '통화',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return '통화를 입력';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _additional2Controller,
            decoration: const InputDecoration(
              labelText: '계좌 유형',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return '계좌 유형을 입력';
              }
              return null;
            },
          ),
        ];
      case AssetType.bond:
        return [
          const SizedBox(height: 16),
          TextFormField(
            controller: _additional1Controller,
            decoration: const InputDecoration(
              labelText: '발행기관',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return '발행기관을 입력';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _additional2Controller,
            decoration: const InputDecoration(
              labelText: '금리 (%)',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return '금리를 입력';
              }
              if (double.tryParse(value) == null) {
                return '유효한 금리를 입력';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _additional3Controller,
            decoration: const InputDecoration(
              labelText: '만기일 (YYYY-MM-DD)',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return '만기일을 입력';
              }
              if (DateTime.tryParse(value) == null) {
                return '올바른 날짜 형식을 입력 (YYYY-MM-DD)';
              }
              return null;
            },
          ),
        ];
      case AssetType.gold:
        return [
          const SizedBox(height: 16),
          TextFormField(
            controller: _additional1Controller,
            decoration: const InputDecoration(
              labelText: '단위',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return '단위를 입력';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _additional2Controller,
            decoration: const InputDecoration(
              labelText: '보관 장소',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return '보관 장소를 입력';
              }
              return null;
            },
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.asset.type.displayName} 정보 수정'),
        backgroundColor: isDarkMode ? Colors.grey[850] : Colors.white,
        elevation: 1,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '기본 정보',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: '자산 이름',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return '자산 이름을 입력';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _quantityController,
                        decoration: InputDecoration(
                          labelText: '보유 수량',
                          suffixText: _getQuantityUnit(widget.asset.type),
                          border: const OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return '보유 수량을 입력';
                          }
                          if (double.tryParse(value) == null || double.parse(value) <= 0) {
                            return '유효한 수량을 입력';
                          }
                          return null;
                        },
                      ),
                      if (widget.asset.type != AssetType.cash) ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _purchasePriceController,
                          decoration: const InputDecoration(
                            labelText: '매수가',
                            prefixText: '\$ ',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return '매수가를 입력';
                            }
                            if (double.tryParse(value) == null || double.parse(value) <= 0) {
                              return '유효한 매수가를 입력';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _currentPriceController,
                          decoration: const InputDecoration(
                            labelText: '현재가',
                            prefixText: '\$ ',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return '현재가를 입력';
                            }
                            if (double.tryParse(value) == null || double.parse(value) < 0) {
                              return '유효한 현재가를 입력';
                            }
                            return null;
                          },
                        ),
                      ],
                      ..._buildAdditionalFields(),
                    ],
                  ),
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    border: Border.all(color: Colors.red.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: const Text('취소'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveChanges,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                          : const Text(
                        '저장',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  border: Border.all(color: Colors.blue.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          '수정 안내',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• 모든 필드를 정확히 입력.\n• 주식의 경우 종목 코드 변경 시 주의.\n• 현재가는 자동으로 업데이트되지 않음 수동으로 수정.',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getQuantityUnit(AssetType type) {
    switch (type) {
      case AssetType.stock:
        return '주';
      case AssetType.cash:
        return '';
      case AssetType.bond:
        return '계약';
      case AssetType.gold:
        return '온스';
    }
  }
}