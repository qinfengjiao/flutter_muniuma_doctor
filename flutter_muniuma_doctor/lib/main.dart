import 'package:flutter/material.dart';
import 'package:flutter_muniuma_doctor/app.dart';
import 'package:flutter_muniuma_doctor/core/session/app_session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final session = AppSession();
  runApp(MuniumaApp(session: session));
  await session.load();
}
