import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_muniuma_doctor/core/config/app_config.dart';
import 'package:flutter_muniuma_doctor/core/network/api_client.dart';
import 'package:flutter_muniuma_doctor/features/auth/auth_repository.dart';
import 'package:flutter_muniuma_doctor/features/auth/captcha_sheet.dart';
import 'package:flutter_muniuma_doctor/features/auth/login_page.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key, required this.auth});

  final AuthRepository auth;

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  int _seconds = 0;
  Timer? _timer;
  bool _loading = false;

  @override
  void dispose() {
    _timer?.cancel();
    _phone.dispose();
    _code.dispose();
    _password.dispose();
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
        smsType: AppConfig.smsTypeResetPassword,
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
    if (_phone.text.isEmpty) {
      showTip(context, '请输入手机号');
      return;
    }
    if (_code.text.isEmpty) {
      showTip(context, '请输入验证码');
      return;
    }
    if (!isPasswordValid(_password.text)) {
      showTip(context, '密码格式错误');
      return;
    }
    setState(() => _loading = true);
    try {
      await widget.auth.resetPassword(
        phone: _phone.text.trim(),
        code: _code.text.trim(),
        password: _password.text,
      );
      if (!mounted) return;
      showTip(context, '设置成功');
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
      appBar: AppBar(title: const Text('重置密码')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '使用绑定的手机号找回密码',
            style: TextStyle(color: Color(0xFF2C2C2E)),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: '手机号', hintText: '请输入账号绑定的手机号'),
          ),
          TextField(
            controller: _code,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: '验证码',
              hintText: '请输入验证码',
              suffixIcon: TextButton(
                onPressed: _seconds > 0 ? null : _send,
                child: Text(_seconds > 0 ? '${_seconds}s' : '获取验证码'),
              ),
            ),
          ),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: '新密码',
              hintText: '请输入新密码',
              helperText: '字母+数字；大于8位',
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 48,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: themeBlue),
              onPressed: _loading ? null : _submit,
              child: const Text('确定'),
            ),
          ),
        ],
      ),
    );
  }
}
