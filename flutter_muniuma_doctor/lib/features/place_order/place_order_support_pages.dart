import 'package:flutter/material.dart';
import 'package:flutter_muniuma_doctor/core/network/api_client.dart';
import 'package:flutter_muniuma_doctor/features/auth/login_page.dart';
import 'package:flutter_muniuma_doctor/features/place_order/place_order_draft.dart';
import 'package:flutter_muniuma_doctor/features/place_order/place_order_repository.dart';
import 'package:flutter_muniuma_doctor/features/place_order/place_order_ui.dart';
import 'package:flutter_muniuma_doctor/features/workbench/sub_pages.dart';

class ColorEditPage extends StatefulWidget {
  const ColorEditPage({super.key, required this.repo, required this.draft});

  final PlaceOrderRepository repo;
  final PlaceOrderDraft draft;

  @override
  State<ColorEditPage> createState() => _ColorEditPageState();
}

class _ColorEditPageState extends State<ColorEditPage> {
  List<Map<String, dynamic>> _groups = [];
  bool _loading = true;
  final _main = TextEditingController();
  final _neck = TextEditingController();
  final _mid = TextEditingController();
  final _cut = TextEditingController();
  final _abutment = TextEditingController();
  final _custom = TextEditingController();
  String _mainId = '';

  @override
  void initState() {
    super.initState();
    final current = widget.draft.colors.isEmpty ? null : widget.draft.colors.first;
    if (current != null) {
      _main.text = field(current, const ['colorMain']);
      _mainId = field(current, const ['colorMainId']);
      _neck.text = field(current, const ['colorNeck']);
      _mid.text = field(current, const ['colorMid']);
      _cut.text = field(current, const ['colorCut']);
      _abutment.text = field(current, const ['colorAbutment']);
      _custom.text = field(current, const ['customize']);
    }
    _load();
  }

