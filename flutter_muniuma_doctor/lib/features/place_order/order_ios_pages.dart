import 'package:flutter/material.dart';
import 'package:flutter_muniuma_doctor/core/network/api_client.dart';
import 'package:flutter_muniuma_doctor/features/place_order/place_order_draft.dart';
import 'package:flutter_muniuma_doctor/features/place_order/place_order_repository.dart';
import 'package:flutter_muniuma_doctor/features/place_order/place_order_ui.dart';

const _zones = <String, String>{
  '颈': 'colorNeck',
  '中': 'colorMid',
  '切': 'colorCut',
  '基牙颜色': 'colorAbutment',
  '牙龈色': 'colorGum',
};

const _operationTimes = <int, String>{1: '一周', 2: '二周', 3: '三周', 4: '三周后'};

List<String> orderToothCodes(PlaceOrderDraft draft) {
  final teeth = <String>{};
  for (final product in draft.products) {
    teeth.addAll(product.tooth.split('|').where((item) => item.isNotEmpty));
  }
  final list = teeth.toList()
    ..sort((a, b) => (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0));
  return list;
}

List<String> _productIds(PlaceOrderDraft draft) {
  return draft.products.map((item) => item.productId).where((item) => item.isNotEmpty).toList();
}

Future<bool> showColorPlate(BuildContext context, PlaceOrderRepository repo, PlaceOrderDraft draft) async {
  final changed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ColorPlateSheet(repo: repo, draft: draft),
  );
  return changed == true;
}

Future<bool> showColorDetail(BuildContext context, PlaceOrderRepository repo, PlaceOrderDraft draft) async {
  final changed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ColorDetailSheet(repo: repo, draft: draft),
  );
  return changed == true;
}

Future<bool> showCoupons(BuildContext context, OrderProduct product) async {
  if (product.coupons.isEmpty) return false;
  final changed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CouponSheet(product: product),
  );
  return changed == true;
}

class PlantDetailPage extends StatefulWidget {
  const PlantDetailPage({super.key, required this.repo, required this.draft});

  final PlaceOrderRepository repo;
  final PlaceOrderDraft draft;

  @override
  State<PlantDetailPage> createState() => _PlantDetailPageState();
}

class _PlantDetailPageState extends State<PlantDetailPage> {
  List<Map<String, dynamic>> _systems = [];
  List<Map<String, dynamic>> _implants = [];
  List<Map<String, dynamic>> _rods = [];
  List<String> _caps = [];
  bool _loading = true;
  int _index = 0;

  List<Map<String, dynamic>> get _plants => [
        for (final product in widget.draft.products.where((item) => item.isPlant))
          ...product.plants,
      ];

  @override
  void initState() {
    super.initState();
    _loadSystems();
  }

