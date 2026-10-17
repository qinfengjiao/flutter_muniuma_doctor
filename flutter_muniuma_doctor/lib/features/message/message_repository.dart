import 'dart:convert';

import 'package:flutter_muniuma_doctor/core/network/api_client.dart';
import 'package:flutter_muniuma_doctor/core/session/app_session.dart';

class MessageRepository {
  MessageRepository(this.api, this.session);

  final ApiClient api;
  final AppSession session;

  String get userInfoId => session.login['userInfoId']?.toString() ?? '';

  Future<GroupPage> groups({
    required int index,
    String? keyword,
    bool unreadOnly = false,
  }) async {
    final identity = session.imIdentity;
    if (identity == null || session.imToken.isEmpty) {
      return const GroupPage(items: [], unread: 0);
    }
    final data = await api.get(
      'IM/IM/GetUserGroupList',
      query: {
        'ImIdentity': identity,
        'MsgIndex': index,
        'MsgSize': 20,
        if (unreadOnly) 'IsUnreadGroup': 'true',
        if (keyword != null && keyword.isNotEmpty) 'KeyWord': keyword,
      },
      useImToken: true,
    );
    final map = asMap(data);
    final items = map['groupListModels'] is List
        ? asMapList(map['groupListModels'])
        : asMapList(data);
    return GroupPage(
      items: items,
      unread: int.tryParse('${map['totalUnreadTotal']}') ?? 0,
    );
  }

  Future<List<Map<String, dynamic>>> history({
    required String groupId,
    String? messageId,
  }) async {
    final data = await api.get(
      'IM/IM/GetGroupMessageList',
      query: {
        'GroupId': groupId,
        'MaxResultCount': 20,
        if (messageId != null && messageId.isNotEmpty) 'MessageId': messageId,
      },
      useImToken: true,
    );
    return asMapList(data);
  }

  Future<UnreadFlags> untreated() async {
    final data = await api.get('/order/Order/GetUntreated');
    final map = asMap(data);
    return UnreadFlags(
      trial: asBool(map['hasTrial']),
      receive: asBool(map['hasOrderReciveSend']),
      notice: asBool(map['system']),
    );
  }

  Future<List<Map<String, dynamic>>> notices(int page) {
    return _list(
      'basic/Notice/GetNoticeList',
      {'NoticePort': 8, 'PageIndex': page, 'PageSize': 20},
    );
  }

  Future<void> markNoticeRead(String id) {
    return api.post('basic/Notice/SetUserRead', body: {'id': id});
  }

  Future<List<Map<String, dynamic>>> trials(int page) {
    return _list('order/OrderTrial/GetGetOrderTrialList', {
      'HospitalDoctorId': session.hospitalDoctorId,
      'PageIndex': page,
      'PageSize': 20,
      'IsFeedback': 'false',
    });
  }

  Future<List<Map<String, dynamic>>> trialOptions(String orderId) {
    return _list('order/OrderTrial/GetOrderTrialOptionList', {
      'OrderId': orderId,
      'PageIndex': 1,
      'PageSize': 50,
    });
  }

  Future<List<Map<String, dynamic>>> trialResults(String orderId) {
    return _list('order/OrderTrial/GetOrderTrialResultList', {'Id': orderId});
  }

  Future<void> submitTrial({
    required String orderId,
    required List<Map<String, dynamic>> trails,
  }) {
    return api.post(
      'order/OrderTrial/SubmitOrderTrail',
      body: {'orderId': orderId, 'orderTrails': trails},
    );
  }

  Future<List<Map<String, dynamic>>> receiveTasks({
    required int page,
    String? keyword,
  }) {
    return _list('/order/OrderLogistics/GetYsOrderReciveSendHandleList', {
      'PageIndex': page,
      'PageSize': 20,
      if (keyword != null && keyword.isNotEmpty) 'Keyword': keyword,
    });
  }

  Future<void> startReceive(String id) {
    return api.post(
      '/order/Order/YsGenerateOrderReceiveSend',
      body: {'id': id},
    );
  }

  Future<List<Map<String, dynamic>>> _list(
    String path,
    Map<String, dynamic> query,
  ) async {
    final data = await api.get(path, query: query);
    return asMapList(data);
  }
}

class GroupPage {
  const GroupPage({required this.items, required this.unread});

  final List<Map<String, dynamic>> items;
  final int unread;
}

class UnreadFlags {
  const UnreadFlags({
    required this.trial,
    required this.receive,
    required this.notice,
  });

  final bool trial;
  final bool receive;
  final bool notice;

  static const empty = UnreadFlags(trial: false, receive: false, notice: false);
}

bool asBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = '$value'.toLowerCase();
  return text == 'true' || text == '1';
}

int asInt(dynamic value) => int.tryParse('$value') ?? 0;

String messageKey(Map<String, dynamic> item) => field(item, const ['id', 'Id']);

String groupKey(Map<String, dynamic> item) =>
    field(item, const ['groupId', 'GroupId']);

String previewOf(Map<String, dynamic> item) {
  final type = asInt(item['contentType']);
  const labels = {
    30: '[图片]',
    40: '[视频]',
    50: '[文件]',
    60: '[语音]',
    70: '[问题处理]',
    80: '[位置]',
    90: '[助手消息]',
    100: '[工单助手]',
  };
  final label = labels[type];
  if (label != null) return label;
  if (type != 10 && type != 0) return '[消息]';
  return field(item, const ['content']);
}

String plainText(String raw) {
  return raw
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String? imageCosOf(String content) {
  final trimmed = content.trim();
  if (trimmed.isEmpty) return null;
  if (trimmed.startsWith('{')) {
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map) {
        final url = decoded['fileCos']?.toString();
        if (url != null && url.isNotEmpty) return url;
      }
    } catch (_) {}
  }
  if (trimmed.startsWith('http')) return trimmed;
  return null;
}
