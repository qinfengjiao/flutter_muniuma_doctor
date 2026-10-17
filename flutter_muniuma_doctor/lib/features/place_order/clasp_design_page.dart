import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_muniuma_doctor/features/place_order/place_order_ui.dart';

const _roundClasps = [
  '三臂卡环-近中',
  '联合卡环',
  '三臂卡环-远中',
  '环状卡环-近中',
  '环状卡环-远中',
  '单臂卡环远中+支托近中',
  '单臂卡环远中+支托远中',
  '单臂卡环近中+支托近中',
  '单臂卡环近中+支托远中',
  '单臂卡环远中+舌板',
  '单臂卡环近中+舌板',
  '冷弯卡环ww-远中',
  '冷弯卡环ww-近中',
  '回力卡环',
  '反回力卡环',
  '延伸卡环-近中',
  '延伸卡环-远中',
];

const _rodClasps = [
  'I杆-近中',
  'T杆-近中',
  'L杆-近中',
  'I杆-远中',
  'T杆-远中',
  'L杆-远中',
  'U杆-近中',
  'U杆-远中',
  'RPI卡环组',
  'RPA卡环组',
  'RPT卡环组',
  'RPL卡环组',
];

const _supportClasps = ['支托近中', '支托远中', '支托-近中', '支托-远中'];
const _otherClasps = ['近中邻面板', '远中邻面板', '舌杆', '舌板'];

class ClaspDesignPage extends StatefulWidget {
  const ClaspDesignPage({super.key, required this.teeth});

  final List<String> teeth;

  @override
  State<ClaspDesignPage> createState() => _ClaspDesignPageState();
}

class _ClaspMark {
  _ClaspMark(this.tag, this.asset);

  final int tag;
  final String asset;
}

class _Stroke {
  _Stroke({required this.width, required this.eraser});

  final List<Offset> points = [];
  final double width;
  final bool eraser;
}

class _ClaspDesignPageState extends State<ClaspDesignPage> {
  final _boundary = GlobalKey();
  bool _lower = false;
  bool _handDraw = false;
  bool _eraser = false;
  double _brushWidth = 3;
  Map<String, List<String>> _catalog = {};
  final Map<int, String> _clasps = {};
  final List<_ClaspMark> _upperHistory = [];
  final List<_ClaspMark> _lowerHistory = [];
  int _upperIndex = -1;
  int _lowerIndex = -1;
  final List<_Stroke> _upperStrokes = [];
  final List<_Stroke> _lowerStrokes = [];
  int _upperStrokeIndex = -1;
  int _lowerStrokeIndex = -1;
  _Stroke? _liveStroke;

  Set<int> get _missing {
    return widget.teeth.map(int.tryParse).whereType<int>().toSet();
  }

  bool get _hasUpper => _missing.any((item) => item >= 11 && item <= 28);
  bool get _hasLower => _missing.any((item) => item >= 31 && item <= 48);
  bool get _both => _hasUpper && _hasLower;

  List<_ClaspMark> get _history => _lower ? _lowerHistory : _upperHistory;
  int get _index => _lower ? _lowerIndex : _upperIndex;
  set _index(int value) {
    if (_lower) {
      _lowerIndex = value;
    } else {
      _upperIndex = value;
    }
  }

  List<_Stroke> get _strokes => _lower ? _lowerStrokes : _upperStrokes;
  int get _strokeIndex => _lower ? _lowerStrokeIndex : _upperStrokeIndex;
  set _strokeIndex(int value) {
    if (_lower) {
      _lowerStrokeIndex = value;
    } else {
      _upperStrokeIndex = value;
    }
  }

  List<_Stroke> get _visibleStrokes {
    if (_strokeIndex < 0) return const [];
    return _strokes.take(_strokeIndex + 1).toList();
  }

  bool get _hasWork => _clasps.isNotEmpty || _upperStrokeIndex >= 0 || _lowerStrokeIndex >= 0;

  @override
  void initState() {
    super.initState();
    if (!_hasUpper && _hasLower) _lower = true;
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    final raw = await rootBundle.loadString('assets/place_order/clasp_catalog.json');
    final decoded = jsonDecode(raw);
    if (decoded is! Map || !mounted) return;
    setState(() {
      _catalog = decoded.map((key, value) {
        final names = value is List ? value.map((item) => '$item').toList() : <String>[];
        return MapEntry('$key', names);
      });
    });
  }

