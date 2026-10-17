import 'package:flutter/material.dart';
import 'package:flutter_muniuma_doctor/core/config/app_config.dart';
import 'package:flutter_muniuma_doctor/core/network/api_client.dart';
import 'package:flutter_muniuma_doctor/core/session/app_session.dart';
import 'package:flutter_muniuma_doctor/features/place_order/place_order_page.dart';
import 'package:flutter_muniuma_doctor/features/place_order/place_order_repository.dart';
import 'package:flutter_muniuma_doctor/features/place_order/place_order_ui.dart';

class ChoiceBasicInfoPage extends StatefulWidget {
  const ChoiceBasicInfoPage({
    super.key,
    required this.session,
    required this.api,
  });

  final AppSession session;
  final ApiClient api;

  @override
  State<ChoiceBasicInfoPage> createState() => _ChoiceBasicInfoPageState();
}

class _ChoiceBasicInfoPageState extends State<ChoiceBasicInfoPage> {
  late final PlaceOrderRepository _repo = PlaceOrderRepository(widget.api);
  List<Map<String, dynamic>> _hospitals = [];
  List<Map<String, dynamic>> _doctors = [];
  List<Map<String, dynamic>> _factories = [];
  Map<String, dynamic>? _hospital;
  Map<String, dynamic>? _doctor;
  int? _factoryIndex;
  bool _manage = false;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHospitals();
  }

  Future<void> _loadHospitals() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _repo.hospitals();
      if (!mounted) return;
      if (list.isEmpty) {
        setState(() {
          _loading = false;
          _error = '您暂无执业单位';
        });
        return;
      }
      Map<String, dynamic> current = list.first;
      for (final item in list) {
        if (field(item, const ['Id', 'id']) == widget.session.hospitalId) {
          current = item;
          break;
        }
      }
      setState(() {
        _hospitals = list;
        _hospital = current;
      });
      await _loadFactories();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    }
  }

  Future<void> _loadFactories() async {
    final hospital = _hospital;
    if (hospital == null) return;
    setState(() => _loading = true);
    try {
      final list = await _repo.factories(field(hospital, const ['Id', 'id']));
      if (!mounted) return;
      var index = list.length == 1 ? 0 : null;
      for (var i = 0; i < list.length; i++) {
        if (asDefault(list[i])) index = i;
      }
      setState(() {
        _factories = list;
        _factoryIndex = index;
        _doctors = [];
        _doctor = null;
        _loading = false;
      });
      if (index != null) await _loadDoctors();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    }
  }

  Future<void> _loadDoctors() async {
    final hospital = _hospital;
    final index = _factoryIndex;
    if (hospital == null || index == null) return;
    final factory = _factories[index];
    try {
      final hospitalId = field(hospital, const ['Id', 'id']);
      final factoryId = field(factory, const ['factoryId', 'FactoryId']);
      final results = await Future.wait([
        _repo.doctors(hospitalId, factoryId),
        _repo.isManageOrAssistant(
          hospitalId: hospitalId,
          factoryId: factoryId,
          userName: widget.session.userName,
        ),
      ]);
      if (!mounted) return;
      final doctors = results[0] as List<Map<String, dynamic>>;
      final manage = results[1] as bool;
      Map<String, dynamic>? current = doctors.isEmpty ? null : doctors.first;
      final userId = fieldOf(widget.session.user, const ['userId', 'id', 'Id']);
      for (final doctor in doctors) {
        if (field(doctor, const ['doctorId', 'DoctorId']) == userId) {
          current = doctor;
          break;
        }
      }
      setState(() {
        _manage = manage;
        _doctor = current;
        _doctors = manage || current == null ? doctors : [current];
      });
    } on ApiException catch (error) {
      if (mounted) _tip(error.message);
    }
  }

  void _enter() {
    if (_factoryIndex == null) {
      _tip('请选择生产单位');
      return;
    }
    if (_doctor == null) {
      _tip('请选择医生');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlaceOrderPage(
          repo: _repo,
          session: widget.session,
          hospital: _hospital!,
          factory: _factories[_factoryIndex!],
          doctor: _doctor!,
        ),
      ),
    );
  }

  void _tip(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _moreDoctors() async {
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      builder: (context) {
        Map<String, dynamic>? current = _doctor;
        return StatefulBuilder(
          builder: (context, setSheet) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      height: 44,
                      child: Center(
                        child: Text(
                          '请选择医生',
                          style: TextStyle(
                            color: orderTitleBlue,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 10,
                      children: [
                        for (final doctor in _doctors)
                          SizedBox(
                            width: 76,
                            height: 28,
                            child: _DoctorChip(
                              name: field(doctor, const ['name', 'doctorName']),
                              selected: doctor == current,
                              onTap: _manage
                                  ? () => setSheet(() => current = doctor)
                                  : null,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: orderBlue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context, current),
                        child: const Text('确定', style: TextStyle(fontSize: 18)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (picked != null) setState(() => _doctor = picked);
  }

  @override
  Widget build(BuildContext context) {
    return OrderBluePage(
      title: '基本信息',
      bottom: _bottomBar(),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  children: [
                    _hospitalCard(),
                    const SizedBox(height: 16),
                    _doctorCard(),
                    const SizedBox(height: 20),
                    const Text(
                      '请选择生产单位',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: orderInk,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _factoryGrid(),
                  ],
                ),
    );
  }

  Widget _hospitalCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD1E8FF), width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          SizedBox(
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: const [
                Positioned.fill(
                  child: OrderIcon('icon_choice_hospital_标题_bg', fit: BoxFit.fill),
                ),
                Text(
                  '请选择执业单位',
                  style: TextStyle(
                    color: orderTitleBlue,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              children: [
                for (final item in _hospitals) ...[
                  const SizedBox(height: 12),
                  _HospitalTile(
                    name: field(item, const ['fullName', 'smallName', 'name']),
                    logo: AppConfig.imageUrl(
                      field(item, const ['logoCos']),
                      widget.session.env.cosDomain,
                    ),
                    selected: item == _hospital,
                    onTap: () {
                      setState(() {
                        _hospital = item;
                        _factories = [];
                        _factoryIndex = null;
                      });
                      _loadFactories();
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _doctorCard() {
    final visible = _doctors.length > 7 ? _doctors.take(7).toList() : _doctors;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD1E8FF), width: 2),
      ),
      child: Column(
        children: [
          const SizedBox(
            height: 44,
            child: Center(
              child: Text(
                '请选择医生',
                style: TextStyle(
                  color: orderTitleBlue,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          if (_doctors.isEmpty)
            const Padding(padding: EdgeInsets.all(8), child: Text('暂无医生'))
          else
            LayoutBuilder(
              builder: (context, constraints) {
                const gap = 8.0;
                final width = (constraints.maxWidth - gap * 3) / 4;
                return Wrap(
                  spacing: gap,
                  runSpacing: 10,
                  children: [
                    for (final doctor in visible)
                      SizedBox(
                        width: width,
                        height: 28,
                        child: _DoctorChip(
                          name: field(doctor, const ['name', 'doctorName']),
                          selected: doctor == _doctor,
                          onTap: _manage ? () => setState(() => _doctor = doctor) : null,
                        ),
                      ),
                    if (_doctors.length > 7)
                      SizedBox(
                        width: width,
                        height: 28,
                        child: _DoctorChip(
                          name: '更多',
                          selected: false,
                          trailing: const OrderIcon('icon_choice_下拉', width: 12, height: 12),
                          onTap: _moreDoctors,
                        ),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _factoryGrid() {
    if (_factories.isEmpty) {
      return const Text('暂无生产单位', textAlign: TextAlign.center);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final rows = <Widget>[];
        var index = 0;
        var row = 0;
        while (index < _factories.length) {
          final count = row == 0
              ? _factories.length.clamp(1, 3)
              : (_factories.length - index).clamp(1, 3);
          final slot = (constraints.maxWidth - 16) / 3;
          rows.add(
            SizedBox(
              height: 109,
              child: Row(
                children: [
                  for (var i = 0; i < count; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    SizedBox(
                      width: row == 0 && count < 3
                          ? (constraints.maxWidth - 8 * (count - 1)) / count
                          : slot,
                      child: _FactoryTile(
                        item: _factories[index + i],
                        selected: index + i == _factoryIndex,
                        cos: widget.session.env.cosDomain,
                        onTap: () {
                          setState(() => _factoryIndex = index + i);
                          _loadDoctors();
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
          rows.add(const SizedBox(height: 8));
          index += count;
          row++;
        }
        return Column(children: rows);
      },
    );
  }

  Widget _bottomBar() {
    final width = (MediaQuery.sizeOf(context).width - 16 * 2 - 15) / 2;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 52,
          color: const Color(0xFFFFF0F0),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: const Row(
            children: [
              OrderIcon('icon_order_说明_16pt', width: 16, height: 16),
              SizedBox(width: 4),
              Expanded(
                child: Text(
                  '执业单位和生产单位是订单重要信息下单后不可更换请明确选择',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFFFF0000), fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        ColoredBox(
          color: orderPageBg,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  SizedBox(
                    width: width,
                    height: 48,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: orderBlue,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            onPressed: () => _tip('语音下单即将开放'),
                            icon: const OrderIcon('icon_语音下单', width: 18, height: 18),
                            label: const Text('语音下单', style: TextStyle(fontSize: 18)),
                          ),
                        ),
                        const Positioned(
                          top: 4,
                          right: 8,
                          child: OrderIcon('icon_新', width: 18, height: 18),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 15),
                  SizedBox(
                    width: width,
                    height: 48,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: orderBlue,
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: orderBlue),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      onPressed: _enter,
                      child: const Text('进入下单', style: TextStyle(fontSize: 18)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

bool asDefault(Map<String, dynamic> item) {
  final value = item['isDefaultFactory'] ?? item['isDefault'];
  return value == true || value == 1 || value == '1' || value == 'true';
}

class _HospitalTile extends StatelessWidget {
  const _HospitalTile({
    required this.name,
    required this.logo,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final String? logo;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFE5F2FF) : orderFieldBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(color: selected ? orderBlue : orderFieldBg),
      ),
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Row(
            children: [
              const SizedBox(width: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: logo == null
                    ? const SizedBox(width: 36, height: 36)
                    : Image.network(
                        logo!,
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const SizedBox(width: 36, height: 36),
                      ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  name,
                  maxLines: 2,
                  style: TextStyle(
                    fontSize: 14,
                    color: selected ? orderBlue : orderInk,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DoctorChip extends StatelessWidget {
  const _DoctorChip({
    required this.name,
    required this.selected,
    this.onTap,
    this.trailing,
  });

  final String name;
  final bool selected;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: trailing == null ? const Color(0xFFF2F7FA) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(color: selected ? orderBlue : Colors.transparent),
      ),
      child: InkWell(
        onTap: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: selected ? orderBlue : orderInk,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

class _FactoryTile extends StatelessWidget {
  const _FactoryTile({
    required this.item,
    required this.selected,
    required this.cos,
    required this.onTap,
  });

  final Map<String, dynamic> item;
  final bool selected;
  final String cos;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final logo = AppConfig.imageUrl(field(item, const ['logoCos']), cos);
    return Material(
      color: selected ? const Color(0xFFE5F2FF) : orderFieldBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(color: selected ? orderBlue : orderFieldBg),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(9, 14, 9, 8),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: logo == null
                    ? const SizedBox(width: 36, height: 36)
                    : Image.network(
                        logo,
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const SizedBox(width: 36, height: 36),
                      ),
              ),
              const SizedBox(height: 10),
              Text(
                field(item, const ['factoryName', 'name']),
                maxLines: 3,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: selected ? orderBlue : orderInk,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
