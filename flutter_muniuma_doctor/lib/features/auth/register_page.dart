import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_muniuma_doctor/core/config/app_config.dart';
import 'package:flutter_muniuma_doctor/core/network/api_client.dart';
import 'package:flutter_muniuma_doctor/features/auth/auth_repository.dart';
import 'package:flutter_muniuma_doctor/features/auth/captcha_sheet.dart';
import 'package:flutter_muniuma_doctor/features/auth/login_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key, required this.auth});

  final AuthRepository auth;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _hospital = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _province = TextEditingController();
  final _city = TextEditingController();
  final _district = TextEditingController();
  final _salesman = TextEditingController();
  final _certificate = TextEditingController();
  bool _isDoctor = true;
  int _seconds = 0;
  Timer? _timer;
  bool _loading = false;

  @override
  void dispose() {
    _timer?.cancel();
    for (final controller in [
      _hospital,
      _name,
      _phone,
      _code,
      _province,
      _city,
      _district,
      _salesman,
      _certificate,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _send() async {
    if (_seconds > 0) return;
    if (!isPhone(_phone.text.trim())) {
      showTip(context, '请输入正确的手机号');
      return;
    }
    final sent = await verifyAndSendCode(
      context: context,
      auth: widget.auth,
      send: (guid, x) => widget.auth.sendSceneCode(
        phone: _phone.text.trim(),
        guid: guid,
        x: x,
        smsType: AppConfig.smsTypeRegister,
      ),
    );
    if (!sent || !mounted) return;
    showTip(context, '验证码已发送');
    setState(() => _seconds = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_seconds <= 1) {
        timer.cancel();
        setState(() => _seconds = 0);
      } else {
        setState(() => _seconds -= 1);
      }
    });
  }

  Future<void> _submit() async {
    if (_hospital.text.trim().isEmpty ||
        _name.text.trim().isEmpty ||
        _phone.text.trim().isEmpty ||
        _code.text.trim().isEmpty) {
      showTip(context, '请完整填写单位、姓名、手机号和验证码');
      return;
    }
    setState(() => _loading = true);
    try {
      await widget.auth.register({
        'phoneCode': _code.text.trim(),
        'name': _name.text.trim(),
        'identity': _isDoctor ? 1 : 2,
        'tel': _phone.text.trim(),
        'hospital': _hospital.text.trim(),
        'province': _province.text.trim(),
        'city': _city.text.trim(),
        'district': _district.text.trim(),
        'provinceCode': '',
        'cityCode': '',
        'districtCode': '',
        'countryCode': '',
        'country': '',
        if (_salesman.text.trim().isNotEmpty) 'salesmanName': _salesman.text.trim(),
        if (_certificate.text.trim().isNotEmpty)
          'certificateCode': _certificate.text.trim(),
      });
      if (!mounted) return;
      showTip(context, '提交成功，48小时内客服将与您联系！');
      Navigator.pop(context);
    } on ApiException catch (error) {
      if (mounted) showTip(context, error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('注册')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _hospital, decoration: const InputDecoration(labelText: '单位名称')),
          TextField(controller: _name, decoration: const InputDecoration(labelText: '姓名')),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('医生')),
              ButtonSegment(value: false, label: Text('其他')),
            ],
            selected: {_isDoctor},
            onSelectionChanged: (value) => setState(() => _isDoctor = value.first),
          ),
          TextField(controller: _province, decoration: const InputDecoration(labelText: '省')),
          TextField(controller: _city, decoration: const InputDecoration(labelText: '市')),
          TextField(controller: _district, decoration: const InputDecoration(labelText: '区')),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: '手机号码'),
          ),
          TextField(
            controller: _code,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: '短信验证码',
              suffixIcon: TextButton(
                onPressed: _seconds > 0 ? null : _send,
                child: Text(_seconds > 0 ? '${_seconds}s' : '获取验证码'),
              ),
            ),
          ),
          TextField(
            controller: _certificate,
            decoration: const InputDecoration(labelText: '医师资格证书编号'),
          ),
          TextField(controller: _salesman, decoration: const InputDecoration(labelText: '业务员')),
          const SizedBox(height: 24),
          SizedBox(
            height: 48,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: themeBlue),
              onPressed: _loading ? null : _submit,
              child: const Text('提交'),
            ),
          ),
        ],
      ),
    );
  }
}