  void _applyClasp(int tag, String name) {
    final imageTag = _imageTag(tag);
    final asset = 'assets/place_order/clasp/$imageTag-$name.png';
    setState(() {
      if (_index < _history.length - 1) {
        final removed = _history.sublist(_index + 1);
        _history.removeRange(_index + 1, _history.length);
        for (final item in removed) {
          if (!_history.any((kept) => kept.tag == item.tag)) _clasps.remove(item.tag);
        }
      }
      _clasps[tag] = asset;
      _history.add(_ClaspMark(tag, asset));
      _index = _history.length - 1;
      _syncVisible();
    });
  }

  void _syncVisible() {
    final hidden = <int>{};
    for (var i = _index + 1; i < _history.length; i++) {
      hidden.add(_history[i].tag);
    }
    final visible = <int, String>{};
    for (var i = 0; i <= _index && i < _history.length; i++) {
      if (!hidden.contains(_history[i].tag)) visible[_history[i].tag] = _history[i].asset;
    }
    final jawTags = _lower
        ? _clasps.keys.where((item) => item >= 31)
        : _clasps.keys.where((item) => item <= 28);
    for (final tag in jawTags.toList()) {
      if (!visible.containsKey(tag)) _clasps.remove(tag);
    }
    _clasps.addAll(visible);
  }

  void _undo() {
    if (_index < 0) return;
    setState(() {
      _index -= 1;
      _syncVisible();
    });
  }

  void _redo() {
    if (_index >= _history.length - 1) return;
    setState(() {
      _index += 1;
      _syncVisible();
    });
  }