  Future<void> _loadSystems() async {
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
      await _loadTooth();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _tip(error.message);
    }
  }

  Future<void> _loadTooth() async {
    final plants = _plants;
    if (plants.isEmpty) return;
    final plant = plants[_index];
    final systemId = field(plant, const ['plantSystemId']);
    if (systemId.isEmpty) {
      setState(() {
        _implants = [];
        _rods = [];
        _caps = [];
      });
      return;
    }
    try {
      final implants = await widget.repo.plantImplants(systemId);
      final rods = asInt(plant['plantType']) == 2 ? await widget.repo.plantRods(systemId) : <Map<String, dynamic>>[];
      final implantId = field(plant, const ['plantImplantId']);
      final caps = _capsOf(implants, implantId);
      if (!mounted) return;
      setState(() {
        _implants = implants;
        _rods = rods;
        _caps = caps;
      });
    } on ApiException catch (error) {
      if (mounted) _tip(error.message);
    }
  }

  List<String> _capsOf(List<Map<String, dynamic>> implants, String implantId) {
    for (final item in implants) {
      if (field(item, const ['Id', 'id', 'plantImplantId']) != implantId) continue;
      return field(item, const ['healcapStr', 'plantHealcapName'])
          .split('|')
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return const [];
  }

  void _tip(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final plants = _plants;
    final current = plants.isEmpty ? null : plants[_index];
    return _IosSheet(
      title: '种植信息',
      onDone: () => Navigator.pop(context, true),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                _ToothChips(
                  teeth: [for (final plant in plants) field(plant, const ['toothSingle'])],
                  selected: current == null ? const {} : {field(current, const ['toothSingle'])},
                  onTap: (code) async {
                    final next = plants.indexWhere((item) => field(item, const ['toothSingle']) == code);
                    if (next < 0) return;
                    setState(() => _index = next);
                    await _loadTooth();
                  },
                ),
                if (current != null) ...[
                  _pickRow('种植系统', field(current, const ['plantSystemName']), () async {
                    final picked = await _pickList(_systems, const ['plantSystemName', 'name']);
                    if (picked == null) return;
                    setState(() {
                      current['plantSystemId'] = field(picked, const ['plantSystemId', 'Id', 'id']);
                      current['plantSystemName'] = field(picked, const ['plantSystemName', 'name']);
                      current['plantImplantId'] = '';
                      current['plantImplantName'] = '';
                      current['plantHealcapName'] = '';
                      current['plantRodId'] = '';
                      current['plantRodName'] = '';
                    });
                    await _loadTooth();
                  }),
                  _pickRow('植体型号', field(current, const ['plantImplantName']), () async {
                    final picked = await _pickList(_implants, const ['name', 'plantImplantName']);
                    if (picked == null) return;
                    setState(() {
                      current['plantImplantId'] = field(picked, const ['Id', 'id', 'plantImplantId']);
                      current['plantImplantName'] = field(picked, const ['name', 'plantImplantName']);
                      current['plantHealcapName'] = '';
                      _caps = _capsOf(_implants, field(current, const ['plantImplantId']));
                    });
                  }),
                  _pickRow('愈合帽', field(current, const ['plantHealcapName']), () async {
                    final name = await _pickText(_caps);
                    if (name == null) return;
                    setState(() => current['plantHealcapName'] = name);
                  }),
                  if (asInt(current['plantType']) == 2)
                    _pickRow('取模杆', field(current, const ['plantRodName']), () async {
                      final picked = await _pickList(_rods, const ['name', 'plantRodName']);
                      if (picked == null) return;
                      setState(() {
                        current['plantRodId'] = field(picked, const ['Id', 'id', 'plantRodId']);
                        current['plantRodName'] = field(picked, const ['name', 'plantRodName']);
                      });
                    })
                  else
                    _pickRow(
                      '二期手术时间',
                      _operationTimes[asInt(current['secondOperationTime'])] ?? '',
                      () async {
                        final picked = await _pickText(_operationTimes.values.toList());
                        if (picked == null) return;
                        final entry = _operationTimes.entries.firstWhere((item) => item.value == picked);
                        setState(() => current['secondOperationTime'] = entry.key);
                      },
                    ),
                ],
              ],
            ),
    );
  }

  Future<Map<String, dynamic>?> _pickList(List<Map<String, dynamic>> items, List<String> keys) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          children: [
            for (final item in items)
              ListTile(
                title: Text(field(item, keys).isEmpty ? '未命名' : field(item, keys)),
                onTap: () => Navigator.pop(context, item),
              ),
          ],
        ),
      ),
    );
  }

  Future<String?> _pickText(List<String> items) {
    return showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          children: [
            for (final item in items)
              ListTile(title: Text(item), onTap: () => Navigator.pop(context, item)),
          ],
        ),
      ),
    );
  }

  Widget _pickRow(String title, String value, VoidCallback onTap) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(fontSize: 14)),
      subtitle: Text(value.isEmpty ? '请选择' : value, style: TextStyle(color: value.isEmpty ? orderMuted : orderBlue)),
      trailing: const OrderIcon('icon_place_order_arrow_gray', width: 18, height: 18),
      onTap: onTap,
    );
  }
}

class DesignDetailPage extends StatefulWidget {
  const DesignDetailPage({super.key, required this.repo, required this.draft});

  final PlaceOrderRepository repo;
  final PlaceOrderDraft draft;

  @override
  State<DesignDetailPage> createState() => _DesignDetailPageState();
}

