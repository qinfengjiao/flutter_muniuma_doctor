import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_muniuma_doctor/core/network/api_client.dart';
import 'package:flutter_muniuma_doctor/core/session/app_session.dart';
import 'package:flutter_muniuma_doctor/features/place_order/choice_basic_info_page.dart';
import 'package:flutter_muniuma_doctor/features/place_order/order_remark_pages.dart';
import 'package:flutter_muniuma_doctor/features/place_order/place_order_draft.dart';
import 'package:flutter_muniuma_doctor/features/place_order/place_order_repository.dart';
import 'package:flutter_muniuma_doctor/features/place_order/place_order_support_pages.dart';
import 'package:flutter_muniuma_doctor/features/place_order/place_order_ui.dart';
import 'package:flutter_muniuma_doctor/features/place_order/product_select_page.dart';
import 'package:flutter_muniuma_doctor/features/place_order/tooth_picker_page.dart';

class PlaceOrderPage extends StatefulWidget {
  const PlaceOrderPage({
    super.key,
    required this.repo,
    required this.session,
    required this.hospital,
    required this.factory,
    required this.doctor,
    this.speech,
    this.speechAudioCos = '',
  });

  final PlaceOrderRepository repo;
  final AppSession session;
  final Map<String, dynamic> hospital;
  final Map<String, dynamic> factory;
  final Map<String, dynamic> doctor;
  final Map<String, dynamic>? speech;
  final String speechAudioCos;

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
  bool _patientOpen = true;
  bool _detailOpen = false;
  bool _attachOpen = false;