  Future<void> _restart() async {
    if (!_hasWork) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认'),
        content: const Text('确认重新开始吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('确定')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      final tags = _lower
          ? _clasps.keys.where((item) => item >= 31).toList()
          : _clasps.keys.where((item) => item <= 28).toList();
      for (final tag in tags) {
        _clasps.remove(tag);
      }
      _history.clear();
      _index = -1;
      _strokes.clear();
      _strokeIndex = -1;
      _liveStroke = null;
    });
  }

  void _startStroke(Offset point) {
    setState(() {
      if (_strokeIndex < _strokes.length - 1) {
        _strokes.removeRange(_strokeIndex + 1, _strokes.length);
      }
      _liveStroke = _Stroke(width: _brushWidth, eraser: _eraser)..points.add(point);
    });
  }

  void _updateStroke(Offset point) {
    final live = _liveStroke;
    if (live == null) return;
    setState(() => live.points.add(point));
  }

  void _endStroke() {
    final live = _liveStroke;
    setState(() {
      if (live != null && live.points.length > 1) {
        _strokes.add(live);
        _strokeIndex = _strokes.length - 1;
      }
      _liveStroke = null;
    });
  }

  void _undoStroke() {
    if (_strokeIndex < 0) return;
    setState(() => _strokeIndex -= 1);
  }

  void _redoStroke() {
    if (_strokeIndex >= _strokes.length - 1) return;
    setState(() => _strokeIndex += 1);
  }

  void _clearStrokes() {
    setState(() {
      _strokes.clear();
      _strokeIndex = -1;
      _liveStroke = null;
    });
  }

  Future<void> _pick(int tag) async {
    if (_handDraw || _missing.contains(tag)) return;
    final imageTag = '${_imageTag(tag)}';
    final names = _catalog[imageTag] ?? const <String>[];
    final picked = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '卡环',
      barrierColor: const Color(0x4D191919),
      pageBuilder: (context, _, _) => _ClaspPanel(names: names),
    );
    if (picked == null || !mounted) return;
    _applyClasp(tag, picked);
  }

  Future<void> _finish() async {
    if (!_hasWork) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先设计卡环或手绘')));
      return;
    }
    final paths = <String>[];
    Future<void> capture(bool lower) async {
      setState(() => _lower = lower);
      await Future<void>.delayed(const Duration(milliseconds: 40));
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

    if (_hasUpper) await capture(false);
    if (_hasLower) await capture(true);
    if (!mounted) return;
    Navigator.pop(context, paths);
  }

  @override
  Widget build(BuildContext context) {
    final ratio = MediaQuery.sizeOf(context).width / 375;
    return Stack(
      children: [
        Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: orderInk,
        elevation: 0,
        title: const Text('开始设计', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          if (_both)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: SizedBox(
                height: 32,
                child: Row(
                  children: [
                    Expanded(child: _jawButton('上颌', false)),
                    Expanded(child: _jawButton('下颌', true)),
                  ],
                ),
              ),
            ),
          Expanded(
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 62 * ratio,
                  height: 308 * ratio,
                  child: RepaintBoundary(
                    key: _boundary,
                    child: ColoredBox(
                      color: Colors.white,
                      child: _JawArch(
                        lower: _lower,
                        ratio: ratio,
                        missing: _missing,
                        clasps: _clasps,
                        strokes: _visibleStrokes,
                        drawing: false,
                        onTooth: _pick,
                        onStrokeStart: _startStroke,
                        onStrokeUpdate: _updateStroke,
                        onStrokeEnd: _endStroke,
                        liveStroke: null,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 16,
                  top: 38 * ratio,
                  child: Row(
                    children: [
                      _stepButton('icon_previous_step', _index >= 0, _undo),
                      const SizedBox(width: 20),
                      _stepButton('icon_next_steps', _index < _history.length - 1, _redo),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 70 * ratio,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _tool('start_over', '重新开始', const Color(0xFF2C2C2E), _hasWork, _restart),
                _tool('hand_drawn', '手绘微调', const Color(0xFF2C2C2E), true, () {
                  setState(() {
                    _handDraw = true;
                    _eraser = false;
                  });
                }),
                if (_hasWork)
                  _tool('design_complete', '完成设计', const Color(0xFF30D03E), true, _finish),
              ],
            ),
          ),
        ],
      ),
        ),
        if (_handDraw)
          _HandDrawSheet(
            ratio: ratio,
            lower: _lower,
            missing: _missing,
            clasps: _clasps,
            strokes: _visibleStrokes,
            liveStroke: _liveStroke,
            eraser: _eraser,
            brushWidth: _brushWidth,
            canUndo: _strokeIndex >= 0,
            canRedo: _strokeIndex < _strokes.length - 1,
            onClose: () => setState(() => _handDraw = false),
            onStrokeStart: _startStroke,
            onStrokeUpdate: _updateStroke,
            onStrokeEnd: _endStroke,
            onUndo: _undoStroke,
            onRedo: _redoStroke,
            onClear: _clearStrokes,
            onEraser: (value) => setState(() => _eraser = value),
            onBrush: (value) => setState(() => _brushWidth = value),
          ),
      ],
    );
  }

  Widget _jawButton(String title, bool lower) {
    final selected = _lower == lower;
    return GestureDetector(
      onTap: () => setState(() => _lower = lower),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? orderBlue : const Color(0xFFECF2F8),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(fontSize: 14, color: selected ? Colors.white : orderInk),
          ),
        ),
      ),
    );
  }

  Widget _stepButton(String icon, bool enabled, VoidCallback onTap) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.35,
        child: OrderIcon(icon, width: 24, height: 24),
      ),
    );
  }

  Widget _tool(String icon, String title, Color color, bool enabled, VoidCallback onTap) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.35,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OrderIcon(icon, width: 24, height: 24),
            const SizedBox(height: 2),
            Text(title, style: TextStyle(fontSize: 10, color: color)),
          ],
        ),
      ),
    );
  }
}

class _JawArch extends StatelessWidget {
  const _JawArch({
    required this.lower,
    required this.ratio,
    required this.missing,
    required this.clasps,
    required this.strokes,
    required this.drawing,
    required this.onTooth,
    required this.onStrokeStart,
    required this.onStrokeUpdate,
    required this.onStrokeEnd,
    required this.liveStroke,
  });

  final bool lower;
  final double ratio;
  final Set<int> missing;
  final Map<int, String> clasps;
  final List<_Stroke> strokes;
  final bool drawing;
  final ValueChanged<int> onTooth;
  final ValueChanged<Offset> onStrokeStart;
  final ValueChanged<Offset> onStrokeUpdate;
  final VoidCallback onStrokeEnd;
  final _Stroke? liveStroke;

