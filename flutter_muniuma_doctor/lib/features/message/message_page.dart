import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_muniuma_doctor/core/config/app_config.dart';
import 'package:flutter_muniuma_doctor/core/network/api_client.dart';
import 'package:flutter_muniuma_doctor/core/session/app_session.dart';
import 'package:flutter_muniuma_doctor/features/auth/login_page.dart';
import 'package:flutter_muniuma_doctor/features/message/chat_page.dart';
import 'package:flutter_muniuma_doctor/features/message/im_socket.dart';
import 'package:flutter_muniuma_doctor/features/message/message_repository.dart';
import 'package:flutter_muniuma_doctor/features/message/notice_detail_page.dart';
import 'package:flutter_muniuma_doctor/features/message/trial_feedback_page.dart';

class MessagePage extends StatefulWidget {
  const MessagePage({super.key, required this.session, required this.api});

  final AppSession session;
  final ApiClient api;

  @override
  State<MessagePage> createState() => _MessagePageState();
}

class _MessagePageState extends State<MessagePage> {
  late final MessageRepository _repo = MessageRepository(widget.api, widget.session);
  late final ImSocket _socket = ImSocket();
  int _index = 0;
  UnreadFlags _flags = UnreadFlags.empty;

  @override
  void initState() {
    super.initState();
    unawaited(_connect());
    unawaited(_loadFlags());
  }

  @override
  void dispose() {
    _socket.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    try {
      await _socket.ensureConnected(widget.session);
    } catch (_) {}
  }

