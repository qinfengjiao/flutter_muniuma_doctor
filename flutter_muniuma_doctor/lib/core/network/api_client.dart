import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_muniuma_doctor/core/config/app_config.dart';
import 'package:flutter_muniuma_doctor/core/session/app_session.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.code, this.unauthorized = false});

  final String message;
  final int? code;
  final bool unauthorized;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient(this.session);

  final AppSession session;
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      responseType: ResponseType.plain,
    ),
  );

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? headers,
    bool useImToken = false,
  }) {
    return _send(
      'GET',
      path,
      query: query,
      headers: headers,
      useImToken: useImToken,
    );
  }

  Future<dynamic> post(
    String path, {
    Object? body,
    Map<String, dynamic>? headers,
    bool useImToken = false,
  }) {
    return _send(
      'POST',
      path,
      body: body,
      headers: headers,
      useImToken: useImToken,
    );
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? body,
    Map<String, dynamic>? headers,
    bool useImToken = false,
  }) async {
    final url = AppConfig.join(session.env.apiBase, path);
    final token = useImToken || path.contains('/IM/')
        ? session.imToken
        : session.token;
    final requestHeaders = <String, dynamic>{
      'accept': 'text/plain',
      if (method == 'POST') 'Content-Type': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      ...?headers,
    };
    try {
      final response = await _dio.request<dynamic>(
        url,
        data: body,
        queryParameters: query,
        options: Options(method: method, headers: requestHeaders),
      );
      return _unwrap(response.data);
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status == 401) {
        await session.logout();
        throw ApiException('登录过期请重新登录', unauthorized: true, code: 401);
      }
      final data = error.response?.data;
      if (data != null) {
        try {
          return _unwrap(data);
        } on ApiException {
          rethrow;
        } catch (_) {}
      }
      throw ApiException('操作失败, 请稍候重试~');
    }
  }

  dynamic _unwrap(dynamic raw) {
    dynamic json = raw;
    if (raw is String) {
      if (raw.trim().isEmpty) {
        throw ApiException('操作失败, 请稍候重试~');
      }
      json = jsonDecode(raw);
    }
    if (json is! Map) {
      throw ApiException('操作失败, 请稍候重试~');
    }
    final code = int.tryParse('${json['code']}') ?? 0;
    if (code == 401) {
      session.logout();
      throw ApiException('登录过期请重新登录', unauthorized: true, code: 401);
    }
    final success = json['success'];
    final ok = success == true ||
        success == 1 ||
        success == '1' ||
        success == 'true';
    if (!ok) {
      final message = json['message']?.toString();
      throw ApiException(
        message == null || message.isEmpty ? '操作失败, 请稍候重试~' : message,
        code: code,
      );
    }
    return json['data'];
  }
}

List<Map<String, dynamic>> asMapList(dynamic data) {
  dynamic source = data;
  if (data is String && data.isNotEmpty) {
    try {
      source = jsonDecode(data);
    } catch (_) {}
  }
  if (source is Map && source['list'] is List) {
    source = source['list'];
  }
  if (source is! List) return const [];
  return source
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

Map<String, dynamic> asMap(dynamic data) {
  if (data is Map) return Map<String, dynamic>.from(data);
  if (data is String && data.isNotEmpty) {
    try {
      final decoded = jsonDecode(data);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
  }
  return const {};
}

String field(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value == null) continue;
    final text = value.toString();
    if (text.isNotEmpty && text != 'null') return text;
  }
  return '';
}

int asCount(dynamic data) {
  if (data is num) return data.toInt();
  if (data is String) return int.tryParse(data) ?? 0;
  if (data is Map) {
    for (final key in ['count', 'total', 'totalCount', 'unassociatedCount']) {
      final value = data[key];
      if (value is num) return value.toInt();
      final parsed = int.tryParse('$value');
      if (parsed != null) return parsed;
    }
  }
  return 0;
}
