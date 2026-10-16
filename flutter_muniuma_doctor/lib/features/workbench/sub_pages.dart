import 'package:flutter/material.dart';
import 'package:flutter_muniuma_doctor/core/network/api_client.dart';
import 'package:flutter_muniuma_doctor/core/session/app_session.dart';
import 'package:flutter_muniuma_doctor/features/auth/captcha_sheet.dart';
import 'package:flutter_muniuma_doctor/features/workbench/workbench_repository.dart';
import 'package:url_launcher/url_launcher.dart';

class RemoteListPage extends StatefulWidget {
  const RemoteListPage({
    super.key,
    required this.title,
    required this.load,
    this.itemTitle,
    this.itemSubtitle,
    this.embedded = false,
  });

  final String title;
  final Future<List<Map<String, dynamic>>> Function(int page) load;
  final String Function(Map<String, dynamic> item)? itemTitle;
  final String Function(Map<String, dynamic> item)? itemSubtitle;
  final bool embedded;

  @override
  State<RemoteListPage> createState() => _RemoteListPageState();
}

class _RemoteListPageState extends State<RemoteListPage> {
  final List<Map<String, dynamic>> _items = [];
  int _page = 1;
  bool _loading = true;
  bool _more = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch(reset: true);
  }

  Future<void> _fetch({required bool reset}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _page = 1;
      });
    }
    try {
      final list = await widget.load(_page);
      if (!mounted) return;
      setState(() {
        if (reset) _items.clear();
        _items.addAll(list);
        _more = list.length >= 10;
        _page += 1;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = RefreshIndicator(
        onRefresh: () => _fetch(reset: true),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null && _items.isEmpty
                ? ListView(
                    children: [
                      const SizedBox(height: 80),
                      Center(child: Text(_error!)),
                    ],
                  )
                : ListView.separated(
                    itemCount: _items.length + (_more ? 1 : 0),
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      if (index >= _items.length) {
                        return TextButton(
                          onPressed: () => _fetch(reset: false),
                          child: const Text('加载更多'),
                        );
                      }
                      final item = _items[index];
                      final title = widget.itemTitle?.call(item) ??
                          field(item, const [
                            'patientName',
                            'name',
                            'customName',
                            'productName',
                            'fullName',
                          ]);
                      final subtitle = widget.itemSubtitle?.call(item) ??
                          [
                            field(item, const ['orderNo', 'stateName']),
                            field(item, const ['factoryName', 'doctorName']),
                          ].where((text) => text.isNotEmpty).join('  ');
                      return ListTile(
                        title: Text(title.isEmpty ? '未命名' : title),
                        subtitle: subtitle.isEmpty ? null : Text(subtitle),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RecordDetailPage(
                                title: title.isEmpty ? widget.title : title,
                                data: item,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
    );
    if (widget.embedded) return body;
    return Scaffold(appBar: AppBar(title: Text(widget.title)), body: body);
  }
}

class ShippedPage extends StatelessWidget {
  const ShippedPage({super.key, required this.repo});

  final WorkbenchRepository repo;

  @override
  Widget build(BuildContext context) {
    return RemoteListPage(
      title: '已发货',
      load: repo.shipped,
      itemSubtitle: (item) => [
        field(item, const ['orderNo']),
        field(item, const ['shippedTime', 'factoryName']),
      ].where((text) => text.isNotEmpty).join('  '),
    );
  }
}

class PendingPage extends StatelessWidget {
  const PendingPage({super.key, required this.repo});

  final WorkbenchRepository repo;

  @override
  Widget build(BuildContext context) {
    return RemoteListPage(title: '待处理', load: repo.pending);
  }
}

class SoonPage extends StatelessWidget {
  const SoonPage({super.key, required this.repo});

  final WorkbenchRepository repo;

  @override
  Widget build(BuildContext context) {
    return RemoteListPage(title: '即将出厂', load: (_) => repo.soon());
  }
}

class WaitOrderPage extends StatelessWidget {
  const WaitOrderPage({super.key, required this.repo});

  final WorkbenchRepository repo;

  @override
  Widget build(BuildContext context) {
    return RemoteListPage(title: '待下单', load: repo.waitOrders);
  }
}

class ProductLibraryPage extends StatelessWidget {
  const ProductLibraryPage({super.key, required this.repo});

  final WorkbenchRepository repo;

  @override
  Widget build(BuildContext context) {
    return RemoteListPage(
      title: '产品库',
      load: (_) => repo.favorites(),
      itemTitle: (item) => field(item, const ['customName', 'productName']),
      itemSubtitle: (item) => field(item, const ['factoryName', 'priceDisplay']),
    );
  }
}

class LaboratoryPage extends StatelessWidget {
  const LaboratoryPage({super.key, required this.repo});

  final WorkbenchRepository repo;

  @override
  Widget build(BuildContext context) {
    return RemoteListPage(
      title: '实验室',
      load: (_) => repo.laboratories(),
      itemTitle: (item) => field(item, const ['name', 'laboratoryName']),
      itemSubtitle: (item) => field(item, const ['stateName']),
    );
  }
}

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key, required this.repo});

  final WorkbenchRepository repo;

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  int _state = 2;

  @override
  Widget build(BuildContext context) {
    const states = {1: '生产前', 2: '生产中', 3: '待收货', 4: '待评价', 5: '已完成'};
    return Column(
      children: [
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              for (final entry in states.entries)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(entry.value),
                    selected: _state == entry.key,
                    onSelected: (_) => setState(() => _state = entry.key),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: RemoteListPage(
            key: ValueKey(_state),
            title: '订单',
            embedded: true,
            load: (page) => widget.repo.orders(page: page, state: _state),
          ),
        ),
      ],
    );
  }
}