class _DesignDetailPageState extends State<DesignDetailPage> {
  final _teeth = <String>{};
  List<Map<String, dynamic>> _items = [];
  final _selected = <String>{};
  bool _pickingTooth = true;
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return _IosSheet(
      title: _pickingTooth ? '详细设计方案' : '选择设计',
      doneText: _pickingTooth ? '确定' : '保存设计',
      onDone: _pickingTooth ? _next : _save,
      child: _pickingTooth
          ? ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('选择详细设计的牙位', style: TextStyle(fontSize: 14, color: orderMuted)),
                const SizedBox(height: 12),
                _ToothChips(
                  teeth: orderToothCodes(widget.draft),
                  selected: _teeth,
                  onTap: (code) => setState(() {
                    if (!_teeth.add(code)) _teeth.remove(code);
                  }),
                ),
              ],
            )
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  children: [
                    for (final item in _items)
                      CheckboxListTile(
                        value: _selected.contains(field(item, const ['Id', 'id', 'designId'])),
                        title: Text(field(item, const ['name', 'designName', 'designsName'])),
                        activeColor: orderBlue,
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
    );
  }

  Future<void> _next() async {
    if (_teeth.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请选择牙位')));
      return;
    }
    setState(() {
      _pickingTooth = false;
      _loading = true;
    });
    try {
      final list = await widget.repo.designs(
        productIds: _productIds(widget.draft).join('|'),
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

  void _save() {
    final tooth = (_teeth.toList()..sort()).join('|');
    widget.draft.designs.removeWhere((item) => field(item, const ['tooth']) == tooth);
    widget.draft.designs.addAll(
      _items.where((item) => _selected.contains(field(item, const ['Id', 'id', 'designId']))).map((item) {
        return {...item, 'tooth': tooth};
      }),
    );
    Navigator.pop(context, true);
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
}

class ToothSegmentPage extends StatefulWidget {
  const ToothSegmentPage({super.key, required this.teeth, required this.initial});

  final List<String> teeth;
  final List<List<String>> initial;

  @override
  State<ToothSegmentPage> createState() => _ToothSegmentPageState();
}

class _ToothSegmentPageState extends State<ToothSegmentPage> {
  late final List<List<String>> _groups = [
    for (final group in widget.initial) [...group],
  ];
  int _current = 0;

  @override
  void initState() {
    super.initState();
    if (_groups.isEmpty) _groups.add([]);
  }

  void _tap(String code) {
    setState(() {
      for (final group in _groups) {
        group.remove(code);
      }
      _groups[_current].add(code);
      _groups.removeWhere((group) => group.isEmpty && _groups.length > 1 && group != _groups[_current]);
      _current = _groups.indexWhere((group) => group.contains(code));
    });
  }

  @override
  Widget build(BuildContext context) {
    return _IosSheet(
      title: '分段牙位',
      onDone: () {
        final groups = _groups.where((group) => group.isNotEmpty).toList();
        if (groups.expand((item) => item).toSet().length != widget.teeth.length) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('分段牙位未选取完全')));
          return;
        }
        Navigator.pop(context, groups);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('在牙位上点选，同一段的牙位使用同一种颜色。上下颌请分成不同段。', style: TextStyle(fontSize: 13, color: orderMuted)),
          const SizedBox(height: 12),
          _ToothChips(
            teeth: widget.teeth,
            selected: _groups[_current].toSet(),
            tint: (code) {
              for (var i = 0; i < _groups.length; i++) {
                if (_groups[i].contains(code)) return _segmentColors[i % _segmentColors.length];
              }
              return null;
            },
            onTap: _tap,
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => setState(() {
              _groups.add([]);
              _current = _groups.length - 1;
            }),
            child: const Text('新的一段'),
          ),
        ],
      ),
    );
  }
}

const _segmentColors = [
  Color(0xFF0083FF),
  Color(0xFFFA4D32),
  Color(0xFFFFAB1A),
  Color(0xFF30D03E),
  Color(0xFF7A5AF8),
];

