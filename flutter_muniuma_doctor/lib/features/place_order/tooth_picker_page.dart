import 'package:flutter/material.dart';
import 'package:flutter_muniuma_doctor/core/network/api_client.dart';
import 'package:flutter_muniuma_doctor/features/place_order/clasp_design_page.dart';
import 'package:flutter_muniuma_doctor/features/place_order/place_order_draft.dart';

enum _ToothMode { normal, rework, repair, repeat }

class _Slot {
  _Slot(this.code, this.rect);

  final String code;
  final Rect rect;
}

Future<OrderProduct?> showToothPicker(
  BuildContext context, {
  required Map<String, dynamic> group,
  required Map<String, dynamic> detail,
  OrderProduct? initial,
}) {
  return showModalBottomSheet<OrderProduct>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x33000000),
    builder: (context) {
      final top = MediaQuery.paddingOf(context).top + 44;
      return Padding(
        padding: EdgeInsets.only(top: top),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          child: ToothPickerPage(group: group, detail: detail, initial: initial),
        ),
      );
    },
  );
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
  final Set<String> _selected = {};
  final Set<String> _rework = {};
  final Set<String> _repair = {};
  final Set<String> _repeat = {};
  _ToothMode _mode = _ToothMode.normal;
  String? _dragCode;
  List<_Slot> _slots = const [];
  final List<String> _claspPaths = [];

  static const _newColor = Color(0xFF23A0FF);
  static const _reworkColor = Color(0xFFFA4D32);
  static const _repairColor = Color(0xFFFFAB1A);

  @override
  void initState() {
    super.initState();
    final grouped = <String, List<int>>{};
    for (final tooth in widget.initial?.teeth ?? const <OrderTooth>[]) {
      grouped.putIfAbsent(tooth.code, () => []).add(tooth.productionType);
    }
    for (final entry in grouped.entries) {
      final types = entry.value;
      _selected.add(entry.key);
      if (types.length > 1) _repeat.add(entry.key);
      if (types.contains(3)) {
        _repair.add(entry.key);
      } else if (types.contains(2) && !types.contains(1)) {
        _rework.add(entry.key);
      }
    }
    _claspPaths.addAll(widget.initial?.claspImagePaths ?? const []);
  }

  int _typeOf(String code) {
    if (_rework.contains(code)) return 2;
    if (_repair.contains(code)) return 3;
    return 1;
  }

  String _imageName(String code) {
    final tag = int.parse(code);
    final type = _typeOf(code);
    if (tag >= 11 && tag <= 18) {
      if (type == 2) return 'tootht_Left_top_rework$tag';
      if (type == 3) return 'tooth_Left_top_repair$tag';
      return 'tooth_Left_top$tag';
    }
    if (tag >= 21 && tag <= 28) {
      if (type == 2) return 'tooth_Right_Top_Rework$tag';
      if (type == 3) return 'tooth_Right_Top_repair$tag';
      return 'tooth_Right_Top$tag';
    }
    if (tag >= 31 && tag <= 38) {
      if (type == 2) return 'tooth_Right_bootom_rework$tag';
      if (type == 3) return 'tooth_Right_bootom_repair$tag';
      return 'tooth_Right_bottom$tag';
    }
    if (type == 2) return 'tooth_Left_bootom_rework$tag';
    if (type == 3) return 'tooth_Left_Bottom_repair$tag';
    return 'tooth_Left_Bottom$tag';
  }

  void _toggle(String code) {
    setState(() {
      if (_mode == _ToothMode.repeat) {
        if (!_selected.contains(code)) return;
        if (_repeat.contains(code)) {
          _repeat.remove(code);
        } else {
          _repeat.add(code);
        }
        return;
      }
      if (_mode == _ToothMode.normal) {
        if (_rework.contains(code) || _repair.contains(code)) {
          _selected.remove(code);
        }
        if (_selected.contains(code)) {
          _selected.remove(code);
          _rework.remove(code);
          _repair.remove(code);
          _repeat.remove(code);
        } else {
          _selected.add(code);
          _rework.remove(code);
          _repair.remove(code);
          _repeat.remove(code);
        }
        return;
      }
      final current = _mode == _ToothMode.rework ? _rework : _repair;
      final other = _mode == _ToothMode.rework ? _repair : _rework;
      if (_selected.contains(code) && !current.contains(code)) {
        _selected.remove(code);
      }
      if (_selected.contains(code) && current.contains(code)) {
        _selected.remove(code);
        _rework.remove(code);
        _repair.remove(code);
        _repeat.remove(code);
      } else {
        _selected.add(code);
        other.remove(code);
        current.add(code);
      }
    });
  }

  void _hit(Offset local, {required bool drag}) {
    final point = local - const Offset(16, 6);
    for (final slot in _slots.reversed) {
      if (!slot.rect.contains(point)) continue;
      if (drag && _dragCode == slot.code) return;
      _dragCode = slot.code;
      _toggle(slot.code);
      return;
    }
    if (!drag) _dragCode = null;
  }

  String get _tipText {
    return switch (_mode) {
      _ToothMode.rework => '请选择返工牙位',
      _ToothMode.repair => '请选择返修牙位',
      _ToothMode.repeat => '请选择重复牙位',
      _ToothMode.normal => '请选择新做牙位',
    };
  }

  List<InlineSpan> _quadrantSpans(int quadrant) {
    final min = quadrant * 10 + 1;
    final max = quadrant * 10 + 8;
    final items = <(int, Color)>[];
    for (final code in _selected) {
      final value = int.tryParse(code) ?? 0;
      if (value < min || value > max) continue;
      final digit = value % 10;
      final color = switch (_typeOf(code)) {
        2 => _reworkColor,
        3 => _repairColor,
        _ => _newColor,
      };
      items.add((digit, color));
      if (_repeat.contains(code)) items.add((digit, color));
    }
    final descending = quadrant == 1 || quadrant == 4;
    items.sort((a, b) => descending ? b.$1.compareTo(a.$1) : a.$1.compareTo(b.$1));
    return [
      for (final item in items)
        TextSpan(
          text: '${item.$1}',
          style: TextStyle(color: item.$2, fontSize: 12),
        ),
    ];
  }

  void _done() {
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请选择牙位')));
      return;
    }
    final product = OrderProduct(group: widget.group, detail: widget.detail);
    final codes = _selected.toList()
      ..sort((a, b) => (int.tryParse(b) ?? 0).compareTo(int.tryParse(a) ?? 0));
    for (final code in codes) {
      final type = _typeOf(code);
      product.teeth.add(OrderTooth(code, productionType: type));
      if (_repeat.contains(code)) {
        product.teeth.add(OrderTooth(code, productionType: type == 1 ? 2 : type));
      }
    }
    product.syncPlants();
    product.claspImagePaths.addAll(_claspPaths);
    product.claspDesignCos = widget.initial?.claspDesignCos ?? '';
    Navigator.pop(context, product);
  }

  void _showTips() {
    showDialog<void>(
      context: context,
      barrierColor: const Color(0x66000000),
      builder: (context) => Center(
        child: SizedBox(
          width: 275,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/place_order/tooth/icon_order_弹窗_说明.png',
                width: 275,
                height: 169,
                fit: BoxFit.fill,
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Image.asset(
                  'assets/place_order/tooth/icon_place_order_close_tips.png',
                  width: 32,
                  height: 32,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openClasp() async {
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请选择牙位')));
      return;
    }
    final paths = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(builder: (_) => ClaspDesignPage(teeth: _selected.toList())),
    );
    if (paths == null || !mounted) return;
    setState(() {
      _claspPaths
        ..clear()
        ..addAll(paths);
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = field(widget.detail, const [
      'customName',
      'fullProductName',
      'productName',
    ]);
    final name = title.isEmpty
        ? field(widget.group, const ['name', 'customName', 'productName'])
        : title;
    return Material(
      color: Colors.white,
      child: Column(
        children: [
          SizedBox(
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Text('选择牙位', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Image.asset('assets/place_order/icon_nav_back.png', width: 22, height: 22),
                  ),
                ),
                const Positioned(left: 0, right: 0, bottom: 0, child: Divider(height: 1, color: Color(0xFFF5F5F5))),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 26),
                  child: Column(
                    children: [
                      Container(
                        height: 44,
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        alignment: Alignment.centerLeft,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2294FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          name.isEmpty ? '未命名产品' : name,
                          maxLines: 2,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(child: _chart()),
                    ],
                  ),
                ),
                Positioned(
                  right: 24,
                  top: 26 + 44 + 29,
                  child: GestureDetector(
                    onTap: _showTips,
                    child: const Row(
                      children: [
                        _AssetIcon('icon_place_order_blue_tips', 14),
                        SizedBox(width: 2),
                        Text('说明', style: TextStyle(color: Color(0xFF0081FF), fontSize: 10)),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  right: 20,
                  bottom: 0,
                  child: GestureDetector(
                    onTap: _openClasp,
                    child: Image.asset(
                      'assets/place_order/tooth/design_clasp.png',
                      width: 68,
                      height: 68,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Expanded(child: _modeButton(_ToothMode.rework)),
                  const SizedBox(width: 8),
                  Expanded(child: _modeButton(_ToothMode.repair)),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 87,
                    height: 48,
                    child: FilledButton(
                      onPressed: _done,
                      style: FilledButton.styleFrom(
                        backgroundColor: _selected.isEmpty ? const Color(0xFFD5D5D5) : const Color(0xFF0081FF),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: EdgeInsets.zero,
                      ),
                      child: const Text('下一步', style: TextStyle(fontSize: 16, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeButton(_ToothMode mode) {
    final selected = _mode == mode;
    final rework = mode == _ToothMode.rework;
    return SizedBox(
      height: 48,
      child: FilledButton(
        onPressed: () => setState(() {
          _mode = selected ? _ToothMode.normal : mode;
        }),
        style: FilledButton.styleFrom(
          backgroundColor: rework
              ? (selected ? const Color(0xFFFFC3BA) : const Color(0xFFFFF4F2))
              : (selected ? const Color(0xFFFFEECC) : const Color(0xFFFFF7E8)),
          foregroundColor: rework
              ? (selected ? const Color(0xFFFF1F00) : _reworkColor)
              : (selected ? const Color(0xFFFFA100) : _repairColor),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: EdgeInsets.zero,
        ),
        child: Text(rework ? '选择返工牙位' : '选择返修牙位', style: const TextStyle(fontSize: 16)),
      ),
    );
  }

  Widget _chart() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final imageWidth = constraints.maxWidth - 32;
        final imageHeight = imageWidth * 476 / 345;
        _slots = _layout(imageWidth, imageHeight);
        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: GestureDetector(
            onTapDown: (details) => _hit(details.localPosition, drag: false),
            onPanStart: (details) {
              _dragCode = null;
              _hit(details.localPosition, drag: true);
            },
            onPanUpdate: (details) => _hit(details.localPosition, drag: true),
            onPanEnd: (_) => _dragCode = null,
            child: SizedBox(
              height: imageHeight + 26,
              width: constraints.maxWidth,
              child: Stack(
                children: [
                  Positioned(
                    left: 16,
                    top: 6,
                    width: imageWidth,
                    height: imageHeight,
                    child: Image.asset(
                      'assets/place_order/tooth/img_yawei_n.png',
                      fit: BoxFit.fill,
                    ),
                  ),
                  for (final slot in _slots)
                    if (_selected.contains(slot.code))
                      Positioned(
                        left: 16 + slot.rect.left,
                        top: 6 + slot.rect.top,
                        width: slot.rect.width,
                        height: slot.rect.height,
                        child: Image.asset(
                          'assets/place_order/tooth/${_imageName(slot.code)}.png',
                          fit: BoxFit.fill,
                        ),
                      ),
                  Positioned(
                    left: 16,
                    top: 6,
                    width: imageWidth,
                    height: imageHeight,
                    child: _centerMarks(imageWidth, imageHeight),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _centerMarks(double width, double height) {
    const labelStyle = TextStyle(fontSize: 12, height: 1);
    return Stack(
      children: [
        Center(
          child: Text(
            _tipText,
            style: const TextStyle(color: Color(0xFFCBCBCB), fontSize: 18, fontWeight: FontWeight.w500),
          ),
        ),
        Positioned(
          right: width / 2 + 7,
          top: height / 2 - 9 - 29,
          left: 8,
          height: 29,
          child: Text.rich(
            TextSpan(children: _quadrantSpans(1)),
            textAlign: TextAlign.right,
            style: labelStyle,
          ),
        ),
        Positioned(
          left: width / 2 + 7,
          top: height / 2 - 9 - 29,
          width: 100,
          height: 29,
          child: Text.rich(TextSpan(children: _quadrantSpans(2)), style: labelStyle),
        ),
        Positioned(
          left: width / 2 + 7,
          top: height / 2 + 9,
          width: 100,
          height: 29,
          child: Text.rich(TextSpan(children: _quadrantSpans(3)), style: labelStyle),
        ),
        Positioned(
          right: width / 2 + 7,
          top: height / 2 + 9,
          left: 8,
          height: 29,
          child: Text.rich(
            TextSpan(children: _quadrantSpans(4)),
            textAlign: TextAlign.right,
            style: labelStyle,
          ),
        ),
        Positioned(
          top: height / 2 + 9 + 60,
          left: 0,
          right: 0,
          child: Center(child: _repeatButton()),
        ),
      ],
    );
  }

  Widget _repeatButton() {
    final selected = _mode == _ToothMode.repeat;
    return GestureDetector(
      onTap: () => setState(() {
        _mode = selected ? _ToothMode.normal : _ToothMode.repeat;
      }),
      child: Container(
        width: 126,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF0081FF) : const Color(0xFFD5D5D5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text('重复牙位', style: TextStyle(color: Colors.white, fontSize: 16)),
      ),
    );
  }

  List<_Slot> _layout(double width, double height) {
    double s(double value) => value / 345 * width;
    final boxes = <String, Rect>{};
    Rect box(String code, double left, double top, double size) {
      final rect = Rect.fromLTWH(left, top, size, size);
      boxes[code] = rect;
      return rect;
    }

    final b18 = box('18', 0, height / 2 - s(3) - s(40), s(40));
    final b17 = box('17', b18.left, b18.top - s(1) - b18.width, b18.width);
    final b16 = box('16', b17.left, b17.top + s(2) - s(41), s(41));
    final b15 = box('15', b16.left + s(10), b16.top + s(3) - s(41), s(41));
    final b14 = box('14', b15.left + s(24), b15.top + s(9) - s(41), s(41));
    final b13 = box('13', b14.right - s(5), b14.top + s(19) - s(37), s(37));
    final b12 = box('12', b13.right - s(7), b13.top + s(22) - s(37), s(37));
    final b11 = box('11', b12.right - s(1), b12.bottom - s(5) - s(37), s(37));
    final b21 = box('21', b11.right, b11.bottom - s(36), s(36));
    final b22 = box('22', b21.right - s(2), b21.top + s(5), s(36));
    final b23 = box('23', b22.right - s(5), b22.top + s(14), s(36));
    final b24 = box('24', b23.right - s(5), b23.top + s(18), s(41));
    final b25 = box('25', b24.right - s(17), b24.bottom - s(9), s(41));
    final b26 = box('26', b25.left + s(10), b25.bottom - s(3), s(41));
    final b27 = box('27', b26.left + s(1), b26.bottom - s(1), s(41));
    final b28 = box('28', b27.left - s(1), b27.bottom, s(41));
    final b38 = box('38', b28.left, b28.bottom + s(1), s(41));
    final b37 = box('37', b38.left, b38.bottom + s(1), s(41));
    final b36 = box('36', b37.left, b37.bottom - s(1), s(41));
    final b35 = box('35', b36.left - s(11), b36.bottom - s(4), s(41));
    final b34 = box('34', b35.left - s(23), b35.bottom - s(9), s(41));
    final b33 = box('33', b34.left + s(6) - s(37), b34.bottom - s(20), s(37));
    final b32 = box('32', b33.left + s(6) - s(37), b33.bottom - s(24), s(37));
    final b31 = box('31', b32.left + s(2) - s(36), b32.top + s(8), s(36));
    final b41 = box('41', width / 2 - s(1) - s(36), b31.top, s(36));
    final b42 = box('42', b41.left + s(1) - s(36), b41.top - s(6), s(36));
    final b43 = box('43', b42.left + s(5) - s(36), b42.top - s(14), s(36));
    final b44 = box('44', b43.left + s(6) - s(42), b43.top - s(23), s(42));
    final b45 = box('45', b44.left + s(18) - s(42), b44.top + s(11) - s(42), s(42));
    final b46 = box('46', b45.right - s(10) - s(42), b45.top + s(3) - s(42), s(42));
    final b47 = box('47', b46.right - s(1) - s(40), b46.top + s(2) - s(40), s(40));
    box('48', b47.right - s(40), b47.top - s(1) - s(40), s(40));
    return [for (final entry in boxes.entries) _Slot(entry.key, entry.value)];
  }
}

class _AssetIcon extends StatelessWidget {
  const _AssetIcon(this.name, this.size);

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset('assets/place_order/$name.png', width: size, height: size);
  }
}
