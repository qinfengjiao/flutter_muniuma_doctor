import 'package:flutter/material.dart';
import 'package:flutter_muniuma_doctor/core/network/api_client.dart';
import 'package:flutter_muniuma_doctor/features/auth/login_page.dart';
import 'package:flutter_muniuma_doctor/features/place_order/place_order_draft.dart';
import 'package:flutter_muniuma_doctor/features/place_order/place_order_repository.dart';

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
    final product = await Navigator.push<OrderProduct>(
      context,
      MaterialPageRoute(
        builder: (_) => ToothPickerPage(group: group, detail: detail),
      ),
    );
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
      appBar: AppBar(title: const Text('产品库')),
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
                                      return ListTile(
                                        title: Text(title.isEmpty ? '未命名产品' : title),
                                        subtitle: Text(
                                          variants.isEmpty
                                              ? ''
                                              : _variantName(variants.first),
                                        ),
                                        trailing: FilledButton(
                                          onPressed: () => _pick(item),
                                          style: FilledButton.styleFrom(
                                            backgroundColor: themeBlue,
                                          ),
                                          child: const Text('立即下单'),
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

class ToothPickerPage extends StatefulWidget {
  const ToothPickerPage({
    super.key,
    required this.group,
    required this.detail,
    this.initial,
  });

  final Map<String, dynamic> group;
  final Map<String, dynamic> detail;
  final OrderProduct? initial;

  @override
  State<ToothPickerPage> createState() => _ToothPickerPageState();
}

class _ToothPickerPageState extends State<ToothPickerPage> {
  late final Map<String, int> _selected = {
    for (final tooth in widget.initial?.teeth ?? const <OrderTooth>[])
      tooth.code: tooth.productionType,
  };
  int _type = 1;

  static const _upperRight = ['18', '17', '16', '15', '14', '13', '12', '11'];
  static const _upperLeft = ['21', '22', '23', '24', '25', '26', '27', '28'];
  static const _lowerRight = ['48', '47', '46', '45', '44', '43', '42', '41'];
  static const _lowerLeft = ['31', '32', '33', '34', '35', '36', '37', '38'];

  void _toggle(String code) {
    setState(() {
      if (_selected[code] == _type) {
        _selected.remove(code);
      } else {
        _selected[code] = _type;
      }
    });
  }

  void _done() {
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择牙位')),
      );
      return;
    }
    final product = OrderProduct(group: widget.group, detail: widget.detail);
    final codes = _selected.keys.toList()
      ..sort((a, b) => (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0));
    for (final code in codes) {
      product.teeth.add(OrderTooth(code, productionType: _selected[code]!));
    }
    product.syncPlants();
    Navigator.pop(context, product);
  }

  @override
  Widget build(BuildContext context) {
    final title = field(widget.detail, const [
      'customName',
      'fullProductName',
      'productName',
    ]);
    return Scaffold(
      appBar: AppBar(title: Text(title.isEmpty ? '选择牙位' : title)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 1, label: Text('新做')),
                ButtonSegment(value: 2, label: Text('返工')),
                ButtonSegment(value: 3, label: Text('返修')),
              ],
              selected: {_type},
              onSelectionChanged: (value) => setState(() => _type = value.first),
            ),
          ),
          const Text('点选牙位，再次点击相同类型可取消', style: TextStyle(color: Color(0xFF8E8E93))),
          const SizedBox(height: 12),
          _toothRow(_upperRight, _upperLeft),
          const Divider(height: 24),
          _toothRow(_lowerRight, _lowerLeft),
          const Spacer(),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _done,
                  style: FilledButton.styleFrom(backgroundColor: themeBlue),
                  child: Text('确定（${_selected.length}）'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toothRow(List<String> left, List<String> right) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          for (final code in left) _tooth(code),
          Container(width: 1, height: 36, color: const Color(0xFFD0D0D0)),
          for (final code in right) _tooth(code),
        ],
      ),
    );
  }

  Widget _tooth(String code) {
    final type = _selected[code];
    final color = switch (type) {
      2 => const Color(0xFFFF8A00),
      3 => const Color(0xFF8E5BFF),
      1 => themeBlue,
      _ => const Color(0xFFF2F7FA),
    };
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: InkWell(
          onTap: () => _toggle(code),
          child: Container(
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              code,
              style: TextStyle(
                fontSize: 11,
                color: type == null ? const Color(0xFF2C2C2E) : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