class ExpressPlacePage extends StatefulWidget {
  const ExpressPlacePage({
    super.key,
    required this.repo,
    required this.orderId,
    required this.factoryId,
  });

  final PlaceOrderRepository repo;
  final String orderId;
  final String factoryId;

  @override
  State<ExpressPlacePage> createState() => _ExpressPlacePageState();
}

class _ExpressPlacePageState extends State<ExpressPlacePage> {
  final _receiveName = TextEditingController();
  final _receivePhone = TextEditingController();
  final _receiveAddress = TextEditingController();
  final _sendName = TextEditingController();
  final _sendPhone = TextEditingController();
  final _sendAddress = TextEditingController();
  int _pay = 1;
  bool _busy = false;

  @override
  void dispose() {
    _receiveName.dispose();
    _receivePhone.dispose();
    _receiveAddress.dispose();
    _sendName.dispose();
    _sendPhone.dispose();
    _sendAddress.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_receiveName.text.trim().isEmpty || _sendName.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请填写收寄件人')));
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.repo.placeExpress({
        'orderIds': [widget.orderId],
        'recipientContact': _receiveName.text.trim(),
        'recipientTel': _receivePhone.text.trim(),
        'recipientAddress': _receiveAddress.text.trim(),
        'senderContact': _sendName.text.trim(),
        'senderTel': _sendPhone.text.trim(),
        'senderAddress': _sendAddress.text.trim(),
        'paymentType': _pay,
        'isDocall': 1,
        'factoryId': widget.factoryId,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('下单成功')));
      Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _IosSheet(
      title: '下快递单',
      doneText: _busy ? '提交中' : '立即下单',
      onDone: _busy ? () {} : _submit,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _box('收件人', _receiveName),
          _box('收件电话', _receivePhone),
          _box('收件地址', _receiveAddress),
          _box('寄件人', _sendName),
          _box('寄件电话', _sendPhone),
          _box('寄件地址', _sendAddress),
          const Text('付款方式', style: TextStyle(fontSize: 14)),
          Wrap(
            spacing: 8,
            children: [
              for (final item in const {1: '寄付现结', 2: '寄付月结', 3: '到付现结'}.entries)
                ChoiceChip(
                  label: Text(item.value),
                  selected: _pay == item.key,
                  onSelected: (_) => setState(() => _pay = item.key),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _box(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: orderFieldBg,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide.none),
        ),
      ),
    );
  }
}

Future<void> showLinkExpress(
  BuildContext context, {
  required PlaceOrderRepository repo,
  required String orderId,
  required String factoryId,
}) async {
  List<Map<String, dynamic>> list;
  try {
    list = await repo.pendingExpress(factoryId);
  } on ApiException catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
    return;
  }
  if (!context.mounted) return;
  if (list.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('没有待揽收的快递')));
    return;
  }
  final picked = await showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    builder: (context) => SafeArea(
      child: ListView(
        children: [
          const ListTile(title: Text('关联快递')),
          for (final item in list)
            ListTile(
              title: Text(field(item, const ['logisticNo', 'mailNo', 'expressNo', 'no'])),
              subtitle: Text(field(item, const ['logisticName', 'expressName'])),
              onTap: () => Navigator.pop(context, item),
            ),
        ],
      ),
    ),
  );
  if (picked == null || !context.mounted) return;
  try {
    await repo.linkExpress(
      doctorExpressId: field(picked, const ['Id', 'id']),
      orderId: orderId,
      factoryId: factoryId,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('关联成功')));
    }
  } on ApiException catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

class _ColorPlateSheet extends StatefulWidget {
  const _ColorPlateSheet({required this.repo, required this.draft});

  final PlaceOrderRepository repo;
  final PlaceOrderDraft draft;

  @override
  State<_ColorPlateSheet> createState() => _ColorPlateSheetState();
}

