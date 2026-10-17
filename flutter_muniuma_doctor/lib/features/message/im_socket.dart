import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_muniuma_doctor/core/session/app_session.dart';

/// 医技长连接，协议与 iOS `MNWebSocketManager` 一致：SignalR JSON hub。
class ImSocket {
  WebSocket? _socket;
  Future<void>? _connecting;
  Timer? _ping;
  AppSession? _session;
  final _buffer = StringBuffer();
  final _pending = <String>[];
  final _listeners = <void Function(Map<String, dynamic>)>[];
  bool _handshakeDone = false;
  bool _disposed = false;

  /// 当前正在查看的会话。收到该群消息时不增加未读。
  String? foregroundGroupId;

  void addListener(void Function(Map<String, dynamic> message) listener) {
    _listeners.add(listener);
  }

  void removeListener(void Function(Map<String, dynamic> message) listener) {
    _listeners.remove(listener);
  }

  Future<void> ensureConnected(AppSession session) async {
    _session = session;
    if (_handshakeDone && _socket != null) return;
    if (session.imToken.isEmpty) {
      throw StateError('医技未登录');
    }
    _connecting ??= _open(session);
    try {
      await _connecting;
    } catch (error) {
      _connecting = null;
      rethrow;
    }
  }

  Future<void> _open(AppSession session) async {
    final host = Uri.parse(session.env.apiBase).host;
    final uri = Uri(
      scheme: 'wss',
      host: host,
      path: '/im/chatHub',
      queryParameters: {'access_token': session.imToken},
    );
    final socket = await WebSocket.connect(uri.toString());
    if (_disposed) {
      await socket.close();
      return;
    }
    _socket = socket;
    _handshakeDone = false;
    socket.add('{"protocol":"json","version":1}\u001e');
    _ping?.cancel();
    _ping = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_handshakeDone) _socket?.add('{"type":6}\u001e');
    });
    socket.listen(_onData, onDone: _onDone, onError: (_, _) => _onDone());
  }

  void invoke(String target, Map<String, dynamic> argument, String invocationId) {
    final frame =
        '${jsonEncode({
          'arguments': [argument],
          'invocationId': invocationId,
          'target': target,
          'type': 1,
        })}\u001e';
    if (_handshakeDone && _socket != null) {
      _socket!.add(frame);
    } else {
      _pending.add(frame);
    }
  }

  void _onData(dynamic data) {
    final text = data is String ? data : utf8.decode(data as List<int>);
    _buffer.write(text);
    final parts = _buffer.toString().split('\u001e');
    _buffer
      ..clear()
      ..write(parts.removeLast());
    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.isNotEmpty) _onFrame(trimmed);
    }
  }

  void _onFrame(String text) {
    if (!_handshakeDone) {
      _handshakeDone = true;
      final pending = List<String>.from(_pending);
      _pending.clear();
      for (final frame in pending) {
        _socket?.add(frame);
      }
    }
    final decoded = _tryDecode(text);
    if (decoded == null) return;
    if (decoded['type'] == 7) {
      _socket?.close();
      return;
    }
    if (decoded['type'] != 1 || decoded['target'] != 'OnMessage') return;
    final args = decoded['arguments'];
    if (args is! List || args.isEmpty || args.first is! Map) return;
    final message = Map<String, dynamic>.from(args.first as Map);
    for (final listener in List.of(_listeners)) {
      listener(message);
    }
  }

  Map<String, dynamic>? _tryDecode(String text) {
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  void _onDone() {
    _socket = null;
    _handshakeDone = false;
    _connecting = null;
    _ping?.cancel();
    final session = _session;
    if (_disposed || session == null) return;
    Future.delayed(const Duration(seconds: 2), () {
      if (!_disposed) unawaited(_reconnect(session));
    });
  }

  Future<void> _reconnect(AppSession session) async {
    try {
      await ensureConnected(session);
    } catch (_) {}
  }

  void dispose() {
    _disposed = true;
    _ping?.cancel();
    _socket?.close();
    _socket = null;
    _listeners.clear();
  }
}

String formatImTime(DateTime time) {
  String two(int value) => value.toString().padLeft(2, '0');
  String three(int value) => value.toString().padLeft(3, '0');
  return '${time.year}-${two(time.month)}-${two(time.day)} '
      '${two(time.hour)}:${two(time.minute)}:${two(time.second)}.${three(time.millisecond)}';
}

String newMessageId() {
  final random = Random.secure();
  return List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

Map<String, dynamic> textPayload({
  required AppSession session,
  required String groupId,
  required int groupType,
  required String content,
  required String messageId,
}) {
  final identity = session.imIdentity ?? 0;
  final now = DateTime.now();
  return {
    'sendUserId': session.login['userInfoId']?.toString() ?? '',
    'sendUserName': session.userName,
    'sendUserImIdentity': identity,
    'imIdentity': identity,
    'messageType': groupType == 2 ? 101 : 100,
    'content': content,
    'contentType': 10,
    'timeStamp': now.millisecondsSinceEpoch,
    'isSystemMessage': false,
    'isAite': false,
    'isHandle': false,
    'doctorIsRead': false,
    'id': messageId,
    'groupId': groupId,
    'sendDateTime': formatImTime(now),
  };
}

Map<String, dynamic> readPayload(AppSession session, String groupId) {
  return {
    'imIdentity': session.imIdentity ?? 0,
    'groupId': groupId,
    'sendDateTime': formatImTime(DateTime.now()),
  };
}
