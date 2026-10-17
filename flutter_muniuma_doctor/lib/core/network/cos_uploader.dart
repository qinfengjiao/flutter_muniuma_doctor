import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_muniuma_doctor/core/network/api_client.dart';

class CosUploader {
  CosUploader(this.api);

  final ApiClient api;
  final Dio _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 30), receiveTimeout: const Duration(seconds: 30)));

  Future<String> uploadPaths(List<String> paths) async {
    if (paths.isEmpty) return '';
    final credential = asMap(await api.get('file/Txy/GetCredential'));
    final models = <Map<String, dynamic>>[];
    for (final path in paths) {
      models.add(await _put(credential, File(path)));
    }
    return jsonEncode(models);
  }

  Future<Map<String, dynamic>> _put(Map<String, dynamic> credential, File file) async {
    final bucket = field(credential, const ['cosName', 'bucket']);
    final region = field(credential, const ['region']);
    final secretId = field(credential, const ['tmpSecretId', 'secretId']);
    final secretKey = field(credential, const ['tmpSecretKey', 'secretKey']);
    final token = field(credential, const ['token', 'sessionToken']);
    var folder = field(credential, const ['path']);
    if (bucket.isEmpty || region.isEmpty || secretId.isEmpty || secretKey.isEmpty) {
      throw ApiException('获取上传凭证失败');
    }
    if (folder.isNotEmpty && !folder.endsWith('/')) folder = '$folder/';
    final bytes = await file.readAsBytes();
    final suffix = file.path.contains('.') ? file.path.split('.').last.toLowerCase() : 'jpg';
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final key = '$folder$stamp${_uuid()}.$suffix';
    final host = '$bucket.cos.$region.myqcloud.com';
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final keyTime = '$now;${now + 1800}';
    final headerList = token.isEmpty ? 'host' : 'host;x-cos-security-token';
    final headers = token.isEmpty
        ? 'host=${_encode(host)}'
        : 'host=${_encode(host)}&x-cos-security-token=${_encode(token)}';
    final httpString = 'put\n/${_encodePath(key)}\n\n$headers\n';
    final stringToSign = 'sha1\n$keyTime\n${sha1.convert(utf8.encode(httpString))}\n';
    final signKey = Hmac(sha1, utf8.encode(secretKey)).convert(utf8.encode(keyTime)).toString();
    final signature = Hmac(sha1, utf8.encode(signKey)).convert(utf8.encode(stringToSign)).toString();
    final authorization =
        'q-sign-algorithm=sha1&q-ak=$secretId&q-sign-time=$keyTime&q-key-time=$keyTime&q-header-list=$headerList&q-url-param-list=&q-signature=$signature';
    try {
      await _dio.put<dynamic>(
        'https://$host/${_encodePath(key)}',
        data: bytes,
        options: Options(
          headers: {
            'Host': host,
            'Authorization': authorization,
            if (token.isNotEmpty) 'x-cos-security-token': token,
            'Content-Type': _mime(suffix),
            'Content-Length': bytes.length,
          },
          validateStatus: (status) => status != null && status < 300,
        ),
      );
    } on DioException {
      throw ApiException('文件上传失败');
    }
    final domain = field(credential, const ['customizeDomainName']);
    final base = domain.isEmpty
        ? 'https://$host'
        : (domain.startsWith('http') ? domain : 'https://$domain').replaceAll(RegExp(r'/+$'), '');
    final url = '$base/$key';
    return {
      'name': file.uri.pathSegments.last,
      'url': url,
      'suffix': suffix,
      'size': (bytes.length / 1024).round(),
    };
  }

  String _mime(String suffix) {
    return switch (suffix) {
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'm4a' || 'aac' => 'audio/mp4',
      'mp3' => 'audio/mpeg',
      'wav' => 'audio/wav',
      _ => 'application/octet-stream',
    };
  }

  String _encode(String value) => Uri.encodeComponent(value);

  String _encodePath(String key) => key.split('/').map(Uri.encodeComponent).join('/');

  String _uuid() {
    final random = Random();
    return List.generate(8, (_) => random.nextInt(16).toRadixString(16)).join();
  }
}
