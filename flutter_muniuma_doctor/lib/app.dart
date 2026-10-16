import 'package:flutter/material.dart';
import 'package:flutter_muniuma_doctor/core/network/api_client.dart';
import 'package:flutter_muniuma_doctor/core/session/app_session.dart';
import 'package:flutter_muniuma_doctor/features/auth/auth_repository.dart';
import 'package:flutter_muniuma_doctor/features/auth/login_page.dart';
import 'package:flutter_muniuma_doctor/features/shell/main_shell_page.dart';
import 'package:flutter_muniuma_doctor/features/workbench/workbench_repository.dart';

class MuniumaApp extends StatefulWidget {
  const MuniumaApp({super.key, required this.session});

  final AppSession session;

  @override
  State<MuniumaApp> createState() => _MuniumaAppState();
}

class _MuniumaAppState extends State<MuniumaApp> {
  late final ApiClient _api = ApiClient(widget.session);
  late final AuthRepository _auth = AuthRepository(_api, widget.session);
  late final WorkbenchRepository _workbench =
      WorkbenchRepository(_api, widget.session);

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_rebuild);
  }

  @override
  void dispose() {
    widget.session.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '木牛马医生',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: themeBlue),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF2C2C2E),
          elevation: 0,
          centerTitle: true,
        ),
      ),
      home: !widget.session.ready
          ? const _Splash()
          : widget.session.isLoggedIn
              ? MainShellPage(session: widget.session, repo: _workbench)
              : LoginPage(session: widget.session, auth: _auth),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: themeBlue,
      body: Center(
        child: Text(
          '木牛马系统',
          style: TextStyle(color: Colors.white, fontSize: 24),
        ),
      ),
    );
  }
}
