import 'dart:convert';

import 'package:flutter_muniuma_doctor/core/config/app_config.dart';
import 'package:flutter_muniuma_doctor/core/crypto/des_util.dart';
import 'package:flutter_muniuma_doctor/core/network/api_client.dart';
import 'package:flutter_muniuma_doctor/core/session/app_session.dart';

class CaptchaChallenge {
  CaptchaChallenge({
    required this.guid,
    required this.background,
    required this.slider,
  });

  final String guid;
  final String background;
  final String slider;
}

class AuthRepository {
  AuthRepository(this.api, this.session);

  final ApiClient api;
  final AppSession session;

  Future<void> loginWithPassword(String account, String password) async {
    final data = asMap(
      await api.get(
        'Authen/Authorization/GetToken',
        query: {
          'LoginName': account,
          'LoginPassWord': encryptUseDes(password),
          'LoginType': AppConfig.loginTypePassword,
          'LoginClient': AppConfig.loginClientDoctor,
        },
      ),
    );
    await session.saveLogin(data);
    await session.rememberPasswordLogin(account, password);
    await _finishLogin();
  }

  Future<void> loginWithSms(String phone, String code) async {
    final data = asMap(
      await api.get(
        'Authen/Authorization/GetToken',
        query: {
          'PhoneNumber': phone,
          'Code': code,
          'LoginType': AppConfig.loginTypeSms,
          'LoginClient': AppConfig.loginClientDoctor,
        },
      ),
    );
    await session.saveLogin(data);
    await _finishLogin();
  }

  Future<void> _finishLogin() async {
    try {
      final im = asMap(
        await api.get('Authen/Authorization/GetV3TokenConvertImToken'),
      );
      if (im.isNotEmpty) await session.saveIm(im);
    } catch (_) {}
    try {
      final hospital = asMap(await api.get('user/Hospital/GetHospital'));
      if (hospital.isNotEmpty) await session.saveHospital(hospital);
    } catch (_) {}
  }

  Future<CaptchaChallenge> fetchCaptcha() async {
    final data = await api.get('Authen/SlideVerify/GetCaptcha');
    final map = asMap(data is String ? jsonDecode(data) : data);
    return CaptchaChallenge(
      guid: map['guidstr']?.toString() ?? '',
      background: map['background']?.toString() ?? '',
      slider: map['slider']?.toString() ?? '',
    );
  }

  Future<void> checkCaptcha(String guid, int x) async {
    await api.get(
      'sms/Sms/CheckCaptcha',
      query: {'GuidStr': guid, 'x': x},
    );
  }

  Future<void> sendLoginCode(String phone, String guid, int x) async {
    await api.get(
      'sms/Sms/GetPhoneLoginCode',
      query: {
        'Phone': phone,
        'GuidStr': guid,
        'CheckCaptchaX': x,
        'LoginClient': AppConfig.loginClientDoctor,
      },
    );
  }

  Future<void> sendSceneCode({
    required String phone,
    required String guid,
    required int x,
    required int smsType,
  }) async {
    await api.get(
      'sms/Sms/GetPhoneCode',
      query: {
        'Phone': phone,
        'GuidStr': guid,
        'CheckCaptchaX': x,
        'SmsType': smsType,
      },
    );
  }

  Future<void> resetPassword({
    required String phone,
    required String code,
    required String password,
  }) async {
    await api.post(
      'user/User/ResetPassword',
      body: {
        'phoneNumber': phone,
        'phoneCode': code,
        'newPassWord': encryptUseDes(password),
      },
    );
  }

  Future<void> register(Map<String, dynamic> body) async {
    await api.post('user/Doctor/RegisterDoctor', body: body);
  }
}
