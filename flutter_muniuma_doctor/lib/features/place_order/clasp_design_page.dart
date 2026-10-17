import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_muniuma_doctor/features/place_order/place_order_ui.dart';

const _claspGroups = {
  '卡环': [
    '三臂卡环-近中',
    '三臂卡环-远中',
    '联合卡环',
    '环状卡环-近中',
    '环状卡环-远中',
    '单臂卡环远中+支托近中',
    '单臂卡环近中+支托远中',
    '冷弯卡环ww-远中',
    '冷弯卡环ww-近中',
    '回力卡环',
    '反回力卡环',
    '延伸卡环-近中',
  ],
  '支托': ['支托近中', '支托远中'],
  '其他': ['舌杆', '舌板', '近中邻面板', '远中邻面板'],
};

class ClaspDesignPage extends StatefulWidget {
  const ClaspDesignPage({super.key, required this.teeth});

  final List<String> teeth;

  @override
  State<ClaspDesignPage> createState() => _ClaspDesignPageState();
}

class _ClaspStroke {
  _ClaspStroke(this.points);

  final List<Offset> points;
}

class _ClaspDesignPageState extends State<ClaspDesignPage> {
  final _boundary = GlobalKey();
  int _step = 1;
  bool _lower = false;
  bool _drawing = false;
  final Map<String, String> _clasps = {};
  final List<_ClaspStroke> _strokes = [];
  final List<Map<String, String>> _claspHistory = [{}];
  final List<List<_ClaspStroke>> _strokeHistory = [[]];
  int _historyIndex = 0;

  List<String> get _upper => widget.teeth.where((item) {
        final value = int.tryParse(item) ?? 0;
        return value >= 11 && value <= 28;
      }).toList();

  List<String> get _lowerTeeth => widget.teeth.where((item) {
        final value = int.tryParse(item) ?? 0;
        return value >= 31 && value <= 48;
      }).toList();

  List<String> get _current => _lower ? _lowerTeeth : _upper;