  Future<void> _loadFlags() async {
    try {
      final flags = await _repo.untreated();
      if (mounted) setState(() => _flags = flags);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF7F8F9),
      child: Column(
        children: [
          ColoredBox(
            color: Colors.white,
            child: Row(
              children: [
                _tab('消息', 0, false),
                _tab('试戴反馈', 1, _flags.trial),
                _tab('接件处理', 2, _flags.receive),
                _tab('通知', 3, _flags.notice),
              ],
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _index,
              children: [
                _SessionTab(repo: _repo, socket: _socket),
                _TrialTab(repo: _repo),
                _ReceiveTab(repo: _repo),
                _NoticeTab(repo: _repo, onRead: _loadFlags),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tab(String label, int index, bool dot) {
    final selected = _index == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() => _index = index);
          _loadFlags();
        },
        child: SizedBox(
          height: 48,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected ? themeBlue : const Color(0xFF2C2C2E),
                    ),
                  ),
                  if (dot)
                    const Positioned(
                      right: -8,
                      top: 0,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Color(0xFFFA4D32),
                          shape: BoxShape.circle,
                        ),
                        child: SizedBox(width: 6, height: 6),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                width: 18,
                height: 2,
                color: selected ? themeBlue : Colors.transparent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionTab extends StatefulWidget {
  const _SessionTab({required this.repo, required this.socket});

  final MessageRepository repo;
  final ImSocket socket;

  @override
  State<_SessionTab> createState() => _SessionTabState();
}

class _SessionTabState extends State<_SessionTab> {
  final _search = TextEditingController();
  final _items = <Map<String, dynamic>>[];
  int _index = 0;
  int _ticket = 0;
  bool _loading = true;
  bool _more = true;
  bool _busy = false;
  bool _unreadOnly = false;
  String? _error;
  String _keyword = '';

  @override
  void initState() {
    super.initState();
    widget.socket.addListener(_onIncoming);
    _load(reset: true);
  }

  @override
  void dispose() {
    widget.socket.removeListener(_onIncoming);
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({required bool reset}) async {
    if (!reset && (_busy || !_more)) return;
    final ticket = ++_ticket;
    final index = reset ? 0 : _index;
    _busy = true;
    if (reset && mounted) {
      setState(() {
        _loading = _items.isEmpty;
        _error = null;
      });
    }
    try {
      final page = await widget.repo.groups(
        index: index,
        keyword: _keyword,
        unreadOnly: _unreadOnly,
      );
      if (!mounted || ticket != _ticket) return;
      setState(() {
        if (reset) {
          _items
            ..clear()
            ..addAll(page.items);
        } else {
          _items.addAll(page.items);
        }
        _index = index + page.items.length;
        _more = page.items.length >= 20;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted || ticket != _ticket) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    } finally {
      if (ticket == _ticket) _busy = false;
    }
  }

  void _onIncoming(Map<String, dynamic> message) {
    final id = groupKey(message);
    if (id.isEmpty) return;
    final current = _items.indexWhere((item) => groupKey(item) == id);
    setState(() {
      final row = current >= 0 ? _items.removeAt(current) : <String, dynamic>{'groupId': id};
      row['content'] = field(message, const ['content']);
      row['contentType'] = message['contentType'];
      row['sendDateTime'] = field(message, const ['sendDateTime']);
      final mine = field(message, const ['sendUserId']) == widget.repo.userInfoId &&
          widget.repo.userInfoId.isNotEmpty;
      final viewing = widget.socket.foregroundGroupId == id;
      row['unreadTotal'] = mine || viewing ? 0 : asInt(row['unreadTotal']) + 1;
      if (field(row, const ['groupName']).isEmpty) {
        row['groupName'] = field(message, const ['groupName', 'sendUserName']);
      }
      _items.insert(0, row);
    });
  }

  Future<void> _readAll() async {
    try {
      await widget.socket.ensureConnected(widget.repo.session);
      widget.socket.invoke(
        'ReadReport',
        readPayload(widget.repo.session, ''),
        '0',
      );
      if (!mounted) return;
      setState(() {
        for (final item in _items) {
          item['unreadTotal'] = 0;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已全部已读')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('操作失败，请稍后重试')),
      );
    }
  }

  void _open(Map<String, dynamic> item) {
    setState(() => item['unreadTotal'] = 0);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPage(
          repo: widget.repo,
          socket: widget.socket,
          group: item,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ColoredBox(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              children: [
                Expanded(child: _searchBox()),
                TextButton(
                  onPressed: () {
                    setState(() => _unreadOnly = !_unreadOnly);
                    _load(reset: true);
                  },
                  child: Text(_unreadOnly ? '全部' : '未读'),
                ),
              ],
            ),
          ),
        ),
        if (_unreadOnly)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: _readAll, child: const Text('全部已读')),
          ),
        Expanded(child: _list()),
      ],
    );
  }

  Widget _searchBox() {
    return TextField(
      controller: _search,
      textInputAction: TextInputAction.search,
      onSubmitted: (value) {
        _keyword = value.trim();
        _load(reset: true);
      },
      decoration: InputDecoration(
        hintText: '搜索单号、患者名',
        isDense: true,
        filled: true,
        fillColor: const Color(0xFFF7F8F9),
        prefixIcon: const Icon(Icons.search, size: 18),
        suffixIcon: IconButton(
          icon: const Icon(Icons.arrow_forward, size: 18),
          onPressed: () {
            _keyword = _search.text.trim();
            _load(reset: true);
          },
        ),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _list() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null && _items.isEmpty) {
      return _ErrorText(message: _error!, onRetry: () => _load(reset: true));
    }
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: ListView(
          children: const [
            SizedBox(height: 120),
            Center(child: Text('暂无会话')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: NotificationListener<ScrollNotification>(
        onNotification: (notice) {
          if (notice.metrics.pixels > notice.metrics.maxScrollExtent - 120) {
            _load(reset: false);
          }
          return false;
        },
        child: ListView.separated(
          itemCount: _items.length,
          separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
          itemBuilder: (_, index) => _sessionTile(_items[index]),
        ),
      ),
    );
  }

  Widget _sessionTile(Map<String, dynamic> item) {
    final name = field(item, const ['groupName', 'patientName', 'name']);
    final unread = asInt(item['unreadTotal']);
    final url = AppConfig.imageUrl(
      field(item, const ['headPortraitCos']),
      widget.repo.session.env.cosDomain,
    );
    return ListTile(
      tileColor: Colors.white,
      leading: _Avatar(url: url, name: name),
      title: Text(name.isEmpty ? '会话' : name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${asBool(item['isAite']) ? '[@你] ' : ''}${previewOf(item)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _shortTime(field(item, const ['sendDateTime', 'messageTime'])),
            style: const TextStyle(fontSize: 11, color: Color(0xFF9F9F9F)),
          ),
          if (unread > 0)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFFFA4D32),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                unread > 99 ? '99+' : '$unread',
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
        ],
      ),
      onTap: () => _open(item),
    );
  }
}

class _TrialTab extends StatelessWidget {
  const _TrialTab({required this.repo});

  final MessageRepository repo;

  @override
  Widget build(BuildContext context) {
    return _PagedList(
      load: repo.trials,
      emptyText: '暂无试戴反馈',
      itemBuilder: (context, item, reload) {
        final patient = field(item, const ['patientName']);
        final orderNo = field(item, const ['orderNo']);
        final done = asBool(item['isFeedback']);
        return ListTile(
          tileColor: Colors.white,
          title: Text(patient.isEmpty ? orderNo : '$orderNo-$patient'),
          subtitle: Text(field(item, const ['completionTime'])),
          trailing: Text(done ? '已反馈' : '待反馈'),
          onTap: () async {
            final changed = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => TrialFeedbackPage(
                  repo: repo,
                  orderId: field(item, const ['orderId', 'id', 'Id']),
                  title: patient.isEmpty ? orderNo : '$patient $orderNo',
                  done: done,
                ),
              ),
            );
            if (changed == true) reload();
          },
        );
      },
    );
  }
}

class _ReceiveTab extends StatefulWidget {
  const _ReceiveTab({required this.repo});

  final MessageRepository repo;

  @override
  State<_ReceiveTab> createState() => _ReceiveTabState();
}

class _ReceiveTabState extends State<_ReceiveTab> {
  final _search = TextEditingController();
  String _keyword = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ColoredBox(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: (value) => setState(() => _keyword = value.trim()),
              decoration: InputDecoration(
                hintText: '搜索订单号、患者名',
                isDense: true,
                filled: true,
                fillColor: const Color(0xFFF7F8F9),
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  onPressed: () => setState(() => _keyword = _search.text.trim()),
                ),
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: _PagedList(
            reloadToken: _keyword,
            emptyText: '暂无接件任务',
            load: (page) => widget.repo.receiveTasks(page: page, keyword: _keyword),
            itemBuilder: (context, item, reload) => _receiveTile(context, item, reload),
          ),
        ),
      ],
    );
  }

