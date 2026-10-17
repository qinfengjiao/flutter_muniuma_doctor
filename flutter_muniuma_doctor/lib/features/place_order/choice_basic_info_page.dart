import 'package:flutter/material.dart';
import 'package:flutter_muniuma_doctor/core/config/app_config.dart';
import 'package:flutter_muniuma_doctor/core/network/api_client.dart';
import 'package:flutter_muniuma_doctor/core/session/app_session.dart';
import 'package:flutter_muniuma_doctor/features/auth/login_page.dart';
import 'package:flutter_muniuma_doctor/features/place_order/place_order_page.dart';
import 'package:flutter_muniuma_doctor/features/place_order/place_order_repository.dart';

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
        _doctors = manage || current == null
            ? doctors
            : [current];
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F7FA),
      appBar: AppBar(title: const Text('基本信息')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        children: [
                          _Card(
                            title: '执业单位',
                            child: Column(
                              children: [
                                for (final item in _hospitals)
                                  _SelectTile(
                                    title: field(item, const [
                                      'fullName',
                                      'smallName',
                                      'name',
                                    ]),
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
                            ),
                          ),
                          const SizedBox(height: 12),
                          _Card(
                            title: '下单医生',
                            child: _doctors.isEmpty
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: Text('暂无医生'),
                                  )
                                : Column(
                                    children: [
                                      for (final item in _doctors)
                                        _SelectTile(
                                          title: field(item, const [
                                            'name',
                                            'doctorName',
                                          ]),
                                          subtitle: _manage ? '可切换医生' : '当前医生',
                                          selected: item == _doctor,
                                          onTap: _manage
                                              ? () => setState(() => _doctor = item)
                                              : null,
                                        ),
                                    ],
                                  ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            '请选择生产单位',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_factories.isEmpty)
                            const Text('暂无生产单位', textAlign: TextAlign.center)
                          else
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                mainAxisSpacing: 8,
                                crossAxisSpacing: 8,
                                childAspectRatio: 0.86,
                              ),
                              itemCount: _factories.length,
                              itemBuilder: (context, index) {
                                final item = _factories[index];
                                final selected = index == _factoryIndex;
                                final logo = AppConfig.imageUrl(
                                  field(item, const ['logoCos']),
                                  widget.session.env.cosDomain,
                                );
                                return InkWell(
                                  onTap: () {
                                    setState(() => _factoryIndex = index);
                                    _loadDoctors();
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: selected
                                            ? themeBlue
                                            : const Color(0xFFD1E8FF),
                                        width: selected ? 2 : 1,
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Expanded(
                                          child: logo == null
                                              ? const Icon(Icons.apartment)
                                              : Image.network(
                                                  logo,
                                                  fit: BoxFit.contain,
                                                  errorBuilder: (_, _, _) =>
                                                      const Icon(Icons.apartment),
                                                ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          field(item, const ['factoryName', 'name']),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                    Container(
                      color: const Color(0xFFFFF0F0),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: const Text(
                        '执业单位和生产单位是订单重要信息，下单后不可更换，请明确选择',
                        style: TextStyle(color: Color(0xFFFF0000), fontSize: 12),
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        child: SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton(
                            onPressed: _enter,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: themeBlue,
                              side: const BorderSide(color: themeBlue),
                            ),
                            child: const Text('进入下单', style: TextStyle(fontSize: 18)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

bool asDefault(Map<String, dynamic> item) {
  final value = item['isDefaultFactory'] ?? item['isDefault'];
  return value == true || value == 1 || value == '1' || value == 'true';
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFD1E8FF), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          child,
        ],
      ),
    );
  }
}

class _SelectTile extends StatelessWidget {
  const _SelectTile({
    required this.title,
    required this.selected,
    this.subtitle,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      onTap: onTap,
      title: Text(title.isEmpty ? '未命名' : title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: Icon(
        selected ? Icons.check_circle : Icons.circle_outlined,
        color: selected ? themeBlue : const Color(0xFFC8C8C8),
      ),
    );
  }
}