  bool get _bothJaws => _upper.isNotEmpty && _lowerTeeth.isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (_upper.isEmpty) _lower = true;
  }

  void _remember() {
    _claspHistory.removeRange(_historyIndex + 1, _claspHistory.length);
    _strokeHistory.removeRange(_historyIndex + 1, _strokeHistory.length);
    _claspHistory.add(Map<String, String>.from(_clasps));
    _strokeHistory.add(_strokes.map((item) => _ClaspStroke(List<Offset>.from(item.points))).toList());
    _historyIndex = _claspHistory.length - 1;
  }

  void _restore(int index) {
    _clasps
      ..clear()
      ..addAll(_claspHistory[index]);
    _strokes
      ..clear()
      ..addAll(_strokeHistory[index].map((item) => _ClaspStroke(List<Offset>.from(item.points))));
    _historyIndex = index;
  }

  Future<void> _pickClasp(String code) async {
    final name = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _ClaspSheet(),
    );
    if (name == null) return;
    setState(() {
      _clasps[code] = name;
      _remember();
    });
  }

  Future<void> _finish() async {
    if (_clasps.isEmpty && _strokes.every((item) => item.points.length < 2)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先设计卡环或手绘')));
      return;
    }
    final paths = <String>[];
    Future<void> capture(bool lower) async {
      setState(() => _lower = lower);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      final boundary = _boundary.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) return;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/clasp_${lower ? 'lower' : 'upper'}_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(data.buffer.asUint8List());
      paths.add(file.path);
    }

    if (_upper.isNotEmpty) await capture(false);
    if (_lowerTeeth.isNotEmpty) await capture(true);
    if (!mounted) return;
    Navigator.pop(context, paths);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('开始设计'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                _stepImage(0, 'fixing_information', 'fixing_information_selected'),
                const SizedBox(width: 12),
                _stepImage(1, 'clasp_design', 'clasp_design_selected'),
                const SizedBox(width: 12),
                _stepImage(2, 'conjoined_design', 'conjoined_design_selected'),
              ],
            ),
          ),
          if (_bothJaws)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Expanded(child: _jawButton('上颌', false)),
                  Expanded(child: _jawButton('下颌', true)),
                ],
              ),
            ),
          Expanded(
            child: RepaintBoundary(
              key: _boundary,
              child: ColoredBox(
                color: Colors.white,
                child: Stack(
                  children: [
                    const Positioned(
                      left: 16,
                      right: 16,
                      top: 24,
                      child: Image(
                        image: AssetImage('assets/place_order/tooth/img_yawei_n.png'),
                        fit: BoxFit.contain,
                      ),
                    ),
                    Positioned.fill(
                      child: GestureDetector(
                        onPanStart: _drawing
                            ? (details) => setState(() => _strokes.add(_ClaspStroke([details.localPosition])))
                            : null,
                        onPanUpdate: _drawing
                            ? (details) => setState(() => _strokes.last.points.add(details.localPosition))
                            : null,
                        onPanEnd: _drawing ? (_) => _remember() : null,
                        child: CustomPaint(
                          painter: _StrokePainter(_strokes),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 250, 24, 90),
                            child: Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final code in _current)
                                  GestureDetector(
                                    onTap: _step == 0 || _drawing ? null : () => _pickClasp(code),
                                    child: Container(
                                      width: 64,
                                      padding: const EdgeInsets.symmetric(vertical: 6),
                                      decoration: BoxDecoration(
                                        color: _clasps.containsKey(code) ? const Color(0xFFE8F5FF) : Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: _clasps.containsKey(code) ? orderBlue : const Color(0xFFD5D5D5),
                                          width: 2,
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          Text(code, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                          if (_clasps[code] != null)
                                            Text(
                                              _clasps[code]!,
                                              maxLines: 2,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(fontSize: 9, color: orderTitleBlue),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_step != 0)
                      Positioned(
                        right: 16,
                        top: 12,
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: _historyIndex > 0 ? () => setState(() => _restore(_historyIndex - 1)) : null,
                              icon: Image.asset('assets/place_order/icon_previous_step.png', width: 24, height: 24),
                            ),
                            IconButton(
                              onPressed: _historyIndex < _claspHistory.length - 1
                                  ? () => setState(() => _restore(_historyIndex + 1))
                                  : null,
                              icon: Image.asset('assets/place_order/icon_next_steps.png', width: 24, height: 24),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (_step == 0)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: orderBlue),
                    onPressed: () => setState(() => _step = 1),
                    child: const Text('下一步'),
                  ),
                ),
              ),
            )
          else
            SafeArea(
              top: false,
              child: SizedBox(
                height: 70,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _tool('start_over', '重新开始', _clasps.isNotEmpty || _strokes.isNotEmpty, () {
                      setState(() {
                        _clasps.clear();
                        _strokes.clear();
                        _remember();
                      });
                    }),
                    _tool('hand_drawn', '手绘微调', true, () => setState(() => _drawing = !_drawing)),
                    _tool('design_complete', '完成设计', true, _finish, color: const Color(0xFF30D03E)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _stepImage(int step, String normal, String selected) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _step = step;
          _drawing = false;
        }),
        child: Image.asset(
          'assets/place_order/${_step == step ? selected : normal}.png',
          height: 36,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _jawButton(String title, bool lower) {
    final selected = _lower == lower;
    return GestureDetector(
      onTap: () => setState(() => _lower = lower),
      child: Container(
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? orderBlue : const Color(0xFFECF2F8),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(title, style: TextStyle(color: selected ? Colors.white : orderInk, fontSize: 14)),
      ),
    );
  }

  Widget _tool(String icon, String title, bool enabled, VoidCallback onTap, {Color color = orderInk}) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/place_order/$icon.png', width: 28, height: 28),
            const SizedBox(height: 2),
            Text(title, style: TextStyle(fontSize: 10, color: _drawing && title == '手绘微调' ? orderBlue : color)),
          ],
        ),
      ),
    );
  }
}

class _StrokePainter extends CustomPainter {
  _StrokePainter(this.strokes);

  final List<_ClaspStroke> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0081FF)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final stroke in strokes) {
      if (stroke.points.length < 2) continue;
      final path = Path()..moveTo(stroke.points.first.dx, stroke.points.first.dy);
      for (final point in stroke.points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StrokePainter oldDelegate) => true;
}

class _ClaspSheet extends StatefulWidget {
  const _ClaspSheet();

  @override
  State<_ClaspSheet> createState() => _ClaspSheetState();
}

class _ClaspSheetState extends State<_ClaspSheet> {
  String _group = '卡环';

  @override
  Widget build(BuildContext context) {
    final items = _claspGroups[_group]!;
    return SafeArea(
      child: SizedBox(
        height: 420,
        child: Column(
          children: [
            const SizedBox(height: 12),
            const Text('选择卡环', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            Row(
              children: [
                for (final name in _claspGroups.keys)
                  Expanded(
                    child: TextButton(
                      onPressed: () => setState(() => _group = name),
                      child: Text(
                        name,
                        style: TextStyle(color: _group == name ? orderBlue : orderMuted, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
              ],
            ),
            Expanded(
              child: ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, index) => ListTile(
                  title: Text(items[index]),
                  onTap: () => Navigator.pop(context, items[index]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
