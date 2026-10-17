import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_muniuma_doctor/core/network/api_client.dart';
import 'package:flutter_muniuma_doctor/core/session/app_session.dart';
import 'package:flutter_muniuma_doctor/features/auth/login_page.dart';
import 'package:flutter_muniuma_doctor/features/place_order/choice_basic_info_page.dart';
import 'package:flutter_muniuma_doctor/features/place_order/place_order_draft.dart';
import 'package:flutter_muniuma_doctor/features/place_order/place_order_repository.dart';
import 'package:flutter_muniuma_doctor/features/place_order/place_order_support_pages.dart';
import 'package:flutter_muniuma_doctor/features/place_order/product_select_page.dart';

class PlaceOrderPage extends StatefulWidget {
  const PlaceOrderPage({
    super.key,
    required this.repo,
    required this.session,
    required this.hospital,
    required this.factory,
    required this.doctor,
  });

  final PlaceOrderRepository repo;
  final AppSession session;
  final Map<String, dynamic> hospital;
  final Map<String, dynamic> factory;
  final Map<String, dynamic> doctor;

  @override
  State<PlaceOrderPage> createState() => _PlaceOrderPageState();
}

class _PlaceOrderPageState extends State<PlaceOrderPage> {
  late final PlaceOrderDraft _draft = PlaceOrderDraft(
    hospital: widget.hospital,
    factory: widget.factory,
    doctor: widget.doctor,
  );
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _age = TextEditingController();
  final _remark = TextEditingController();
  List<Map<String, dynamic>> _brands = [];
  List<Map<String, dynamic>> _sendWays = [];
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadAddress();
    _loadScanOptions();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _age.dispose();
    _remark.dispose();
    super.dispose();
  }

  Future<void> _loadAddress() async {
    try {
      final list = await widget.repo.addresses(
        hospitalId: _draft.hospitalId,
        factoryId: _draft.factoryId,
      );
      if (!mounted || list.isEmpty) return;
      Map<String, dynamic> current = list.first;
      for (final item in list) {
        if (asBool(item['isDefault'])) {
          current = item;
          break;
        }
      }
      setState(() => _draft.address = current);
    } on ApiException catch (error) {
      if (mounted) _tip(error.message);
    }
  }

  Future<void> _loadScanOptions() async {
    try {
      final brands = await widget.repo.scanBrands();
      final ways = await widget.repo.enumItems('EnumOralScanSendType');
      if (!mounted) return;
      setState(() {
        _brands = brands;
        _sendWays = ways;
      });
    } catch (_) {}
  }

  Future<void> _addProduct() async {
    _syncInputs();
    if (_draft.patientName.isEmpty) {
      _tip('请输入【患者姓名】');
      return;
    }
    final product = await Navigator.push<OrderProduct>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductSelectPage(
          repo: widget.repo,
          factoryHospitalId: _draft.factoryHospitalId,
          factoryId: _draft.factoryId,
          doctorId: _draft.doctorId,
        ),
      ),
    );
    if (product == null || !mounted) return;
    try {
      final coupons = await widget.repo.coupons(
        doctorId: _draft.doctorId,
        productHospitalId: product.productHospitalId,
      );
      for (final coupon in coupons) {
        coupon['selected'] = false;
      }
      product.coupons.addAll(coupons);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _draft.products.insert(0, product);
      _draft.refreshMould();
      _draft.applyDefaultColor(product);
      if (!_draft.hasSingleConnected) {
        _draft.connectType = -1;
        _draft.segments.clear();
      }
    });
    if (product.hasReworkOrRepair && _draft.reason == null) {
      await _pickReason();
    }
  }

  Future<void> _editTooth(int index) async {
    final current = _draft.products[index];
    final edited = await Navigator.push<OrderProduct>(
      context,
      MaterialPageRoute(
        builder: (_) => ToothPickerPage(
          group: current.group,
          detail: current.detail,
          initial: current,
        ),
      ),
    );
    if (edited == null || !mounted) return;
    edited.coupons.addAll(current.coupons);
    edited.trialId = current.trialId;
    edited.trialName = current.trialName;
    setState(() {
      _draft.products[index] = edited;
      _draft.refreshMould();
      _draft.segments.clear();
    });
    if (edited.hasReworkOrRepair && _draft.reason == null) await _pickReason();
  }

  Future<void> _pickReason() async {
    final reason = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => ReasonPage(repo: widget.repo)),
    );
    if (reason != null && mounted) setState(() => _draft.reason = reason);
  }

  Future<void> _openAddress() async {
    final picked = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => AddressPage(
          repo: widget.repo,
          hospitalId: _draft.hospitalId,
          factoryId: _draft.factoryId,
          currentId: _draft.address == null
              ? ''
              : field(_draft.address!, const ['Id', 'id']),
        ),
      ),
    );
    if (picked != null && mounted) setState(() => _draft.address = picked);
  }

  Future<void> _openSegments() async {
    final groups = await Navigator.push<List<List<String>>>(
      context,
      MaterialPageRoute(
        builder: (_) => SegmentPage(
          teeth: _draft.conjoinedTeeth(),
          initial: _draft.segments,
        ),
      ),
    );
    if (groups != null && mounted) {
      setState(() {
        _draft.segments
          ..clear()
          ..addAll(groups);
      });
    }
  }

  Future<T?> _push<T>(Widget page) {
    return Navigator.push<T>(context, MaterialPageRoute(builder: (_) => page));
  }

  void _syncInputs() {
    _draft.patientName = _name.text.trim();
    _draft.patientTel = _phone.text.trim();
    _draft.patientAge = int.tryParse(_age.text.trim()) ?? 0;
    _draft.remark = _remark.text.trim();
  }

  Future<void> _submit() async {
    _syncInputs();
    final message = _draft.validate();
    if (message != null) {
      _tip(message);
      return;
    }
    setState(() => _submitting = true);
    try {
      final result = await widget.repo.placeOrder(_draft.toPayload());
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlaceOrderSuccessPage(
            result: result,
            repo: widget.repo,
            onContinue: () {
              final navigator = Navigator.of(context);
              navigator.popUntil((route) => route.isFirst);
              navigator.push(
                MaterialPageRoute(
                  builder: (_) => ChoiceBasicInfoPage(
                    session: widget.session,
                    api: widget.repo.api,
                  ),
                ),
              );
            },
          ),
        ),
      );
    } on ApiException catch (error) {
      if (mounted) _tip(error.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _tip(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final hospitalName = field(widget.hospital, const ['fullName', 'smallName', 'name']);
    final factoryName = field(widget.factory, const ['factoryName', 'name']);
    final doctorName = field(widget.doctor, const ['name', 'doctorName']);
    final hasProduct = _draft.products.isNotEmpty;
    return Scaffold(
      backgroundColor: const Color(0xFFF2F7FA),
      appBar: AppBar(title: const Text('下单')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _section('基本信息', [
            _line('执业单位', hospitalName),
            _line('生产单位', factoryName),
            _line('下单医生', doctorName),
          ]),
          _section('患者信息', [
            _input('患者姓名', _name),
            _input('患者电话', _phone, type: TextInputType.phone),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  const Text('性别'),
                  const SizedBox(width: 12),
                  ChoiceChip(
                    label: const Text('男'),
                    selected: _draft.patientSex == 1,
                    onSelected: (_) => setState(() => _draft.patientSex = 1),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('女'),
                    selected: _draft.patientSex == 2,
                    onSelected: (_) => setState(() => _draft.patientSex = 2),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _age,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: '年龄',
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ]),
          _section('产品信息', [
            for (var i = 0; i < _draft.products.length; i++) _productTile(i),
            ListTile(
              leading: const Icon(Icons.add, color: themeBlue),
              title: const Text('添加产品', style: TextStyle(color: themeBlue)),
              onTap: _addProduct,
            ),
            if (hasProduct && _draft.hasSingleConnected) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                child: const Text('连接方式'),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('全部单独'),
                      selected: _draft.connectType == 0,
                      onSelected: (_) => setState(() {
                        _draft.connectType = 0;
                        _draft.segments.clear();
                      }),
                    ),
                    ChoiceChip(
                      label: const Text('全部连体'),
                      selected: _draft.connectType == 1,
                      onSelected: (_) => setState(() {
                        _draft.connectType = 1;
                        _draft.segments.clear();
                      }),
                    ),
                    ChoiceChip(
                      label: const Text('分段'),
                      selected: _draft.connectType == 2,
                      onSelected: (_) {
                        setState(() => _draft.connectType = 2);
                        _openSegments();
                      },
                    ),
                  ],
                ),
              ),
              if (_draft.connectType == 2)
                ListTile(
                  title: Text(
                    _draft.segments.isEmpty
                        ? '请完成分段牙位'
                        : _draft.segments.map((item) => item.join('|')).join('，'),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _openSegments,
                ),
            ],
            if (hasProduct) ...[
              const Divider(height: 1),
              ListTile(
                title: const Text('取模方式'),
                subtitle: Text(mouldName(_draft.obtainMould)),
              ),
              if (_draft.canChoiceMould)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      for (final entry in mouldOptions.entries)
                        ChoiceChip(
                          label: Text(entry.value),
                          selected: _draft.obtainMould == entry.key,
                          onSelected: (_) =>
                              setState(() => _draft.obtainMould = entry.key),
                        ),
                    ],
                  ),
                ),
              if (_draft.obtainMould == 2) ...[
                ListTile(
                  title: const Text('口扫品牌'),
                  subtitle: Text(
                    _draft.scanBrand == null
                        ? '请选择'
                        : field(_draft.scanBrand!, const ['name', 'brandName']),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _pickBrand,
                ),
                ListTile(
                  title: const Text('发送方式'),
                  subtitle: Text(
                    _draft.sendWayName.isEmpty ? '请选择' : _draft.sendWayName,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _pickSendWay,
                ),
                SwitchListTile(
                  title: const Text('上门取附件'),
                  value: _draft.takeAttachments,
                  onChanged: (value) => setState(() => _draft.takeAttachments = value),
                ),
              ],
              ListTile(
                title: Text(_draft.hasRequiredColor ? '颜色（必填）' : '颜色'),
                subtitle: Text(_colorText()),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final changed = await _push<bool>(
                    ColorEditPage(repo: widget.repo, draft: _draft),
                  );
                  if (changed == true) setState(() {});
                },
              ),
              if (_draft.hasRework)
                ListTile(
                  title: const Text('返工原因'),
                  subtitle: Text(
                    _draft.reason == null
                        ? '请选择'
                        : field(_draft.reason!, const ['name', 'phenomenonName']),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _pickReason,
                ),
              if (_draft.hasPlant)
                ListTile(
                  title: const Text('种植信息'),
                  subtitle: Text(_plantText()),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final changed = await _push<bool>(
                      PlantEditPage(repo: widget.repo, draft: _draft),
                    );
                    if (changed == true) setState(() {});
                  },
                ),
            ],
          ]),
          if (hasProduct) ...[
            _section('详细内容', [
              if (_draft.hasTrial)
                ListTile(
                  title: const Text('试戴'),
                  subtitle: Text(_trialText()),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final changed = await _push<bool>(
                      TrialEditPage(repo: widget.repo, draft: _draft),
                    );
                    if (changed == true) setState(() {});
                  },
                ),
              ListTile(
                title: const Text('设计'),
                subtitle: Text(
                  _draft.designs.isEmpty
                      ? '可选'
                      : _draft.designs
                          .map((item) => field(item, const ['name', 'designName']))
                          .where((item) => item.isNotEmpty)
                          .join('、'),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final changed = await _push<bool>(
                    DesignEditPage(repo: widget.repo, draft: _draft),
                  );
                  if (changed == true) setState(() {});
                },
              ),
            ]),
            _section('附件与备注', [
              ListTile(
                title: const Text('附件'),
                subtitle: Text(
                  _draft.attachments.isEmpty
                      ? '可选'
                      : _draft.attachments
                          .map(
                            (item) =>
                                '${field(item, const ['name', 'enclosureName'])} x${asInt(item['number'])}',
                          )
                          .join('、'),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final changed = await _push<bool>(
                    AttachmentEditPage(repo: widget.repo, draft: _draft),
                  );
                  if (changed == true) setState(() {});
                },
              ),
              if (_draft.hasWarranty)
                SwitchListTile(
                  title: const Text('打印实体质保卡'),
                  value: _draft.printPhysicalCard,
                  onChanged: (value) =>
                      setState(() => _draft.printPhysicalCard = value),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: TextField(
                  controller: _remark,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: '文字备注',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              ListTile(
                title: const Text('收货地址'),
                subtitle: Text(_addressText()),
                trailing: const Icon(Icons.chevron_right),
                onTap: _openAddress,
              ),
            ]),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: _submitting ? null : _submit,
                  style: FilledButton.styleFrom(backgroundColor: themeBlue),
                  child: Text(_submitting ? '提交中' : '提交订单'),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _productTile(int index) {
    final product = _draft.products[index];
    final summary = product.teeth
        .map((item) => '${item.code}${productionName(item.productionType)}')
        .join(' ');
    return ListTile(
      title: Text(product.name),
      subtitle: Text(summary.isEmpty ? '未选牙位' : summary),
      trailing: IconButton(
        onPressed: () => setState(() {
          _draft.products.removeAt(index);
          _draft.refreshMould();
          if (_draft.products.isEmpty) {
            _draft.colors.clear();
            _draft.designs.clear();
            _draft.reason = null;
            _draft.connectType = -1;
            _draft.segments.clear();
          }
        }),
        icon: const Icon(Icons.delete_outline),
      ),
      onTap: () => _editTooth(index),
    );
  }

  Future<void> _pickBrand() async {
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          children: [
            for (final item in _brands)
              ListTile(
                title: Text(field(item, const ['name', 'brandName'])),
                onTap: () => Navigator.pop(context, item),
              ),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _draft.scanBrand = picked);
  }

  Future<void> _pickSendWay() async {
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          children: [
            for (final item in _sendWays)
              ListTile(
                title: Text(field(item, const ['name', 'description', 'text'])),
                onTap: () => Navigator.pop(context, item),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    setState(() {
      _draft.sendWayId = asInt(
        picked['value'] ?? picked['id'] ?? picked['Id'] ?? picked['enumValue'],
      );
      _draft.sendWayName = field(picked, const ['name', 'description', 'text']);
    });
  }

  String _colorText() {
    if (_draft.colors.isEmpty) return _draft.hasRequiredColor ? '请填写' : '可选';
    final color = _draft.colors.first;
    return [
      field(color, const ['colorMain']),
      field(color, const ['colorNeck']),
      field(color, const ['colorMid']),
      field(color, const ['colorCut']),
      field(color, const ['customize']),
    ].where((item) => item.isNotEmpty).join(' / ');
  }

  String _plantText() {
    final names = <String>[];
    for (final product in _draft.products.where((item) => item.isPlant)) {
      for (final plant in product.plants) {
        final name = field(plant, const ['plantSystemName']);
        names.add(
          '${field(plant, const ['toothSingle'])}${name.isEmpty ? '未选' : name}',
        );
      }
    }
    return names.isEmpty ? '请选择' : names.join('、');
  }

  String _trialText() {
    final names = _draft.products
        .where((item) => item.isTrial && item.trialName.isNotEmpty)
        .map((item) => '${item.name} ${item.trialName}');
    return names.isEmpty ? '请选择' : names.join('、');
  }

  String _addressText() {
    final address = _draft.address;
    if (address == null) return '请选择或添加地址';
    return [
      field(address, const ['consignee', 'name']),
      field(address, const ['tel']),
      field(address, const ['detailAddr', 'address']),
    ].where((item) => item.isNotEmpty).join(' ');
  }

  Widget _section(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          ...children,
        ],
      ),
      ),
    );
  }

  Widget _line(String label, String value) {
    return ListTile(
      dense: true,
      title: Text(label),
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 220),
        child: Text(value, textAlign: TextAlign.end, maxLines: 2),
      ),
    );
  }

  Widget _input(String label, TextEditingController controller, {TextInputType? type}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: TextField(
        controller: controller,
        keyboardType: type,
        decoration: InputDecoration(labelText: label, isDense: true),
      ),
    );
  }
}