class _ColorPlateSheetState extends State<_ColorPlateSheet> {
  List<Map<String, dynamic>> _groups = [];
  Map<String, dynamic>? _group;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final groups = await widget.repo.colorGroups(_productIds(widget.draft));
      if (!mounted) return;
      setState(() {
        _groups = groups;
        _group = groups.length == 1 ? groups.first : null;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  void _choose(Map<String, dynamic> color) {
    final teeth = orderToothCodes(widget.draft).join('|');
    final main = field(color, const ['code', 'colorName', 'name']);
    final mainId = field(color, const ['Id', 'id', 'colorId']);
    widget.draft.colors
      ..clear()
      ..add({
        'tooth': teeth,
        'colorMain': main,
        'colorMainId': mainId,
        'colorTypeName': _group == null ? '' : field(_group!, const ['colorTypeName', 'name']),
        'colorTypeId': _group == null ? '' : field(_group!, const ['colorTypeId', 'Id', 'id']),
      });
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = _colorsOf(_group);
    return _IosSheet(
      title: _group == null ? '添加色板' : field(_group!, const ['colorTypeName', 'name']),
      onDone: () => Navigator.pop(context),
      doneText: '关闭',
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_group == null)
                  for (final group in _groups)
                    ListTile(
                      title: Text(field(group, const ['colorTypeName', 'name'])),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => setState(() => _group = group),
                    )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final color in colors)
                        ActionChip(
                          label: Text(field(color, const ['code', 'colorName', 'name'])),
                          onPressed: () => _choose(color),
                        ),
                    ],
                  ),
              ],
            ),
    );
  }
}

class _ColorDetailSheet extends StatefulWidget {
  const _ColorDetailSheet({required this.repo, required this.draft});

  final PlaceOrderRepository repo;
  final PlaceOrderDraft draft;

  @override
  State<_ColorDetailSheet> createState() => _ColorDetailSheetState();
}

class _ColorDetailSheetState extends State<_ColorDetailSheet> {
  final _teeth = <String>{};
  String _zone = '颈';
  List<Map<String, dynamic>> _colors = [];
  bool _loading = false;
  final _values = <String, String>{};
  final _ids = <String, String>{};

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final groups = await widget.repo.colorGroups(
        _productIds(widget.draft),
        position: _zone == '基牙颜色' ? 2 : 1,
      );
      final colors = <Map<String, dynamic>>[];
      for (final group in groups) {
        colors.addAll(_colorsOf(group));
      }
      if (!mounted) return;
      setState(() {
        _colors = colors;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  void _save() {
    if (_teeth.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请选择牙位')));
      return;
    }
    final selected = _teeth.toList()..sort();
    final remain = <Map<String, dynamic>>[];
    Map<String, dynamic> base = {};
    for (final row in widget.draft.colors) {
      final teeth = field(row, const ['tooth']).split('|').where((item) => item.isNotEmpty).toList();
      final keep = teeth.where((item) => !_teeth.contains(item)).toList();
      final hit = teeth.where(_teeth.contains).toList();
      if (hit.isNotEmpty && base.isEmpty) base = Map<String, dynamic>.from(row);
      if (keep.isEmpty) continue;
      remain.add({...row, 'tooth': keep.join('|')});
    }
    final next = <String, dynamic>{
      ...base,
      'tooth': selected.join('|'),
    };
    for (final entry in _zones.entries) {
      final value = _values[entry.value] ?? '';
      if (value.isNotEmpty) {
        next[entry.value] = value;
        next['${entry.value}Id'] = _ids[entry.value] ?? '';
      }
    }
    widget.draft.colors
      ..clear()
      ..addAll([...remain, next]);
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return _IosSheet(
      title: '详细颜色',
      onDone: _save,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('选择需要单独配色的牙位', style: TextStyle(fontSize: 13, color: orderMuted)),
          const SizedBox(height: 8),
          _ToothChips(
            teeth: orderToothCodes(widget.draft),
            selected: _teeth,
            onTap: (code) => setState(() {
              if (!_teeth.add(code)) _teeth.remove(code);
            }),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final zone in _zones.keys)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(zone),
                      selected: _zone == zone,
                      onSelected: (_) {
                        setState(() => _zone = zone);
                        _load();
                      },
                    ),
                  ),
              ],
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final color in _colors)
                ActionChip(
                  label: Text(field(color, const ['code', 'colorName', 'name'])),
                  onPressed: () {
                    final key = _zones[_zone]!;
                    setState(() {
                      _values[key] = field(color, const ['code', 'colorName', 'name']);
                      _ids[key] = field(color, const ['Id', 'id', 'colorId']);
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _zones.entries.map((item) => '${item.key} ${_values[item.value] ?? '未选'}').join('  '),
            style: const TextStyle(fontSize: 12, color: orderInk),
          ),
        ],
      ),
    );
  }
}