  Widget _receiveTile(
    BuildContext context,
    Map<String, dynamic> item,
    VoidCallback reload,
  ) {
    final patient = field(item, const ['patientName']);
    final orderNo = field(item, const ['orderNo']);
    final canStart = asBool(item['canInitiate']);
    final name = patient.isEmpty ? orderNo : patient;
    return ListTile(
      tileColor: Colors.white,
      leading: _Avatar(name: name),
      title: Text(patient.isEmpty ? orderNo : '$orderNo-$patient'),
      subtitle: Text(
        canStart ? field(item, const ['message']) : _receiveTime(item),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: canStart ? const Color(0xFFFA4D32) : const Color(0xFF9F9F9F)),
      ),
      trailing: Text(
        canStart ? '发起接件' : '查看详情',
        style: TextStyle(
          color: canStart ? const Color(0xFFFA4D32) : const Color(0xFF2C2C2E),
          fontSize: 13,
        ),
      ),
      onTap: () => canStart ? _start(context, item, reload) : _detail(context, item),
    );
  }

  Future<void> _start(
    BuildContext context,
    Map<String, dynamic> item,
    VoidCallback reload,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('发起接件任务'),
        content: Text(field(item, const ['message', 'orderNo'])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('发起')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await widget.repo.startReceive(field(item, const ['id', 'Id']));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('发起成功')));
      reload();
    } on ApiException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  void _detail(BuildContext context, Map<String, dynamic> item) {
    final rows = <String>[
      if (field(item, const ['stateStr']).isNotEmpty) field(item, const ['stateStr']),
      if (field(item, const ['message']).isNotEmpty) field(item, const ['message']),
      if (field(item, const ['creationTime']).isNotEmpty) '创建 ${field(item, const ['creationTime'])}',
      if (field(item, const ['receiveTime']).isNotEmpty) '接件 ${field(item, const ['receiveTime'])}',
      if (field(item, const ['takeTime']).isNotEmpty) '取件 ${field(item, const ['takeTime'])}',
      if (field(item, const ['arriveTime']).isNotEmpty) '送达 ${field(item, const ['arriveTime'])}',
      if (field(item, const ['orderInFactoryTime']).isNotEmpty)
        '到厂 ${field(item, const ['orderInFactoryTime'])}',
    ];
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${field(item, const ['orderNo'])}-${field(item, const ['patientName'])}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              for (final row in rows) Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(row),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoticeTab extends StatelessWidget {
  const _NoticeTab({required this.repo, required this.onRead});

  final MessageRepository repo;
  final VoidCallback onRead;

  @override
  Widget build(BuildContext context) {
    return _PagedList(
      load: repo.notices,
      emptyText: '暂无通知',
      itemBuilder: (context, item, reload) {
        final read = asBool(item['isRead']);
        final title = field(item, const ['title']);
        final content = field(item, const ['content']);
        return ListTile(
          tileColor: Colors.white,
          leading: Icon(
            Icons.campaign_outlined,
            color: read ? const Color(0xFFB0B0B0) : themeBlue,
          ),
          title: Text(title.isEmpty ? '通知' : title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            plainText(content),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Text(
            field(item, const ['creationTime']),
            style: const TextStyle(fontSize: 11, color: Color(0xFF9F9F9F)),
          ),
          onTap: () async {
            final id = field(item, const ['id', 'Id']);
            if (id.isNotEmpty) {
              try {
                await repo.markNoticeRead(id);
                item['isRead'] = true;
                onRead();
              } catch (_) {}
            }
            if (!context.mounted) return;
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => NoticeDetailPage(
                  title: title,
                  time: field(item, const ['creationTime']),
                  content: content,
                ),
              ),
            );
            reload();
          },
        );
      },
    );
  }
}

