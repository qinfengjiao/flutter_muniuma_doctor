import 'package:flutter/material.dart';
import 'package:flutter_muniuma_doctor/core/network/api_client.dart';
import 'package:flutter_muniuma_doctor/features/auth/login_page.dart';
import 'package:flutter_muniuma_doctor/features/place_order/place_order_repository.dart';
import 'package:flutter_muniuma_doctor/features/place_order/place_order_ui.dart';
import 'package:flutter_muniuma_doctor/features/place_order/tooth_picker_page.dart';

class ProductSelectPage extends StatefulWidget {
  const ProductSelectPage({
    super.key,
    required this.repo,
    required this.factoryHospitalId,
    required this.factoryId,
    required this.doctorId,
  });

  final PlaceOrderRepository repo;
  final String factoryHospitalId;
  final String factoryId;
  final String doctorId;

  @override
  State<ProductSelectPage> createState() => _ProductSelectPageState();
}

class _ProductSelectPageState extends State<ProductSelectPage> {
  final _search = TextEditingController();
  List<Map<String, dynamic>> _labels = [];
  List<Map<String, dynamic>> _types = [];
  List<Map<String, dynamic>> _products = [];
  int _labelIndex = 0;
  int _typeIndex = 0;
  bool _loading = true;
  bool _searching = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLabels();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadLabels() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final labels = await widget.repo.productLabels(widget.factoryHospitalId);
      if (!mounted) return;
      setState(() => _labels = labels);
      if (labels.isEmpty) {
        setState(() {
          _loading = false;
          _error = '获取标签为空';
        });
        return;
      }
      await _loadTypes();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    }
  }

  Future<void> _loadTypes() async {
    final label = _labels[_labelIndex];
    setState(() => _loading = true);
    try {
      final types = await widget.repo.productTypes(
        factoryHospitalId: widget.factoryHospitalId,
        factoryId: widget.factoryId,
        typeLabelId: field(label, const ['typeLabelId', 'Id', 'id']),
      );
      if (!mounted) return;
      final flat = _flatten(types);
      setState(() {
        _types = flat;
        _typeIndex = 0;
        _products = [];
        _searching = false;
      });
      if (flat.isNotEmpty) {
        await _loadProducts();
      } else if (mounted) {
        setState(() => _loading = false);
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    }
  }

  List<Map<String, dynamic>> _flatten(List<Map<String, dynamic>> source) {
    final result = <Map<String, dynamic>>[];
    void walk(Map<String, dynamic> item) {
      final children = item['children'];
      if (children is List && children.isNotEmpty) {
        for (final child in children.whereType<Map>()) {
          walk(Map<String, dynamic>.from(child));
        }
      } else {
        result.add(item);
      }
    }

    for (final item in source) {
      walk(item);
    }
    return result;
  }

  Future<void> _loadProducts() async {
    if (_types.isEmpty) return;
    final label = _labels[_labelIndex];
    final type = _types[_typeIndex];
    setState(() => _loading = true);
    try {
      final list = await widget.repo.placeOrderProducts(
        factoryHospitalId: widget.factoryHospitalId,
        factoryId: widget.factoryId,
        typeLabelId: field(label, const ['typeLabelId', 'Id', 'id']),
        productTypeId: field(type, const ['Id', 'id']),
        doctorId: widget.doctorId,
      );
      if (!mounted) return;
      setState(() {
        _products = list;
        _loading = false;
        _searching = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    }
  }

  Future<void> _runSearch() async {
    final keyword = _search.text.trim();
    if (keyword.isEmpty) {
      await _loadProducts();
      return;
    }
    setState(() => _loading = true);
    try {
      final list = await widget.repo.searchProducts(
        factoryHospitalId: widget.factoryHospitalId,
        factoryId: widget.factoryId,
        keyword: keyword,
      );
      if (!mounted) return;
      setState(() {
        _products = list;
        _loading = false;
        _searching = true;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _tip(error.message);
    }
  }

  Future<void> _pick(Map<String, dynamic> group) async {
    final variants = _variants(group);
    if (variants.isEmpty) {
      _tip('该产品暂无可下单规格');
      return;
    }
    Map<String, dynamic> detail = variants.first;
    if (variants.length > 1) {
      final picked = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        builder: (context) => SafeArea(
          child: ListView(
            children: [
              const ListTile(title: Text('选择产品系列')),
              for (final item in variants)
                ListTile(
                  title: Text(_variantName(item)),
                  onTap: () => Navigator.pop(context, item),
                ),
            ],
          ),
        ),
      );
      if (picked == null || !mounted) return;
      detail = picked;
    }
    final product = await showToothPicker(context, group: group, detail: detail);
    if (product != null && mounted) Navigator.pop(context, product);
  }

  List<Map<String, dynamic>> _variants(Map<String, dynamic> group) {
    final raw = group['products'];
    if (raw is List) {
      return raw.whereType<Map>().map(Map<String, dynamic>.from).toList();
    }
    if (field(group, const ['productId', 'Id', 'id']).isNotEmpty) return [group];
    return const [];
  }

  String _variantName(Map<String, dynamic> item) {
    return field(item, const [
      'customName',
      'fullProductName',
      'productName',
      'productSerieName',
      'name',
    ]);
  }

  void _tip(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: orderPageBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('产品库'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: '搜索产品',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  onPressed: _runSearch,
                  icon: const Icon(Icons.arrow_forward),
                ),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (_) => _runSearch(),
            ),
          ),
          if (_labels.isNotEmpty && !_searching)
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: _labels.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, index) => ChoiceChip(
                  label: Text(
                    field(_labels[index], const ['typeLabelName', 'name']),
                  ),
                  selected: index == _labelIndex,
                  onSelected: (_) {
                    setState(() => _labelIndex = index);
                    _loadTypes();
                  },
                ),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : Row(
                        children: [
                          if (!_searching && _types.isNotEmpty)
                            SizedBox(
                              width: 108,
                              child: ListView.builder(
                                itemCount: _types.length,
                                itemBuilder: (_, index) {
                                  final selected = index == _typeIndex;
                                  return ListTile(
                                    selected: selected,
                                    selectedTileColor: Colors.white,
                                    tileColor: const Color(0xFFF2F7FA),
                                    title: Text(
                                      field(_types[index], const ['name', 'typeName']),
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: selected
                                            ? themeBlue
                                            : const Color(0xFF2C2C2E),
                                      ),
                                    ),
                                    onTap: () {
                                      setState(() => _typeIndex = index);
                                      _loadProducts();
                                    },
                                  );
                                },
                              ),
                            ),
                          Expanded(
                            child: _products.isEmpty
                                ? const Center(child: Text('暂无产品'))
                                : ListView.separated(
                                    itemCount: _products.length,
                                    separatorBuilder: (_, _) =>
                                        const Divider(height: 1),
                                    itemBuilder: (_, index) {
                                      final item = _products[index];
                                      final variants = _variants(item);
                                      final title = field(item, const [
                                        'name',
                                        'customName',
                                        'productName',
                                      ]);
                                      return Container(
                                        margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: const Color(0xFFE8EEF2)),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    title.isEmpty ? '未命名产品' : title,
                                                    style: const TextStyle(fontSize: 14),
                                                  ),
                                                  if (variants.isNotEmpty)
                                                    Text(
                                                      _variantName(variants.first),
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        color: Color(0xFF8E8E93),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            FilledButton(
                                              onPressed: () => _pick(item),
                                              style: FilledButton.styleFrom(
                                                backgroundColor: orderBlue,
                                                minimumSize: const Size(88, 32),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                              ),
                                              child: const Text('立即下单'),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}