class SearchPage extends StatefulWidget {
  const SearchPage({super.key, required this.repo});

  final WorkbenchRepository repo;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();
  int _tab = 0;
  List<Map<String, dynamic>> _items = const [];
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final keyword = _controller.text.trim();
    setState(() => _loading = true);
    try {
      final list = _tab == 0
          ? await widget.repo.patients(keyword, 1)
          : await widget.repo.orders(
              page: 1,
              patientName: keyword,
              orderNo: RegExp(r'\d').hasMatch(keyword) ? keyword : null,
            );
      if (mounted) setState(() => _items = list);
    } on ApiException catch (error) {
      if (mounted) showTip(context, error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('搜索')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: _tab == 0 ? '患者姓名' : '患者或订单号',
                suffixIcon: IconButton(
                  onPressed: _search,
                  icon: const Icon(Icons.search),
                ),
              ),
            ),
          ),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('患者')),
              ButtonSegment(value: 1, label: Text('订单')),
            ],
            selected: {_tab},
            onSelectionChanged: (value) => setState(() {
              _tab = value.first;
              _items = const [];
            }),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    itemCount: _items.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final item = _items[index];
                      return ListTile(
                        title: Text(
                          field(item, const ['name', 'patientName', 'fullName']),
                        ),
                        subtitle: Text(field(item, const ['phoneNumber', 'orderNo'])),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class CustomerServicePage extends StatefulWidget {
  const CustomerServicePage({super.key, required this.repo});

  final WorkbenchRepository repo;

  @override
  State<CustomerServicePage> createState() => _CustomerServicePageState();
}

class _CustomerServicePageState extends State<CustomerServicePage> {
  List<Map<String, dynamic>> _factories = const [];
  List<Map<String, dynamic>> _staff = const [];
  String? _factoryId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFactories();
  }

  Future<void> _loadFactories() async {
    try {
      final list = await widget.repo.factories();
      if (!mounted) return;
      setState(() {
        _factories = list;
        _factoryId = list.isEmpty ? null : field(list.first, const ['factoryId']);
        _loading = false;
      });
      if (_factoryId != null) await _loadStaff();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      showTip(context, error.message);
    }
  }

  Future<void> _loadStaff() async {
    if (_factoryId == null) return;
    setState(() => _loading = true);
    try {
      final list = await widget.repo.serviceStaff(_factoryId!, 1);
      if (mounted) setState(() => _staff = list);
    } on ApiException catch (error) {
      if (mounted) showTip(context, error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('专属客服')),
      body: _loading && _factories.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_factories.isNotEmpty)
                  DropdownButton<String>(
                    value: _factoryId,
                    items: [
                      for (final item in _factories)
                        DropdownMenuItem(
                          value: field(item, const ['factoryId']),
                          child: Text(field(item, const ['factoryName'])),
                        ),
                    ],
                    onChanged: (value) {
                      setState(() => _factoryId = value);
                      _loadStaff();
                    },
                  ),
                Expanded(
                  child: ListView.separated(
                    itemCount: _staff.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final item = _staff[index];
                      final phone = field(item, const ['phoneNumber']);
                      return ListTile(
                        title: Text(field(item, const ['name'])),
                        subtitle: Text(
                          [
                            field(item, const ['plate']),
                            phone,
                          ].where((text) => text.isNotEmpty).join('  '),
                        ),
                        trailing: phone.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.phone),
                                onPressed: () => launchUrl(Uri.parse('tel:$phone')),
                              ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

class OrderDetailPage extends StatefulWidget {
  const OrderDetailPage({
    super.key,
    required this.repo,
    required this.orderId,
    this.preview,
  });

  final WorkbenchRepository repo;
  final String orderId;
  final Map<String, dynamic>? preview;

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  static const _labels = {
    'orderNo': '订单号',
    'patientName': '患者',
    'doctorName': '医生',
    'factoryName': '工厂',
    'hospitalName': '诊所',
    'stateName': '状态',
    'currentWorkSequence': '当前工序',
    'expectOutTime': '预计出厂',
    'expectArrivalTime': '预计到货',
    'creationTime': '创建时间',
    'shippedTime': '发货时间',
    'orderTypeStr': '订单类型',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.orderId.isEmpty) {
      setState(() {
        _data = widget.preview ?? {};
        _loading = false;
      });
      return;
    }
    try {
      final detail = await widget.repo.orderDetail(widget.orderId);
      if (mounted) {
        setState(() {
          _data = detail.isEmpty ? widget.preview ?? {} : detail;
          _loading = false;
        });
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _data = widget.preview ?? {};
        _loading = false;
      });
      showTip(context, error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data ?? {};
    final rows = [
      for (final entry in _labels.entries)
        if (field(data, [entry.key]).isNotEmpty)
          MapEntry(entry.value, field(data, [entry.key])),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('订单详情')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                for (final row in rows)
                  ListTile(title: Text(row.key), subtitle: Text(row.value)),
                if (rows.isEmpty) const Center(child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('暂无详情'),
                )),
              ],
            ),
    );
  }
}

class RecordDetailPage extends StatelessWidget {
  const RecordDetailPage({super.key, required this.title, required this.data});

  final String title;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final rows = data.entries.where((entry) {
      final value = entry.value;
      return value is String || value is num || value is bool;
    });
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        children: [
          for (final entry in rows)
            ListTile(
              title: Text(entry.key),
              subtitle: Text('${entry.value}'),
            ),
        ],
      ),
    );
  }
}

