import 'package:flutter/material.dart';
import 'package:flutter_muniuma_doctor/core/config/app_config.dart';
import 'package:flutter_muniuma_doctor/core/network/api_client.dart';
import 'package:flutter_muniuma_doctor/features/auth/login_page.dart';
import 'package:flutter_muniuma_doctor/features/message/im_socket.dart';
import 'package:flutter_muniuma_doctor/features/message/message_repository.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.repo,
    required this.socket,
    required this.group,
  });

  final MessageRepository repo;
  final ImSocket socket;
  final Map<String, dynamic> group;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _input = TextEditingController();
  final _messages = <Map<String, dynamic>>[];
  bool _loading = true;
  bool _more = true;
  bool _loadingOlder = false;
  String? _error;
  late final String _groupId = groupKey(widget.group);
  late final bool _canSend = widget.group['allowSend'] == null
      ? true
      : asBool(widget.group['allowSend']);

  @override
  void initState() {
    super.initState();
    widget.socket.foregroundGroupId = _groupId;
    widget.socket.addListener(_onIncoming);
    _markRead();
    _load();
  }

  @override
  void dispose() {
    if (widget.socket.foregroundGroupId == _groupId) {
      widget.socket.foregroundGroupId = null;
    }
    widget.socket.removeListener(_onIncoming);
    _input.dispose();
    super.dispose();
  }

  Future<void> _markRead() async {
    try {
      await widget.socket.ensureConnected(widget.repo.session);
      widget.socket.invoke(
        'ReadReport',
        readPayload(widget.repo.session, _groupId),
        '0',
      );
    } catch (_) {}
  }

  Future<void> _load({bool older = false}) async {
    if (older) {
      if (!_more || _loadingOlder || _messages.isEmpty) return;
      setState(() => _loadingOlder = true);
    }
    try {
      final oldest = older ? messageKey(_messages.last) : null;
      final list = await widget.repo.history(
        groupId: _groupId,
        messageId: oldest,
      );
      if (!mounted) return;
      list.sort((a, b) => _stamp(b).compareTo(_stamp(a)));
      setState(() {
        for (final item in list) {
          final id = messageKey(item);
          if (_messages.any((row) => messageKey(row) == id && id.isNotEmpty)) {
            continue;
          }
          _messages.add(item);
        }
        _more = list.length >= 20;
        _loading = false;
        _loadingOlder = false;
        _error = null;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingOlder = false;
        _error = error.message;
      });
    }
  }

  void _onIncoming(Map<String, dynamic> message) {
    if (groupKey(message) != _groupId) return;
    final id = messageKey(message);
    if (id.isNotEmpty && _messages.any((row) => messageKey(row) == id)) return;
    setState(() => _messages.insert(0, message));
    _markRead();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || !_canSend) return;
    _input.clear();
    final id = newMessageId();
    final payload = textPayload(
      session: widget.repo.session,
      groupId: _groupId,
      groupType: asInt(widget.group['groupType']),
      content: text,
      messageId: id,
    );
    setState(() => _messages.insert(0, payload));
    try {
      await widget.socket.ensureConnected(widget.repo.session);
      widget.socket.invoke('SendMessage', payload, id);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('发送失败，请稍后重试')),
      );
    }
  }

  int _stamp(Map<String, dynamic> item) => asInt(item['timeStamp']);

  @override
  Widget build(BuildContext context) {
    final title = field(widget.group, const ['groupName', 'patientName', 'name']);
    return Scaffold(
      appBar: AppBar(title: Text(title.isEmpty ? '会话' : title)),
      body: Column(
        children: [
          Expanded(child: _body()),
          if (_canSend) _composer() else const _DisabledSendBar(),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null && _messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            TextButton(onPressed: _load, child: const Text('重试')),
          ],
        ),
      );
    }
    if (_messages.isEmpty) return const Center(child: Text('暂无消息'));
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _messages.length + (_more ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _messages.length) {
          return Center(
            child: TextButton(
              onPressed: _loadingOlder ? null : () => _load(older: true),
              child: Text(_loadingOlder ? '加载中...' : '查看更早的消息'),
            ),
          );
        }
        return _bubble(_messages[index]);
      },
    );
  }

  Widget _bubble(Map<String, dynamic> item) {
    if (asBool(item['isSystemMessage'])) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Text(
            field(item, const ['content']),
            style: const TextStyle(color: Color(0xFF9F9F9F), fontSize: 12),
          ),
        ),
      );
    }
    final mine = field(item, const ['sendUserId']) == widget.repo.userInfoId &&
        widget.repo.userInfoId.isNotEmpty;
    final type = asInt(item['contentType']);
    final content = field(item, const ['content']);
    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: mine ? themeBlue : const Color(0xFFF2F4F7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: _content(type, content, mine),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment:
            mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!mine)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                field(item, const ['sendUserName']),
                style: const TextStyle(fontSize: 11, color: Color(0xFF9F9F9F)),
              ),
            ),
          bubble,
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              field(item, const ['sendDateTime']),
              style: const TextStyle(fontSize: 10, color: Color(0xFFB0B0B0)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _content(int type, String content, bool mine) {
    final color = mine ? Colors.white : const Color(0xFF2C2C2E);
    if (type == 30) {
      final raw = imageCosOf(content);
      final url = AppConfig.imageUrl(raw, widget.repo.session.env.cosDomain);
      if (url == null) {
        return Text('[图片]', style: TextStyle(color: color));
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.network(
          url,
          width: 160,
          height: 160,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => SizedBox(
            width: 160,
            height: 80,
            child: ColoredBox(
              color: const Color(0xFFE8EEF3),
              child: Center(child: Text('图片加载失败', style: TextStyle(color: color))),
            ),
          ),
        ),
      );
    }
    return Text(
      type == 10 || type == 0 ? content : previewOf({'contentType': type, 'content': content}),
      style: TextStyle(color: color, fontSize: 15),
    );
  }

  Widget _composer() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFF0F0F0))),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _input,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: const InputDecoration(
                  hintText: '输入消息',
                  isDense: true,
                  filled: true,
                  fillColor: Color(0xFFF7F8F9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            TextButton(onPressed: _send, child: const Text('发送')),
          ],
        ),
      ),
    );
  }
}

class _DisabledSendBar extends StatelessWidget {
  const _DisabledSendBar();

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Text(
          '当前会话不能发送消息',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF9F9F9F)),
        ),
      ),
    );
  }
}