class _PagedList extends StatefulWidget {
  const _PagedList({
    required this.load,
    required this.itemBuilder,
    required this.emptyText,
    this.reloadToken = '',
  });

  final Future<List<Map<String, dynamic>>> Function(int page) load;
  final Widget Function(
    BuildContext context,
    Map<String, dynamic> item,
    VoidCallback reload,
  ) itemBuilder;
  final String emptyText;
  final String reloadToken;

  @override
  State<_PagedList> createState() => _PagedListState();
}

class _PagedListState extends State<_PagedList> {
  final _items = <Map<String, dynamic>>[];
  int _page = 1;
  int _ticket = 0;
  bool _loading = true;
  bool _more = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch(reset: true);
  }

  @override
  void didUpdateWidget(covariant _PagedList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadToken != widget.reloadToken) _fetch(reset: true);
  }

  Future<void> _fetch({required bool reset}) async {
    if (!reset && (_busy || !_more)) return;
    final ticket = ++_ticket;
    _busy = true;
    if (reset && mounted) {
      setState(() {
        _loading = _items.isEmpty;
        _error = null;
      });
    }
    try {
      final page = reset ? 1 : _page;
      final list = await widget.load(page);
      if (!mounted || ticket != _ticket) return;
      setState(() {
        if (reset) {
          _items
            ..clear()
            ..addAll(list);
        } else {
          _items.addAll(list);
        }
        _page = page + 1;
        _more = list.length >= 20;
        _loading = false;
        _error = null;
      });
    } on ApiException catch (error) {
      if (!mounted || ticket != _ticket) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    } finally {
      if (ticket == _ticket) _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null && _items.isEmpty) {
      return _ErrorText(message: _error!, onRetry: () => _fetch(reset: true));
    }
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _fetch(reset: true),
        child: ListView(
          children: [
            const SizedBox(height: 120),
            Center(child: Text(widget.emptyText)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _fetch(reset: true),
      child: NotificationListener<ScrollNotification>(
        onNotification: (notice) {
          if (notice.metrics.pixels > notice.metrics.maxScrollExtent - 120) {
            _fetch(reset: false);
          }
          return false;
        },
        child: ListView.separated(
          itemCount: _items.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) => widget.itemBuilder(
            context,
            _items[index],
            () => _fetch(reset: true),
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, this.url});

  final String name;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final label = name.isEmpty
        ? '群'
        : (name.length <= 2 ? name : name.substring(name.length - 2));
    final fallback = ColoredBox(
      color: const Color(0xFFEAF2FF),
      child: Center(
        child: Text(label, style: const TextStyle(color: themeBlue, fontSize: 14)),
      ),
    );
    return ClipOval(
      child: SizedBox(
        width: 44,
        height: 44,
        child: url == null || url!.isEmpty
            ? fallback
            : Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
              ),
      ),
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message),
          TextButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}

String _shortTime(String raw) {
  if (raw.length >= 16) return raw.substring(5, 16);
  return raw;
}

String _receiveTime(Map<String, dynamic> item) {
  if (field(item, const ['orderInFactoryTime']).isNotEmpty) {
    return field(item, const ['arriveTime']);
  }
  switch (asInt(item['state'])) {
    case 1:
      return field(item, const ['creationTime']);
    case 2:
      return field(item, const ['receiveTime']);
    case 3:
      return field(item, const ['takeTime']);
    default:
      return field(item, const ['message', 'creationTime']);
  }
}
