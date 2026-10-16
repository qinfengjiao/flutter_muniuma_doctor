import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_muniuma_doctor/core/config/app_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSession extends ChangeNotifier {
  static const _tokenKey = 'header_user_token';
  static const _imTokenKey = 'im_token';
  static const _loginKey = 'user_data_json';
  static const _hospitalKey = 'hospital_json';
  static const _accountKey = 'login_account';
  static const _passwordKey = 'login_password';
  static const _envKey = 'server_env';
  static const _protocolKey = 'agreed_protocol';

  bool ready = false;
  String token = '';
  String imToken = '';
  Map<String, dynamic> login = {};
  Map<String, dynamic> hospital = {};
  String savedAccount = '';
  String savedPassword = '';
  int envIndex = 0;
  bool agreedProtocol = false;

  bool get isLoggedIn => token.isNotEmpty;
  AppEnv get env => AppConfig.envs[envIndex.clamp(0, AppConfig.envs.length - 1)];

  String get hospitalId => fieldOf(hospital, const ['id', 'Id']);
  String get hospitalDoctorId => hospital['hospitalDoctorId']?.toString() ?? '';
  String get hospitalName {
    final name = fieldOf(hospital, const ['fullName', 'smallName']);
    return name.isEmpty ? '未选择诊所' : name;
  }

  Map<String, dynamic> get user {
    final value = login['user'];
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  String get userName {
    final name = user['name']?.toString() ?? '';
    if (name.isNotEmpty) return name;
    return login['userName']?.toString() ?? '';
  }

  String get phone => user['phoneNumber']?.toString() ?? '';
  String get avatar => user['headPortraitCos']?.toString() ?? '';

  int? get imIdentity {
    final list = login['identityList'];
    if (list is! List || list.isEmpty) return null;
    final last = list.last;
    if (last is Map) return int.tryParse('${last['imIdentity']}');
    return null;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString(_tokenKey) ?? '';
    imToken = prefs.getString(_imTokenKey) ?? '';
    savedAccount = prefs.getString(_accountKey) ?? '';
    savedPassword = prefs.getString(_passwordKey) ?? '';
    envIndex = prefs.getInt(_envKey) ?? 0;
    agreedProtocol = prefs.getBool(_protocolKey) ?? false;
    login = _decodeMap(prefs.getString(_loginKey));
    hospital = _decodeMap(prefs.getString(_hospitalKey));
    ready = true;
    notifyListeners();
  }

  Future<void> saveLogin(Map<String, dynamic> data) async {
    login = Map<String, dynamic>.from(data);
    token = fieldOf(login, const ['token']);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_loginKey, jsonEncode(login));
    notifyListeners();
  }

  Future<void> saveIm(Map<String, dynamic> data) async {
    imToken = data['token']?.toString() ?? '';
    login['IM_token'] = imToken;
    login['userInfoId'] = data['userInfoId'];
    login['userName'] = data['userName'];
    login['identityList'] = data['identityList'];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_imTokenKey, imToken);
    await prefs.setString(_loginKey, jsonEncode(login));
    notifyListeners();
  }

  Future<void> saveHospital(
    Map<String, dynamic> data, {
    bool notify = true,
  }) async {
    hospital = Map<String, dynamic>.from(data);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_hospitalKey, jsonEncode(hospital));
    if (notify) notifyListeners();
  }

  Future<void> patchUser(Map<String, dynamic> nextUser) async {
    login['user'] = nextUser;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_loginKey, jsonEncode(login));
    notifyListeners();
  }

  Future<void> rememberPasswordLogin(String account, String password) async {
    savedAccount = account;
    savedPassword = password;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accountKey, account);
    await prefs.setString(_passwordKey, password);
  }

  Future<void> setAgreedProtocol() async {
    agreedProtocol = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_protocolKey, true);
    notifyListeners();
  }

  Future<void> setEnv(int index) async {
    envIndex = index.clamp(0, AppConfig.envs.length - 1);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_envKey, envIndex);
    notifyListeners();
  }

  Future<void> logout() async {
    token = '';
    imToken = '';
    login = {};
    hospital = {};
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_imTokenKey);
    await prefs.remove(_loginKey);
    await prefs.remove(_hospitalKey);
    notifyListeners();
  }

  Map<String, dynamic> _decodeMap(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return {};
  }
}

String fieldOf(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value == null) continue;
    final text = value.toString();
    if (text.isNotEmpty && text != 'null') return text;
  }
  return '';
}
