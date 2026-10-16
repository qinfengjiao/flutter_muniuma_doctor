import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_muniuma_doctor/core/config/app_config.dart';
import 'package:flutter_muniuma_doctor/core/network/api_client.dart';
import 'package:flutter_muniuma_doctor/core/session/app_session.dart';
import 'package:flutter_muniuma_doctor/features/auth/auth_repository.dart';
import 'package:flutter_muniuma_doctor/features/auth/captcha_sheet.dart';
import 'package:flutter_muniuma_doctor/features/auth/register_page.dart';
import 'package:flutter_muniuma_doctor/features/auth/reset_password_page.dart';
import 'package:flutter_muniuma_doctor/features/common/simple_web_page.dart';

const themeBlue = Color(0xFF007FFF);

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.session, required this.auth});

  final AppSession session;
  final AuthRepository auth;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late final TextEditingController _account = TextEditingController(
    text: widget.session.savedAccount,
  );
  late final TextEditingController _password = TextEditingController(
    text: widget.session.savedPassword,
  );
  final _phone = TextEditingController();
  final _code = TextEditingController();
  bool _phoneLogin = false;
  bool _agree = false;
  bool _obscure = true;
  bool _loading = false;
  int _seconds = 0;
  int _debugTaps = 0;
  DateTime? _lastDebugTap;
  Timer? _timer;
  String? _accountError;
  String? _secretError;

  @override
  void initState() {
    super.initState();
    if (!widget.session.agreedProtocol) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showProtocol(force: true));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _account.dispose();
    _password.dispose();
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _accountError = null;
      _secretError = null;
    });
    if (_phoneLogin) {
      if (_phone.text.isEmpty) {
        showTip(context, '请输入手机号');
        return;
      }
      if (_code.text.isEmpty) {
        showTip(context, '请输入验证码');
        return;
      }
      if (!isPhone(_phone.text)) {
        setState(() => _accountError = '手机号格式不正确');
        return;
      }
      if (_code.text.length != 4 && _code.text.length != 6) {
        setState(() => _secretError = '验证码格式不正确');
        return;
      }
    } else {
      if (_account.text.isEmpty) {
        showTip(context, '请输入账号');
        return;
      }
      if (_account.text.length < 2) return;
      if (_password.text.isEmpty) {
        showTip(context, '请输入密码');
        return;
      }
    }
    if (!_agree) {
      await _showProtocol(force: false);
      if (!_agree) return;
    }
    setState(() => _loading = true);
    try {
      if (_phoneLogin) {
        await widget.auth.loginWithSms(_phone.text.trim(), _code.text.trim());
      } else {
        await widget.auth.loginWithPassword(
          _account.text.trim(),
          _password.text,
        );
      }
    } on ApiException catch (error) {
      if (mounted) showTip(context, error.message);
    } catch (_) {
      if (mounted) showTip(context, '操作失败, 请稍候重试~');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendCode() async {
    if (_seconds > 0) return;
    if (!isPhone(_phone.text.trim())) {
      setState(() => _accountError = _phone.text.isEmpty ? '请输入手机号!' : '手机号格式不正确');
      return;
    }
    setState(() => _accountError = null);
    final sent = await verifyAndSendCode(
      context: context,
      auth: widget.auth,
      send: (guid, x) => widget.auth.sendLoginCode(_phone.text.trim(), guid, x),
    );
    if (!sent || !mounted) return;
    showTip(context, '验证码已发送');
    setState(() => _seconds = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_seconds <= 1) {
        timer.cancel();
        setState(() => _seconds = 0);
      } else {
        setState(() => _seconds -= 1);
      }
    });
  }

  Future<void> _showProtocol({required bool force}) async {
    final agreed = await showDialog<bool>(
      context: context,
      barrierDismissible: !force,
      builder: (context) => const _ProtocolDialog(),
    );
    if (agreed == true) {
      await widget.session.setAgreedProtocol();
      if (mounted) setState(() => _agree = true);
    } else if (force) {
      await SystemNavigator.pop();
    }
  }

  Future<void> _onSloganTap() async {
    final now = DateTime.now();
    if (_lastDebugTap == null ||
        now.difference(_lastDebugTap!) > const Duration(seconds: 1)) {
      _debugTaps = 0;
    }
    _lastDebugTap = now;
    _debugTaps += 1;
    if (_debugTaps < 3) return;
    _debugTaps = 0;
    await _switchEnv();
  }

  Future<void> _switchEnv() async {
    final next = (widget.session.envIndex + 1) % AppConfig.envs.length;
    await widget.session.setEnv(next);
    if (mounted) showTip(context, '已切换到${widget.session.env.name}环境');
  }

  @override
  Widget build(BuildContext context) {
    final version = '版本号 v1.0.0';
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _Header(
            phoneLogin: _phoneLogin,
            onChanged: (value) => setState(() => _phoneLogin = value),
            onDebug: () {
              _onSloganTap();
            },
          ),
          Expanded(
            child: Transform.translate(
              offset: const Offset(0, -18),
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                  children: [
                    if (_phoneLogin) ...[
                      _Field(
                        label: '手机号',
                        hint: '请输入手机号',
                        controller: _phone,
                        error: _accountError,
                        keyboardType: TextInputType.phone,
                      ),
                      _Field(
                        label: '验证码',
                        hint: '请输入验证码',
                        controller: _code,
                        error: _secretError,
                        keyboardType: TextInputType.number,
                        suffix: TextButton(
                          onPressed: _seconds > 0 ? null : _sendCode,
                          child: Text(_seconds > 0 ? '${_seconds}s' : '获取验证码'),
                        ),
                      ),
                    ] else ...[
                      _Field(
                        label: '账号',
                        hint: '请输入账号',
                        controller: _account,
                        error: _accountError,
                      ),
                      _Field(
                        label: '密码',
                        hint: '请输入密码',
                        controller: _password,
                        error: _secretError,
                        obscure: _obscure,
                        suffix: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure ? Icons.visibility_off : Icons.visibility,
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ResetPasswordPage(auth: widget.auth),
                              ),
                            );
                          },
                          child: const Text('忘记密码'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 48,
                      child: FilledButton(
                        onPressed: _loading ? null : _login,
                        style: FilledButton.styleFrom(
                          backgroundColor: themeBlue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('登录', style: TextStyle(fontSize: 18)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 48,
                      child: FilledButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RegisterPage(auth: widget.auth),
                            ),
                          );
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFF7F8F9),
                          foregroundColor: const Color(0xFF2C2C2E),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('注册', style: TextStyle(fontSize: 18)),
                      ),
                    ),
                    const SizedBox(height: 26),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: () => setState(() => _agree = !_agree),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _agree
                                    ? Icons.check_box
                                    : Icons.check_box_outline_blank,
                                size: 18,
                                color: _agree ? themeBlue : const Color(0xFF949495),
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                '我已阅读并同意',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF949495),
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _openAgreement('服务协议', AppConfig.serviceAgreementUrl),
                          child: const Text(
                            '《服务协议》',
                            style: TextStyle(fontSize: 12, color: Color(0xFF414142)),
                          ),
                        ),
                        const Text('和', style: TextStyle(fontSize: 12)),
                        GestureDetector(
                          onTap: () => _openAgreement('隐私协议', AppConfig.privacyAgreementUrl),
                          child: const Text(
                            '《隐私协议》',
                            style: TextStyle(fontSize: 12, color: Color(0xFF414142)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Center(
                      child: Text(
                        version,
                        style: const TextStyle(fontSize: 10, color: Color(0xFF414142)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openAgreement(String title, String url) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SimpleWebPage(title: title, url: url)),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.phoneLogin,
    required this.onChanged,
    required this.onDebug,
  });

  final bool phoneLogin;
  final ValueChanged<bool> onChanged;
  final VoidCallback onDebug;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(32, MediaQuery.paddingOf(context).top + 30, 32, 36),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF4AA8FF), Color(0xFF007FFF)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '木牛马系统',
            style: TextStyle(color: Colors.white, fontSize: 20, height: 1.4),
          ),
          GestureDetector(
            onTap: onDebug,
            child: const Text(
              '沟通便捷，出件迅速！',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 36),
          Row(
            children: [
              _Tab(
                title: '账户密码登录',
                selected: !phoneLogin,
                onTap: () => onChanged(false),
              ),
              const SizedBox(width: 36),
              _Tab(
                title: '短信验证码登录',
                selected: phoneLogin,
                onTap: () => onChanged(true),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFFE7F5FE),
              fontSize: selected ? 16 : 14,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          const SizedBox(height: 6),
          Icon(
            Icons.arrow_drop_up,
            color: selected ? Colors.white : Colors.transparent,
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.hint,
    required this.controller,
    this.error,
    this.obscure = false,
    this.keyboardType,
    this.suffix,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final String? error;
  final bool obscure;
  final TextInputType? keyboardType;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: Color(0xFF2C2C2E))),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            obscureText: obscure,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              hintText: hint,
              filled: true,
              fillColor: const Color(0xFFF7F8F9),
              suffixIcon: suffix,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
            ),
        ],
      ),
    );
  }
}