class _CouponSheet extends StatefulWidget {
  const _CouponSheet({required this.product});

  final OrderProduct product;

  @override
  State<_CouponSheet> createState() => _CouponSheetState();
}

class _CouponSheetState extends State<_CouponSheet> {
  @override
  Widget build(BuildContext context) {
    return _IosSheet(
      title: '优惠券',
      onDone: () => Navigator.pop(context, true),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          for (final coupon in widget.product.coupons) _coupon(coupon),
        ],
      ),
    );
  }

  Widget _coupon(Map<String, dynamic> coupon) {
    final total = asInt(coupon['amount']);
    final used = asInt(coupon['useAmount']);
    final selected = asBool(coupon['selected']);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6EE),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFFD7B8)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 18,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: const Color(0xFFFF7F31), borderRadius: BorderRadius.circular(2)),
            child: const Text('产品券', style: TextStyle(color: Colors.white, fontSize: 9)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              field(coupon, const ['couponsName', 'couponName']),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          Text('共$total张', style: const TextStyle(fontSize: 12, color: orderMuted)),
          if (selected) ...[
            IconButton(
              onPressed: used <= 1 ? null : () => setState(() => coupon['useAmount'] = used - 1),
              icon: const Icon(Icons.remove, size: 16),
            ),
            Text('$used'),
            IconButton(
              onPressed: used >= total ? null : () => setState(() => coupon['useAmount'] = used + 1),
              icon: const Icon(Icons.add, size: 16),
            ),
          ],
          TextButton(
            onPressed: () => setState(() {
              coupon['selected'] = !selected;
              if (!selected && used == 0) coupon['useAmount'] = 1;
            }),
            child: Text(selected ? '取消' : '使用'),
          ),
        ],
      ),
    );
  }
}

class _IosSheet extends StatelessWidget {
  const _IosSheet({
    required this.title,
    required this.child,
    required this.onDone,
    this.doneText = '确认',
  });

  final String title;
  final Widget child;
  final VoidCallback onDone;
  final String doneText;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height * 0.86;
        return _sheet(context, height);
      },
    );
  }

  Widget _sheet(BuildContext context, double height) {
    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 20),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: child),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                height: 48,
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: orderBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  onPressed: onDone,
                  child: Text(doneText, style: const TextStyle(fontSize: 18)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToothChips extends StatelessWidget {
  const _ToothChips({
    required this.teeth,
    required this.selected,
    required this.onTap,
    this.tint,
  });

  final List<String> teeth;
  final Set<String> selected;
  final ValueChanged<String> onTap;
  final Color? Function(String code)? tint;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _row(teeth.where((item) => (int.tryParse(item) ?? 0) <= 28).toList()),
        const SizedBox(height: 8),
        _row(teeth.where((item) => (int.tryParse(item) ?? 0) > 28).toList()),
      ],
    );
  }

  Widget _row(List<String> codes) {
    if (codes.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final code in codes)
          GestureDetector(
            onTap: () => onTap(code),
            child: Container(
              width: 36,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected.contains(code) || tint?.call(code) != null
                    ? (tint?.call(code) ?? orderChipOn)
                    : orderChipBg,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                code,
                style: TextStyle(
                  color: selected.contains(code) || tint?.call(code) != null ? Colors.white : orderInk,
                  fontSize: 12,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

List<Map<String, dynamic>> _colorsOf(Map<String, dynamic>? group) {
  if (group == null) return const [];
  for (final key in ['color', 'colorList', 'colors', 'list']) {
    final value = group[key];
    if (value is List) {
      return value.whereType<Map>().map(Map<String, dynamic>.from).toList();
    }
  }
  return const [];
}