  @override
  Widget build(BuildContext context) {
    final height = 308 * ratio;
    final left = lower ? _layoutLower(ratio) : _layoutUpper(ratio, height);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Row(
          children: [
            Expanded(child: _half(left)),
            Expanded(
              child: Transform.flip(
                flipX: true,
                child: _half(
                  [
                    for (final item in left)
                      _PlacedTooth(_mirror(item.tag), item.left, item.top, item.width, item.height),
                  ],
                ),
              ),
            ),
          ],
        ),
        Positioned(
          left: 0,
          right: 0,
          top: lower ? 80 : null,
          bottom: lower ? null : 40 * ratio,
          child: Text.rich(
            TextSpan(
              children: drawing
                  ? const [
                      TextSpan(text: '💡\n直接画出你的想法', style: TextStyle(color: Color(0xFFCBCBCB), fontSize: 16)),
                    ]
                  : const [
                      TextSpan(text: '点击牙位\n', style: TextStyle(color: orderBlue, fontSize: 16, fontWeight: FontWeight.w500)),
                      TextSpan(text: '即可选择/取消卡环', style: TextStyle(color: Color(0xFFCBCBCB), fontSize: 16)),
                    ],
            ),
            textAlign: TextAlign.center,
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !drawing,
            child: GestureDetector(
              onPanStart: (details) => onStrokeStart(details.localPosition),
              onPanUpdate: (details) => onStrokeUpdate(details.localPosition),
              onPanEnd: (_) => onStrokeEnd(),
              child: CustomPaint(
                painter: _StrokePainter([...strokes, ?liveStroke]),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _half(List<_PlacedTooth> teeth) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (final tooth in teeth)
          Positioned(
            left: tooth.left,
            top: tooth.top,
            width: tooth.width,
            height: tooth.height,
            child: GestureDetector(
              onTap: () => onTooth(tooth.tag),
              child: _ToothArt(
                tag: tooth.tag,
                missing: missing.contains(tooth.tag),
                clasp: clasps[tooth.tag],
              ),
            ),
          ),
      ],
    );
  }
}

class _ToothArt extends StatelessWidget {
  const _ToothArt({
    required this.tag,
    required this.missing,
    required this.clasp,
  });

  final int tag;
  final bool missing;
  final String? clasp;

  @override
  Widget build(BuildContext context) {
    final imageTag = _imageTag(tag);
    final jaw = imageTag >= 40 ? 'lower' : 'upper';
    String file(String kind) => 'assets/place_order/clasp_tooth/${jaw}_left_$kind$imageTag.png';
    return Stack(
      fit: StackFit.expand,
      children: [
        if (missing) Image.asset(file('missing_teeth_back'), fit: BoxFit.contain),
        Image.asset(file(missing ? 'loss_tooth_position' : 'tooth_position_optional'), fit: BoxFit.contain),
        if (clasp != null) Image.asset(clasp!, fit: BoxFit.contain),
      ],
    );
  }
}

class _PlacedTooth {
  const _PlacedTooth(this.tag, this.left, this.top, this.width, this.height);

  final int tag;
  final double left;
  final double top;
  final double width;
  final double height;
}

int _imageTag(int tag) {
  if (tag >= 21 && tag <= 28) return tag - 10;
  if (tag >= 31 && tag <= 38) return tag + 10;
  return tag;
}

int _mirror(int tag) {
  if (tag >= 11 && tag <= 18) return tag + 10;
  if (tag >= 41 && tag <= 48) return tag - 10;
  return tag;
}

List<_PlacedTooth> _layoutUpper(double ratio, double height) {
  const spec = [
    [18, 94.0, 118.0],
    [17, 98.0, 160.0],
    [16, 94.0, 154.0],
    [15, 110.0, 136.0],
    [14, 102.0, 120.0],
    [13, 92.0, 113.0],
    [12, 76.0, 82.0],
    [11, 100.0, 76.0],
  ];
  const leftDelta = [0.0, 6.0, 6.0, -3.0, 22.0, 15.0, 34.0, 32.0];
  const bottomDelta = [0.0, -14.0, -34.0, -56.0, -52.0, -33.0, -30.0, -18.0];
  var left = 11 * ratio;
  var bottomInset = 0.0;
  final placed = <_PlacedTooth>[];
  for (var i = 0; i < spec.length; i++) {
    final w = spec[i][1] * ratio;
    final h = spec[i][2] * ratio;
    if (i > 0) {
      left += i == 3 ? -3 : leftDelta[i] * ratio;
      bottomInset -= bottomDelta[i] * ratio;
    }
    placed.add(_PlacedTooth(spec[i][0].toInt(), left, height - bottomInset - h, w, h));
  }
  return placed;
}

List<_PlacedTooth> _layoutLower(double ratio) {
  const spec = [
    [48, 79.0, 122.0],
    [47, 91.0, 166.0],
    [46, 94.0, 158.0],
    [45, 116.0, 143.0],
    [44, 112.0, 116.0],
    [43, 101.0, 106.0],
    [42, 62.0, 80.0],
    [41, 54.0, 80.0],
  ];
  var left = 0.0;
  var top = 0.0;
  var bottom = 122 * ratio;
  final placed = <_PlacedTooth>[];
  for (var i = 0; i < spec.length; i++) {
    final w = spec[i][1] * ratio;
    final h = spec[i][2] * ratio;
    if (i == 1) {
      left += 7 * ratio;
      top += 20 * ratio;
    } else if (i == 2) {
      left += 5 * ratio;
      top += 41 * ratio;
    } else if (i == 3) {
      left += -2;
      top += 49 * ratio;
    } else if (i == 4) {
      left += 25 * ratio;
      top += 53 * ratio;
    } else if (i == 5) {
      left += 25 * ratio;
      top += 29 * ratio;
    } else if (i == 6) {
      left += 49 * ratio;
      bottom = (top + (spec[i - 1][2] * ratio)) - ratio;
      top = bottom - h;
    } else if (i == 7) {
      left += 30 * ratio;
      bottom += 6 * ratio;
      top = bottom - h;
    } else {
      bottom = h;
    }
    placed.add(_PlacedTooth(spec[i][0].toInt(), left, top, w, h));
  }
  return placed;
}

class _StrokePainter extends CustomPainter {
  _StrokePainter(this.strokes);

  final List<_Stroke> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(Offset.zero & size, Paint());
    for (final stroke in strokes) {
      if (stroke.points.length < 2) continue;
      final path = Path()..moveTo(stroke.points.first.dx, stroke.points.first.dy);
      for (final point in stroke.points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = stroke.eraser ? const Color(0x00000000) : orderBlue
          ..blendMode = stroke.eraser ? BlendMode.clear : BlendMode.srcOver
          ..strokeWidth = stroke.width
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _StrokePainter oldDelegate) => true;
}

class _HandDrawSheet extends StatelessWidget {
  const _HandDrawSheet({
    required this.ratio,
    required this.lower,
    required this.missing,
    required this.clasps,
    required this.strokes,
    required this.liveStroke,
    required this.eraser,
    required this.brushWidth,
    required this.canUndo,
    required this.canRedo,
    required this.onClose,
    required this.onStrokeStart,
    required this.onStrokeUpdate,
    required this.onStrokeEnd,
    required this.onUndo,
    required this.onRedo,
    required this.onClear,
    required this.onEraser,
    required this.onBrush,
  });

  final double ratio;
  final bool lower;
  final Set<int> missing;
  final Map<int, String> clasps;
  final List<_Stroke> strokes;
  final _Stroke? liveStroke;
  final bool eraser;
  final double brushWidth;
  final bool canUndo;
  final bool canRedo;
  final VoidCallback onClose;
  final ValueChanged<Offset> onStrokeStart;
  final ValueChanged<Offset> onStrokeUpdate;
  final VoidCallback onStrokeEnd;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onClear;
  final ValueChanged<bool> onEraser;
  final ValueChanged<double> onBrush;

  @override
  Widget build(BuildContext context) {
    final accent = eraser ? const Color(0xFFEC8C86) : orderBlue;
    final track = eraser ? const Color(0xFFFFE9E7) : const Color(0xFFCCE5FF);
    return GestureDetector(
      onTap: () {},
      child: ColoredBox(
      color: const Color(0x99000000),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: FractionallySizedBox(
          heightFactor: 0.9,
          child: Material(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 120 * ratio,
                  height: 308 * ratio,
                  child: _JawArch(
                    lower: lower,
                    ratio: ratio,
                    missing: missing,
                    clasps: clasps,
                    strokes: strokes,
                    drawing: true,
                    onTooth: (_) {},
                    onStrokeStart: onStrokeStart,
                    onStrokeUpdate: onStrokeUpdate,
                    onStrokeEnd: onStrokeEnd,
                    liveStroke: liveStroke,
                  ),
                ),
                SizedBox(
                  height: 48,
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: onClose,
                        icon: const OrderIcon('icon_nav_back', width: 22, height: 22),
                      ),
                      const Expanded(
                        child: Text(
                          '手绘微调',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 18, color: Colors.black),
                        ),
                      ),
                      TextButton(
                        onPressed: onClose,
                        child: const Text('完成', style: TextStyle(fontSize: 14, color: Color(0xFF077DFD))),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 16,
                  top: 56,
                  child: GestureDetector(
                    onTap: onClear,
                    child: Container(
                      width: 56,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFDBDBDB)),
                      ),
                      child: const Text('默认', style: TextStyle(fontSize: 14, color: orderInk)),
                    ),
                  ),
                ),
                Positioned(
                  right: 16,
                  top: 56,
                  child: Row(
                    children: [
                      _SheetStep('icon_previous_step', canUndo, onUndo),
                      const SizedBox(width: 20),
                      _SheetStep('icon_next_steps', canRedo, onRedo),
                    ],
                  ),
                ),
                Positioned(
                  left: 45,
                  right: 45,
                  bottom: 115 + 26,
                  height: 28,
                  child: Row(
                    children: [
                      Text('笔刷大小', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: accent)),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: accent,
                            inactiveTrackColor: track,
                            thumbColor: accent,
                            overlayColor: accent.withValues(alpha: 0.12),
                          ),
                          child: Slider(
                            min: 1,
                            max: 50,
                            value: brushWidth,
                            onChanged: onBrush,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 115,
                  child: ColoredBox(
                    color: const Color(0xFFF6F6F6),
                    child: Center(
                      child: SizedBox(
                        width: 80,
                        height: 101,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _BrushButton('img_paintbrush', !eraser, onTap: () => onEraser(false)),
                            _BrushButton('img_eraser', eraser, onTap: () => onEraser(true)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}

class _SheetStep extends StatelessWidget {
  const _SheetStep(this.icon, this.enabled, this.onTap);

  final String icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.35,
        child: OrderIcon(icon, width: 24, height: 24),
      ),
    );
  }
}

class _BrushButton extends StatelessWidget {
  const _BrushButton(this.name, this.selected, {required this.onTap});

  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: OrderIcon(selected ? '${name}_select' : name, width: 20, height: selected ? 101 : 71),
    );
  }
}

class _ClaspPanel extends StatefulWidget {
  const _ClaspPanel({required this.names});

  final List<String> names;

  @override
  State<_ClaspPanel> createState() => _ClaspPanelState();
}

class _ClaspPanelState extends State<_ClaspPanel> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    const groups = [_roundClasps, _rodClasps, _supportClasps, _otherClasps];
    final known = groups[_tab].where(widget.names.contains).toList();
    final extra = _tab == 0
        ? widget.names.where((name) => groups.every((group) => !group.contains(name))).toList()
        : const <String>[];
    final items = [...known, ...extra];
    final width = MediaQuery.sizeOf(context).width - 100;
    return Material(
      color: Colors.transparent,
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          width: width,
          color: Colors.white,
          child: SafeArea(
            child: Column(
              children: [
                SizedBox(
                  height: 54,
                  child: Row(
                    children: [
                      for (final entry in ['圆型', '杆型', '支托', '其他'].indexed)
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _tab = entry.$1),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _tab == entry.$1 ? const Color(0xFF0081FF) : Colors.white,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: _tab == entry.$1 ? const Color(0xFF0081FF) : const Color(0xFFD5D5D5),
                                ),
                              ),
                              child: Text(
                                entry.$2,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _tab == entry.$1 ? Colors.white : orderInk,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      for (final name in items)
                        GestureDetector(
                          onTap: () => Navigator.pop(context, name),
                          child: Container(
                            margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F7FA),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(name, style: const TextStyle(fontSize: 12, color: Color(0xFF2E2D2C))),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