class MessagePage extends StatefulWidget {
  const MessagePage({super.key, required this.repo});

  final WorkbenchRepository repo;

  @override
  State<MessagePage> createState() => _MessagePageState();
}

class _MessagePageState extends State<MessagePage> {
  List<Map<String, dynamic>> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await widget.repo.conversations();
      if (mounted) {
        setState(() {
          _items = list;
          _loading = false;
          _error = null;
        });
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!));
    if (_items.isEmpty) return const Center(child: Text('暂无会话'));
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        itemCount: _items.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (_, index) {
          final item = _items[index];
          return ListTile(
            title: Text(
              field(item, const ['groupName', 'name', 'patientName', 'title']),
            ),
            subtitle: Text(
              field(item, const ['lastMsg', 'lastMessage', 'content', 'orderNo']),
            ),
            trailing: Text(field(item, const ['unreadCount', 'unreadTotal'])),
          );
        },
      ),
    );
  }
}

class MorePage extends StatelessWidget {
  const MorePage({super.key, required this.session});

  final AppSession session;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 24),
        ListTile(
          title: Text(session.userName.isEmpty ? '未登录' : session.userName),
          subtitle: Text(
            [session.phone, session.hospitalName]
                .where((text) => text.isNotEmpty)
                .join('\n'),
          ),
        ),
        const Divider(),
        ListTile(
          title: const Text('退出登录'),
          onTap: () async {
            await session.logout();
          },
        ),
      ],
    );
  }
}