class _ProtocolDialog extends StatelessWidget {
  const _ProtocolDialog();

  static const _text =
      '本个人信息保护指引将通过《服务协议》与《隐私协议》帮助你了解我们的如何收集、处理个人信息。\n'
      '1.我们可能会申请系统设备权限收集设备信息、日志信息，用于推送、信息查询、内容分享等服务，并申请存储权限，用于下载及缓存相关文件。\n'
      '2.麦克风、相册（上传、存储）等权限均不会默认或者强制开启收集信息。你有权拒绝开启，拒绝授权不会影响APP提供基本服务。\n'
      '3.木牛马提供以AI对话为核心功能的技术服务，该技术服务由智谱清言(ChatGLM)大模型提供。木牛马提倡用户遵守相关法律法规政策，不得使用本服务从事违法活动。\n'
      '模型名称：智谱清言(ChatGLM)\n'
      '备案编号：Beijing-ChatGLM-20230821\n'
      '如你同意，请点击“同意”，开始接受我们的服务。';

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Text(
                '欢迎使用  木牛马',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Text(_text, style: const TextStyle(fontSize: 14, height: 1.5)),
              ),
            ),
            const Divider(height: 1),
            SizedBox(
              height: 48,
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('暂不使用', style: TextStyle(color: Colors.grey)),
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('同意'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