  @override
  void initState() {
    super.initState();
    final speech = widget.speech;
    if (speech != null) {
      _draft.applySpeech(speech, audioCosJson: widget.speechAudioCos);
      _name.text = _draft.patientName;
      _phone.text = _draft.patientTel;
      if (_draft.patientAge > 0) _age.text = '${_draft.patientAge}';
      _remark.text = _draft.remark;
    }
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
    final edited = await showToothPicker(
      context,
      group: current.group,
      detail: current.detail,
      initial: current,
    );
    if (edited == null || !mounted) return;
    edited.coupons.addAll(current.coupons);
    edited.trialId = current.trialId;
    edited.trialName = current.trialName;
    edited.designIds.addAll(current.designIds);
    edited.claspDesignCos = current.claspDesignCos;
    edited.plants
      ..clear()
      ..addAll(current.plants.map(Map<String, dynamic>.from));
    edited.syncPlants();
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

  String _mergeCos(String current, String added) {
    if (added.isEmpty) return current;
    if (current.isEmpty) return added;
    final first = jsonDecode(current);
    final second = jsonDecode(added);
    if (first is List && second is List) {
      return jsonEncode([...first, ...second]);
    }
    return added;
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
      _draft.colorimetricCos = await widget.repo.uploadFiles(_draft.colorimetricPhotos);
      _draft.otherPhotoCos = await widget.repo.uploadFiles(_draft.otherPhotos);
      final uploadedAudio = await widget.repo.uploadFiles(
        _draft.audios.map((item) => item.path).toList(),
      );
      _draft.audioCos = _mergeCos(_draft.audioCos, uploadedAudio);
      for (final product in _draft.products) {
        if (product.claspImagePaths.isEmpty) continue;
        product.claspDesignCos = await widget.repo.uploadFiles(product.claspImagePaths);
      }
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
    final hasProduct = _draft.products.isNotEmpty;
    return OrderBluePage(
      title: '下单',
      bottom: _submitBar(hasProduct),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        children: [
          _headerCard(),
          const SizedBox(height: 8),
          _banner('产品信息', add: true, onAdd: _addProduct),
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)),
            ),
            child: Column(
              children: [
                for (var i = 0; i < _draft.products.length; i++) _productCard(i),
                if (hasProduct) ...[
                  _connectCard(),
                  const SizedBox(height: 8),
                  _mouldCard(),
                  const SizedBox(height: 8),
                  _colorCard(),
                  if (_draft.hasRework) _linkRow('返工原因', _reasonText(), _pickReason),
                  if (_draft.hasPlant)
                    _linkRow('种植信息', _plantText(), () async {
                      final changed = await _push<bool>(
                        PlantEditPage(repo: widget.repo, draft: _draft),
                      );
                      if (changed == true) setState(() {});
                    }),
                ],
              ],
            ),
          ),
          if (hasProduct) ...[
            const SizedBox(height: 8),
            _foldBanner(
              title: '详细内容',
              icon: _detailOpen ? 'icon_placeorder_详细内容_white' : 'icon_order_icon_详细内容',
              tip: '展开填写【种植系统、试戴、设计方式】等信息',
              open: _detailOpen,
              whiteTitle: _detailOpen,
              onTap: () => setState(() => _detailOpen = !_detailOpen),
            ),
            if (_detailOpen)
              Container(
                color: Colors.white,
                child: Column(
                  children: [
                    if (_draft.hasTrial)
                      _linkRow('试戴', _trialText(), () async {
                        final changed = await _push<bool>(
                          TrialEditPage(repo: widget.repo, draft: _draft),
                        );
                        if (changed == true) setState(() {});
                      }),
                    _linkRow('设计', _designText(), () async {
                      final changed = await _push<bool>(
                        DesignEditPage(repo: widget.repo, draft: _draft),
                      );
                      if (changed == true) setState(() {});
                    }),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            _foldBanner(
              title: '附件内容',
              icon: _attachOpen ? 'icon_placeorder_附件内容_white' : 'icon_order_icon_附件内容',
              tip: '展开填写【附件、质保卡】等信息',
              open: _attachOpen,
              whiteTitle: _attachOpen,
              onTap: () => setState(() => _attachOpen = !_attachOpen),
            ),
            if (_attachOpen)
              Container(
                color: Colors.white,
                child: Column(
                  children: [
                    _linkRow('附件', _attachmentText(), () async {
                      final changed = await _push<bool>(
                        AttachmentEditPage(repo: widget.repo, draft: _draft),
                      );
                      if (changed == true) setState(() {});
                    }),
                    if (_draft.hasWarranty)
                      SwitchListTile(
                        title: const Text('打印实体质保卡', style: TextStyle(fontSize: 14)),
                        value: _draft.printPhysicalCard,
                        activeThumbColor: orderBlue,
                        onChanged: (value) =>
                            setState(() => _draft.printPhysicalCard = value),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            _remarkCard(),
          ],
        ],
      ),
    );
  }

  Widget _submitBar(bool visible) {
    return ColoredBox(
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 80,
          child: visible
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: FilledButton(
                    onPressed: _submitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: orderBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    child: Text(
                      _submitting ? '提交中' : '提交订单',
                      style: const TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _headerCard() {
    final hospital = field(widget.hospital, const ['fullName', 'smallName', 'name']);
    final doctor = field(widget.doctor, const ['name', 'doctorName']);
    final factory = field(widget.factory, const ['factoryName', 'name']);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          _infoLine('执行单位', hospital),
          _infoLine('医生姓名', doctor),
          _infoLine('生产单位', factory),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              children: [
                const SizedBox(
                  width: 74,
                  height: 44,
                  child: Padding(
                    padding: EdgeInsets.only(left: 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('患者姓名', style: TextStyle(fontSize: 12, color: orderInk)),
                    ),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _name,
                    style: const TextStyle(fontSize: 12),
                    decoration: const InputDecoration(
                      hintText: '请输入患者姓名',
                      hintStyle: TextStyle(fontSize: 12, color: orderMuted),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                _sexButton('男', 1),
                const SizedBox(width: 8),
                _sexButton('女', 2),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() => _patientOpen = !_patientOpen),
                  child: Row(
                    children: [
                      Text(
                        _patientOpen ? '收起' : '展开',
                        style: const TextStyle(color: orderTitleBlue, fontSize: 12),
                      ),
                      OrderIcon(
                        'icon_place_order_arrow_blue',
                        width: 12,
                        height: 12,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_patientOpen)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: Row(
                children: [
                  Expanded(child: _grayField(_phone, '患者手机号（选填）', TextInputType.phone)),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 128,
                    child: _grayField(
                      _age,
                      '患者年龄（选填）',
                      TextInputType.number,
                      digits: true,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _infoLine(String label, String value) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          SizedBox(
            width: 74,
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text(label, style: const TextStyle(fontSize: 12, color: orderInk)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: orderInk,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 12),
            child: OrderIcon('icon_place_order_arrow_gray', width: 12, height: 12),
          ),
        ],
      ),
    );
  }

  Widget _sexButton(String text, int value) {
    final selected = _draft.patientSex == value;
    return GestureDetector(
      onTap: () => setState(() => _draft.patientSex = value),
      child: Container(
        width: 52,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? orderTitleBlue : orderFieldBg,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 14,
            color: selected ? Colors.white : orderInk,
          ),
        ),
      ),
    );
  }

  Widget _grayField(
    TextEditingController controller,
    String hint,
    TextInputType type, {
    bool digits = false,
  }) {
    return Container(
      height: 32,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: orderFieldBg,
      child: TextField(
        controller: controller,
        keyboardType: type,
        inputFormatters: digits ? [FilteringTextInputFormatter.digitsOnly] : null,
        style: const TextStyle(fontSize: 12),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 12, color: orderMuted),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _banner(String title, {bool add = false, VoidCallback? onAdd}) {
    return SizedBox(
      height: 42,
      child: Stack(
        children: [
          const Positioned(
            left: 0,
            top: 0,
            child: OrderIcon('icon_place_order_section_bg', width: 119, height: 42),
          ),
          Positioned(
            left: 16,
            top: 0,
            bottom: 0,
            child: Center(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          if (add)
            Positioned(
              right: 12,
              top: 0,
              bottom: 0,
              child: GestureDetector(
                onTap: onAdd,
                child: const OrderIcon(
                  'icon_place_order_section_add_item',
                  width: 18,
                  height: 18,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _foldBanner({
    required String title,
    required String icon,
    required String tip,
    required bool open,
    required bool whiteTitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 42,
        color: open ? orderTitleBlue : Colors.white,
        child: Row(
          children: [
            const SizedBox(width: 12),
            OrderIcon(icon, width: 16, height: 16),
            const SizedBox(width: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: whiteTitle ? Colors.white : orderTitleBlue,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                open ? '' : tip,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: Color(0xFFBFBFC0)),
              ),
            ),
            OrderIcon(
              open ? 'icon_order_icon_arrow_收起' : 'icon_order_icon_带背板展开',
              width: 18,
              height: 18,
            ),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }

  Widget _productCard(int index) {
    final product = _draft.products[index];
    final tags = <Widget>[];
    if (product.teeth.any((item) => item.productionType == 1)) {
      tags.add(_tag('新做', const Color(0xFFE8F5FF), orderBlue));
    }
    if (product.teeth.any((item) => item.productionType == 2)) {
      tags.add(_tag('返工', const Color(0xFFFEEDEA), const Color(0xFFFA4D32)));
    }
    if (product.teeth.any((item) => item.productionType == 3)) {
      tags.add(_tag('返修', const Color(0xFFFFF6E8), const Color(0xFFFFAB1A)));
    }
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 8, 0, 0),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: orderChipBg, width: 4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name, maxLines: 2, style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 8),
                Wrap(spacing: 6, children: tags),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Stack(
            clipBehavior: Clip.none,
            children: [
              GestureDetector(
                onTap: () => _editTooth(index),
                child: ToothCrossView(teeth: product.teeth.map((item) => item.code).toList()),
              ),
              Positioned(
                right: 0,
                top: 0,
                child: GestureDetector(
                  onTap: () => setState(() {
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
                  child: const OrderIcon('icon_order_product_delete', width: 16, height: 16),
                ),
              ),
              Positioned(
                right: 4,
                top: 20,
                child: GestureDetector(
                  onTap: () => _editTooth(index),
                  child: const OrderIcon('icon_order_product_edit', width: 14, height: 14),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tag(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      color: bg,
      child: Text(text, style: TextStyle(fontSize: 12, color: fg)),
    );
  }

  Widget _connectCard() {
    return _optionCard(
      title: '*连接方式',
      buttons: [
        ('全部单独', 0),
        ('全部连体', 1),
        ('分段', 2),
      ],
      selected: _draft.connectType,
      onSelect: (value) {
        setState(() => _draft.connectType = value);
        if (value == 2) _openSegments();
      },
      extra: _draft.connectType == 2
          ? Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: GestureDetector(
                onTap: _openSegments,
                child: Text(
                  _draft.segments.isEmpty
                      ? '请完成分段牙位'
                      : _draft.segments.map((item) => item.join('|')).join('，'),
                  style: const TextStyle(fontSize: 12, color: orderTitleBlue),
                ),
              ),
            )
          : null,
    );
  }

  Widget _mouldCard() {
    return _optionCard(
      title: '*取模方式',
      buttons: const [
        ('常规取模', 1),
        ('工厂灌硅胶', 8),
        ('口内扫描', 2),
      ],
      selected: _draft.obtainMould,
      onSelect: _draft.canChoiceMould
          ? (value) => setState(() => _draft.obtainMould = value)
          : null,
      extra: _draft.obtainMould == 2
          ? Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 12, 12),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _draft.takeAttachments = !_draft.takeAttachments),
                    child: Row(
                      children: [
                        const SizedBox(width: 72),
                        OrderIcon(
                          _draft.takeAttachments
                              ? 'icon_order_未选_上门取附件'
                              : 'icon_order_已选_上门取附件',
                          width: 14,
                          height: 14,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          '请接送人员上门取附件',
                          style: TextStyle(fontSize: 12, color: orderTitleBlue),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Text('发送方式', style: TextStyle(fontSize: 12, color: orderInk)),
                      const SizedBox(width: 12),
                      Expanded(child: _arrowBox(_brandText(), _pickBrand)),
                      const SizedBox(width: 9),
                      Expanded(child: _arrowBox(_sendText(), _pickSendWay)),
                    ],
                  ),
                ],
              ),
            )
          : null,
    );
  }

  Widget _optionCard({
    required String title,
    required List<(String, int)> buttons,
    required int selected,
    required ValueChanged<int>? onSelect,
    Widget? extra,
  }) {
    final star = title.startsWith('*');
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: orderChipBg, width: 4),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    if (star)
                      const TextSpan(
                        text: '*',
                        style: TextStyle(color: Color(0xFFFA4D32), fontSize: 12),
                      ),
                    TextSpan(
                      text: star ? title.substring(1) : title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: orderInk,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              for (final item in buttons) ...[
                Expanded(
                  child: OrderChoiceButton(
                    text: item.$1,
                    selected: selected == item.$2,
                    onTap: onSelect == null ? null : () => onSelect(item.$2),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
          ?extra,
        ],
      ),
    );
  }

  Widget _arrowBox(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 32,
        padding: const EdgeInsets.only(left: 8),
        color: orderFieldBg,
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: text.contains('请选择') || text == '口扫品牌' || text == '发送方式'
                      ? orderMuted
                      : orderInk,
                ),
              ),
            ),
            const OrderIcon('icon_place_order_arrow_gray', width: 18, height: 18),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  Widget _colorCard() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const OrderIcon('icon_order_choice_颜色', width: 16, height: 16),
          const SizedBox(width: 4),
          const Text('颜色', style: TextStyle(fontSize: 12, color: orderInk)),
          const Spacer(),
          GestureDetector(
            onTap: () async {
              final changed = await _push<bool>(
                ColorEditPage(repo: widget.repo, draft: _draft),
              );
              if (changed == true) setState(() {});
            },
            child: Container(
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: orderBlue,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Row(
                children: [
                  Text('添加色板', style: TextStyle(color: Colors.white, fontSize: 12)),
                  SizedBox(width: 2),
                  OrderIcon('icon_add_colorPlate', width: 12, height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _linkRow(String title, String value, VoidCallback onTap) {
    return ListTile(
      dense: true,
      title: Text(title, style: const TextStyle(fontSize: 14)),
      subtitle: Text(value, style: const TextStyle(fontSize: 12)),
      trailing: const OrderIcon('icon_place_order_arrow_gray', width: 12, height: 12),
      onTap: onTap,
    );
  }

  Widget _remarkCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _menuButton('icon_colorimetric', '比色照片', onTap: () async {
                await pickOrderPhotos(context, _draft.colorimetricPhotos);
                if (mounted) setState(() {});
              }),
              const SizedBox(width: 11),
              _menuButton('icon_order_icon_照片上传', '其他图片', onTap: () async {
                await pickOrderPhotos(context, _draft.otherPhotos);
                if (mounted) setState(() {});
              }),
              const SizedBox(width: 11),
              _menuButton('icon_order_icon_录音备注', '录音备注', onTap: () async {
                await recordOrderAudio(context, _draft.audios);
                if (mounted) setState(() {});
              }),
              const SizedBox(width: 11),
              _menuButton('icon_order_icon_文字备注', '文字备注', onTap: _editRemark),
            ],
          ),
          _mediaPreview('比色', _draft.colorimetricPhotos),
          _mediaPreview('图片', _draft.otherPhotos),
          if (_draft.audios.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '录音 ${_draft.audios.length} 条',
                  style: const TextStyle(fontSize: 12, color: orderTitleBlue),
                ),
              ),
            ),
          if (_remark.text.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _remark.text.trim(),
                style: const TextStyle(fontSize: 12, color: orderInk),
              ),
            ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _openAddress,
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F7FA),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  const OrderIcon('icon_order_icon_地址_16pt', width: 16, height: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _addressText(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, color: orderInk),
                    ),
                  ),
                  const OrderIcon('icon_place_order_arrow_gray', width: 18, height: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuButton(String icon, String title, {VoidCallback? onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap ?? () => _tip('请在下单备注中补充$title'),
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            color: orderChipBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OrderIcon(icon, width: 18, height: 18),
              const SizedBox(height: 4),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: orderTitleBlue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mediaPreview(String title, List<String> photos) {
    if (photos.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            Text(title, style: const TextStyle(fontSize: 12, color: orderTitleBlue)),
            const SizedBox(width: 8),
            Expanded(
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: photos.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (_, index) => ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.file(File(photos[index]), width: 48, height: 48, fit: BoxFit.cover),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editRemark() async {
    final text = await editOrderRemark(
      context,
      initial: _remark.text,
      repo: widget.repo,
      factoryId: _draft.factoryId,
      hospitalDoctorId: _draft.hospitalDoctorId,
    );
    if (text == null || !mounted) return;
    setState(() => _remark.text = text);
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

  String _brandText() {
    if (_draft.scanBrand == null) return '口扫品牌';
    final name = field(_draft.scanBrand!, const ['name', 'brandName']);
    return name.isEmpty ? '口扫品牌' : name;
  }

  String _sendText() => _draft.sendWayName.isEmpty ? '发送方式' : _draft.sendWayName;

  String _reasonText() {
    if (_draft.reason == null) return '请选择';
    return field(_draft.reason!, const ['name', 'phenomenonName']);
  }

  String _designText() {
    if (_draft.designs.isEmpty) return '可选';
    return _draft.designs
        .map((item) => field(item, const ['name', 'designName']))
        .where((item) => item.isNotEmpty)
        .join('、');
  }

  String _attachmentText() {
    if (_draft.attachments.isEmpty) return '可选';
    return _draft.attachments
        .map(
          (item) =>
              '${field(item, const ['name', 'enclosureName'])} x${asInt(item['number'])}',
        )
        .join('、');
  }

  String _plantText() {
    final names = <String>[];
    for (final product in _draft.products.where((item) => item.isPlant)) {
      for (final plant in product.plants) {
        final name = field(plant, const ['plantSystemName']);
        names.add('${field(plant, const ['toothSingle'])}${name.isEmpty ? '未选' : name}');
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
}
