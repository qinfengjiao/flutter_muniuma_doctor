import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_muniuma_doctor/core/crypto/des_util.dart';
import 'package:flutter_muniuma_doctor/core/session/app_session.dart';
import 'package:flutter_muniuma_doctor/features/auth/auth_repository.dart';
import 'package:flutter_muniuma_doctor/features/auth/login_page.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_muniuma_doctor/core/network/api_client.dart';

void main() {
  test('password DES matches iOS zero padding', () {
    final cipher = encryptUseDes('abc');
    expect(cipher, 'zPQbEDOQO1g=');
    final plain = utf8.decode(
      decryptUseDes(cipher).where((byte) => byte != 0).toList(),
    );
    expect(plain, 'abc');
  });

  testWidgets('login page shows title', (tester) async {
    final session = AppSession()
      ..ready = true
      ..agreedProtocol = true;
    await tester.pumpWidget(
      MaterialApp(
        home: LoginPage(
          session: session,
          auth: AuthRepository(ApiClient(session), session),
        ),
      ),
    );
    expect(find.text('木牛马系统'), findsOneWidget);
    expect(find.text('登录'), findsOneWidget);
  });
}