  @override
  void dispose() {
    _main.dispose();
    _neck.dispose();
    _mid.dispose();
    _cut.dispose();
    _abutment.dispose();
    _custom.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final ids = widget.draft.products
          .map((item) => item.productId)
          .where((item) => item.isNotEmpty)
          .toList();
      final groups = ids.isEmpty ? <Map<String, dynamic>>[] : await widget.repo.colorGroups(ids);
      if (!mounted) return;
      setState(() {
        _groups = groups;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _tip(error.message);
    }
  }

  void _save() {
    final teeth = <String>{};
    for (final product in widget.draft.products) {
      teeth.addAll(product.tooth.split('|').where((item) => item.isNotEmpty));
    }
    widget.draft.colors
      ..clear()
      ..add({
        'tooth': (teeth.toList()
              ..sort((a, b) => (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0)))
            .join('|'),
        'colorMain': _main.text.trim(),
        'colorMainId': _mainId,
        'colorNeck': _neck.text.trim(),
        'colorMid': _mid.text.trim(),
        'colorCut': _cut.text.trim(),
        'colorAbutment': _abutment.text.trim(),
        'customize': _custom.text.trim(),
      });
    Navigator.pop(context, true);
  }

  void _tip(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('颜色')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_loading) const LinearProgressIndicator(),
          if (_groups.isNotEmpty) ...[
            const Text('色板', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            for (final group in _groups) ...[
              Text(field(group, const ['colorTypeName', 'name', 'typeName'])),
              Wrap(
                spacing: 8,
                children: [
                  for (final color in _colorsOf(group))
                    ChoiceChip(
                      label: Text(field(color, const ['colorName', 'name', 'value'])),
                      selected: _main.text ==
                          field(color, const ['colorName', 'name', 'value']),
                      onSelected: (_) {
                        setState(() {
                          _main.text = field(color, const ['colorName', 'name', 'value']);
                          _mainId = field(color, const ['Id', 'id', 'colorId']);
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ],
          _field('主色', _main),
          _field('颈色', _neck),
          _field('中色', _mid),
          _field('切色', _cut),
          _field('基牙颜色', _abutment),
          _field('自定义', _custom),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(backgroundColor: themeBlue),
            child: const Text('保存颜色'),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _colorsOf(Map<String, dynamic> group) {
    for (final key in ['colorList', 'colors', 'list', 'items', 'details']) {
      final value = group[key];
      if (value is List) {
        return value.whereType<Map>().map(Map<String, dynamic>.from).toList();
      }
    }
    return const [];
  }

  Widget _field(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      ),
    );
  }
}

class PlantEditPage extends StatefulWidget {
  const PlantEditPage({super.key, required this.repo, required this.draft});

  final PlaceOrderRepository repo;
  final PlaceOrderDraft draft;

  @override
  State<PlantEditPage> createState() => _PlantEditPageState();
}

class _PlantEditPageState extends State<PlantEditPage> {
  List<Map<String, dynamic>> _systems = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await widget.repo.plantSystems(
        factoryHospitalId: widget.draft.factoryHospitalId,
        doctorId: widget.draft.doctorId,
      );
      if (!mounted) return;
      setState(() {
        _systems = list;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _pick(Map<String, dynamic> plant) async {
    if (asBool(plant['isDesignatedSystem'])) return;
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          children: [
            const ListTile(title: Text('选择种植系统')),
            for (final item in _systems)
              ListTile(
                title: Text(field(item, const ['plantSystemName', 'name', 'systemName'])),
                onTap: () => Navigator.pop(context, item),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    setState(() {
      plant['plantSystemId'] = field(picked, const ['plantSystemId', 'Id', 'id']);
      plant['plantSystemName'] =
          field(picked, const ['plantSystemName', 'name', 'systemName']);
      plant['plantType'] = asInt(picked['plantType']) == 0
          ? asInt(plant['plantType'])
          : asInt(picked['plantType']);
    });
  }

  @override
  Widget build(BuildContext context) {
    final plants = [
      for (final product in widget.draft.products.where((item) => item.isPlant))
        ...product.plants,
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('种植信息')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                for (final plant in plants)
                  ListTile(
                    title: Text('牙位 ${field(plant, const ['toothSingle'])}'),
                    subtitle: Text(
                      field(plant, const ['plantSystemName']).isEmpty
                          ? '请选择种植系统'
                          : field(plant, const ['plantSystemName']),
                    ),
                    trailing: asBool(plant['isDesignatedSystem'])
                        ? const Text('指定系统')
                        : const Icon(Icons.chevron_right),
                    onTap: () => _pick(plant),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: FilledButton.styleFrom(backgroundColor: themeBlue),
                    child: const Text('完成'),
                  ),
                ),
              ],
            ),
    );
  }
}

class DesignEditPage extends StatefulWidget {
  const DesignEditPage({super.key, required this.repo, required this.draft});

  final PlaceOrderRepository repo;
  final PlaceOrderDraft draft;

  @override
  State<DesignEditPage> createState() => _DesignEditPageState();
}

class _DesignEditPageState extends State<DesignEditPage> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  late final Set<String> _selected = {
    for (final item in widget.draft.designs)
      field(item, const ['Id', 'id', 'designId']),
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final ids = widget.draft.products.map((item) => item.productId).join('|');
      final list = await widget.repo.designs(
        productIds: ids,
        factoryId: widget.draft.factoryId,
      );
      if (!mounted) return;
      setState(() {
        _items = _flatten(list);
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  List<Map<String, dynamic>> _flatten(List<Map<String, dynamic>> source) {
    final result = <Map<String, dynamic>>[];
    void walk(Map<String, dynamic> item) {
      final id = field(item, const ['Id', 'id', 'designId']);
      final name = field(item, const ['name', 'designName', 'designsName']);
      if (id.isNotEmpty && name.isNotEmpty) result.add(item);
      for (final key in ['designList', 'list', 'children', 'designs']) {
        final value = item[key];
        if (value is List) {
          for (final child in value.whereType<Map>()) {
            walk(Map<String, dynamic>.from(child));
          }
        }
      }
    }

    for (final item in source) {
      walk(item);
    }
    return result;
  }

  void _save() {
    widget.draft.designs
      ..clear()
      ..addAll(_items.where((item) => _selected.contains(field(item, const ['Id', 'id', 'designId']))));
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设计')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: _items.isEmpty
                      ? const Center(child: Text('暂无设计'))
                      : ListView(
                          children: [
                            for (final item in _items)
                              CheckboxListTile(
                                value: _selected.contains(
                                  field(item, const ['Id', 'id', 'designId']),
                                ),
                                title: Text(
                                  field(item, const ['name', 'designName', 'designsName']),
                                ),
                                onChanged: (value) {
                                  final id = field(item, const ['Id', 'id', 'designId']);
                                  setState(() {
                                    if (value == true) {
                                      _selected.add(id);
                                    } else {
                                      _selected.remove(id);
                                    }
                                  });
                                },
                              ),
                          ],
                        ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _save,
                        style: FilledButton.styleFrom(backgroundColor: themeBlue),
                        child: const Text('保存设计'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class TrialEditPage extends StatefulWidget {
  const TrialEditPage({super.key, required this.repo, required this.draft});

  final PlaceOrderRepository repo;
  final PlaceOrderDraft draft;

  @override
  State<TrialEditPage> createState() => _TrialEditPageState();
}

class _TrialEditPageState extends State<TrialEditPage> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final ids = widget.draft.products
          .where((item) => item.isTrial)
          .map((item) => item.productId)
          .where((item) => item.isNotEmpty)
          .toList();
      final list = ids.isEmpty ? <Map<String, dynamic>>[] : await widget.repo.trials(ids);
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = widget.draft.products.where((item) => item.isTrial).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('试戴')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                for (final product in products)
                  RadioGroup<String>(
                    groupValue: product.trialId,
                    onChanged: (value) {
                      Map<String, dynamic>? trial;
                      for (final item in _items) {
                        if (field(item, const ['Id', 'id']) == value) trial = item;
                      }
                      setState(() {
                        product.trialId = value ?? '';
                        product.trialName = trial == null
                            ? ''
                            : field(trial, const ['name', 'trialName']);
                      });
                    },
                    child: Column(
                      children: [
                        ListTile(title: Text(product.name)),
                        for (final trial in _items)
                          RadioListTile<String>(
                            value: field(trial, const ['Id', 'id']),
                            title: Text(field(trial, const ['name', 'trialName'])),
                          ),
                      ],
                    ),
                  ),
                if (_items.isEmpty) const ListTile(title: Text('暂无试戴方案')),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: FilledButton.styleFrom(backgroundColor: themeBlue),
                    child: const Text('完成'),
                  ),
                ),
              ],
            ),
    );
  }
}

class AttachmentEditPage extends StatefulWidget {
  const AttachmentEditPage({super.key, required this.repo, required this.draft});

  final PlaceOrderRepository repo;
  final PlaceOrderDraft draft;

  @override
  State<AttachmentEditPage> createState() => _AttachmentEditPageState();
}

class _AttachmentEditPageState extends State<AttachmentEditPage> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await widget.repo.enclosures(widget.draft.factoryId);
      final selected = {
        for (final item in widget.draft.attachments)
          field(item, const ['Id', 'id']): asInt(item['number']),
      };
      for (final item in list) {
        item['number'] = selected[field(item, const ['Id', 'id'])] ?? 0;
      }
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  void _save() {
    widget.draft.attachments
      ..clear()
      ..addAll(_items.where((item) => asInt(item['number']) > 0));
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('附件')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    children: [
                      for (final item in _items)
                        ListTile(
                          title: Text(field(item, const ['name', 'enclosureName'])),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: asInt(item['number']) == 0
                                    ? null
                                    : () => setState(() {
                                          item['number'] = asInt(item['number']) - 1;
                                        }),
                                icon: const Icon(Icons.remove_circle_outline),
                              ),
                              Text('${asInt(item['number'])}'),
                              IconButton(
                                onPressed: () => setState(() {
                                  item['number'] = asInt(item['number']) + 1;
                                }),
                                icon: const Icon(Icons.add_circle_outline),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _save,
                        style: FilledButton.styleFrom(backgroundColor: themeBlue),
                        child: const Text('保存附件'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class ReasonPage extends StatefulWidget {
  const ReasonPage({super.key, required this.repo});

  final PlaceOrderRepository repo;

  @override
  State<ReasonPage> createState() => _ReasonPageState();
}

class _ReasonPageState extends State<ReasonPage> {
  List<Map<String, dynamic>> _types = [];
  List<Map<String, dynamic>> _items = [];
  int _index = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTypes();
  }

  Future<void> _loadTypes() async {
    try {
      final types = await widget.repo.phenomenonTypes();
      if (!mounted) return;
      setState(() => _types = types);
      if (types.isNotEmpty) await _loadItems();
      if (mounted) setState(() => _loading = false);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _loadItems() async {
    final type = _types[_index];
    try {
      final items = await widget.repo.phenomena(field(type, const ['Id', 'id']), 1);
      if (!mounted) return;
      setState(() => _items = items);
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('返工原因')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                SizedBox(
                  width: 120,
                  child: ListView.builder(
                    itemCount: _types.length,
                    itemBuilder: (_, index) => ListTile(
                      selected: index == _index,
                      title: Text(field(_types[index], const ['name'])),
                      onTap: () {
                        setState(() => _index = index);
                        _loadItems();
                      },
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      for (final item in _items)
                        ListTile(
                          title: Text(field(item, const ['name', 'phenomenonName'])),
                          onTap: () => Navigator.pop(context, item),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class AddressPage extends StatefulWidget {
  const AddressPage({
    super.key,
    required this.repo,
    required this.hospitalId,
    required this.factoryId,
    required this.currentId,
  });

  final PlaceOrderRepository repo;
  final String hospitalId;
  final String factoryId;
  final String currentId;

  @override
  State<AddressPage> createState() => _AddressPageState();
}

class _AddressPageState extends State<AddressPage> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await widget.repo.addresses(
        hospitalId: widget.hospitalId,
        factoryId: widget.factoryId,
      );
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _add() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddAddressPage(repo: widget.repo, hospitalId: widget.hospitalId),
      ),
    );
    if (created == true) _load();
  }

  String _line(Map<String, dynamic> item) {
    return [
      field(item, const ['province']),
      field(item, const ['city']),
      field(item, const ['district']),
      field(item, const ['detailAddr', 'address']),
    ].where((text) => text.isNotEmpty).join('');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('收货地址'),
        actions: [IconButton(onPressed: _add, icon: const Icon(Icons.add))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                if (_items.isEmpty) const ListTile(title: Text('请添加地址')),
                for (final item in _items)
                  ListTile(
                    title: Text(
                      '${field(item, const ['consignee', 'name'])}  ${field(item, const ['tel', 'phone'])}',
                    ),
                    subtitle: Text(_line(item)),
                    trailing: field(item, const ['Id', 'id']) == widget.currentId
                        ? const Icon(Icons.check, color: themeBlue)
                        : null,
                    onTap: () => Navigator.pop(context, item),
                  ),
              ],
            ),
    );
  }
}

class AddAddressPage extends StatefulWidget {
  const AddAddressPage({super.key, required this.repo, required this.hospitalId});

  final PlaceOrderRepository repo;
  final String hospitalId;

  @override
  State<AddAddressPage> createState() => _AddAddressPageState();
}

class _AddAddressPageState extends State<AddAddressPage> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _province = TextEditingController();
  final _city = TextEditingController();
  final _district = TextEditingController();
  final _detail = TextEditingController();
  bool _default = false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _province.dispose();
    _city.dispose();
    _district.dispose();
    _detail.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty ||
        _phone.text.trim().isEmpty ||
        _detail.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写收货人、电话和详细地址')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.repo.addAddress({
        'consignee': _name.text.trim(),
        'tel': _phone.text.trim(),
        'province': _province.text.trim(),
        'city': _city.text.trim(),
        'district': _district.text.trim(),
        'detailAddr': _detail.text.trim(),
        'isDefault': _default,
        'country': '',
        'hospitalId': widget.hospitalId,
      });
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('新增地址')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _box('收货人', _name),
          _box('电话', _phone, type: TextInputType.phone),
          _box('省', _province),
          _box('市', _city),
          _box('区', _district),
          _box('详细地址', _detail),
          SwitchListTile(
            value: _default,
            title: const Text('设为默认地址'),
            onChanged: (value) => setState(() => _default = value),
          ),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(backgroundColor: themeBlue),
            child: Text(_saving ? '保存中' : '保存'),
          ),
        ],
      ),
    );
  }

  Widget _box(String label, TextEditingController controller, {TextInputType? type}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: controller,
        keyboardType: type,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      ),
    );
  }
}

class SegmentPage extends StatefulWidget {
  const SegmentPage({super.key, required this.teeth, required this.initial});

  final List<String> teeth;
  final List<List<String>> initial;

  @override
  State<SegmentPage> createState() => _SegmentPageState();
}

class _SegmentPageState extends State<SegmentPage> {
  late final List<List<String>> _groups = [
    for (final group in widget.initial) [...group],
  ];
  final Set<String> _picking = {};

  Set<String> get _used => _groups.expand((item) => item).toSet();

  void _addGroup() {
    if (_picking.isEmpty) return;
    setState(() {
      final group = _picking.toList()
        ..sort((a, b) => (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0));
      _groups.add(group);
      _picking.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final remain = widget.teeth.where((item) => !_used.contains(item));
    return Scaffold(
      appBar: AppBar(title: const Text('分段牙位')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('先点选一组牙位，再加入分段。上下颌需要分开连体时请分成不同段。'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final tooth in remain)
                FilterChip(
                  label: Text(tooth),
                  selected: _picking.contains(tooth),
                  onSelected: (value) {
                    setState(() {
                      if (value) {
                        _picking.add(tooth);
                      } else {
                        _picking.remove(tooth);
                      }
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: _addGroup, child: const Text('加入分段')),
          const SizedBox(height: 12),
          for (var i = 0; i < _groups.length; i++)
            ListTile(
              title: Text(_groups[i].join(' | ')),
              trailing: IconButton(
                onPressed: () => setState(() => _groups.removeAt(i)),
                icon: const Icon(Icons.delete_outline),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.pop(context, _groups),
            style: FilledButton.styleFrom(backgroundColor: themeBlue),
            child: const Text('完成分段'),
          ),
        ],
      ),
    );
  }
}

class PlaceOrderSuccessPage extends StatelessWidget {
  const PlaceOrderSuccessPage({
    super.key,
    required this.result,
    required this.repo,
    required this.onContinue,
  });

  final Map<String, dynamic> result;
  final PlaceOrderRepository repo;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final mail = field(result, const ['mailNo']);
    final parts = mail.trim().isEmpty
        ? const <String>[]
        : mail.trim().split(RegExp(r'\s+'));
    final expect = field(result, const ['expectArrivalTime']);
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                SizedBox(
                  height: 224,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Positioned.fill(
                        child: OrderIcon('img_下单成功bg', fit: BoxFit.cover),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(top: 48),
                        child: Text(
                          '下单成功',
                          style: TextStyle(
                            color: orderTitleBlue,
                            fontSize: 32,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Text(
                    '请将以下 6位数寄件号 写到发货包装上发出',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
                if (parts.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(36, 24, 36, 0),
                    child: Row(
                      children: [
                        for (final part in parts)
                          Expanded(
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              height: 56,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF2F7FA),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                part,
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(29, 24, 29, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '订单号：${field(result, const ['no', 'orderNo'])}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0x73000000),
                        ),
                      ),
                      if (expect.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(expect, style: const TextStyle(fontSize: 14)),
                        ),
                      const SizedBox(height: 12),
                      Text(field(result, const ['factoryFullName', 'factoryName'])),
                      const SizedBox(height: 8),
                      Text('模型请寄至 ${field(result, const ['region', 'address'])}'),
                      Text(
                        '${field(result, const ['addressee', 'consignee'])} ${field(result, const ['addresseeTel', 'tel'])}',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF23A0FF),
                        side: const BorderSide(color: Color(0xFF23A0FF)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: () async {
                        final id = field(result, const ['Id', 'id', 'orderId']);
                        if (id.isEmpty) return;
                        try {
                          final detail = await repo.orderDetail(id);
                          if (!context.mounted) return;
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RecordDetailPage(
                                title: field(result, const ['no', 'orderNo']),
                                data: detail.isEmpty ? result : detail,
                              ),
                            ),
                          );
                        } on ApiException catch (error) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(error.message)),
                          );
                        }
                      },
                      child: const Text('查看订单'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: orderBlue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: onContinue,
                      child: const Text('继续下单'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          TextButton(onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst), child: const Text('返回首页')),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
