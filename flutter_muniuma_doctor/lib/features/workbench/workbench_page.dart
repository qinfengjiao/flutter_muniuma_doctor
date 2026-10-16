import 'package:flutter/material.dart';
import 'package:flutter_muniuma_doctor/core/config/app_config.dart';
import 'package:flutter_muniuma_doctor/core/network/api_client.dart';
import 'package:flutter_muniuma_doctor/core/session/app_session.dart';
import 'package:flutter_muniuma_doctor/features/auth/captcha_sheet.dart';
import 'package:flutter_muniuma_doctor/features/auth/login_page.dart';
import 'package:flutter_muniuma_doctor/features/common/simple_web_page.dart';
import 'package:flutter_muniuma_doctor/features/workbench/sub_pages.dart';
import 'package:flutter_muniuma_doctor/features/workbench/workbench_repository.dart';
import 'package:url_launcher/url_launcher.dart';

class WorkbenchPage extends StatefulWidget {
  const WorkbenchPage({super.key, required this.session, required this.repo});

  final AppSession session;
  final WorkbenchRepository repo;

  @override
  State<WorkbenchPage> createState() => _WorkbenchPageState();
}

class _WorkbenchPageState extends State<WorkbenchPage> {
  HomeSnapshot? _data;
  bool _loading = true;
  int _page = 1;
  bool _loadingMore = false;
  final List<Map<String, dynamic>> _orders = [];
  String? _hospitalId;

  @override
  void initState() {
    super.initState();
    _hospitalId = widget.session.hospitalId;
    widget.session.addListener(_onSession);
    _load();
  }

  @override
  void dispose() {
    widget.session.removeListener(_onSession);
    super.dispose();
  }

  void _onSession() {
    if (!mounted) return;
    if (widget.session.hospitalId != _hospitalId) {
      _hospitalId = widget.session.hospitalId;
      _load();
    } else {
      setState(() {});
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final snapshot = await widget.repo.loadHome();
    if (!mounted) return;
    setState(() {
      _data = snapshot;
      _orders
        ..clear()
        ..addAll(snapshot.inFactory);
      _page = 2;
      _loading = false;
    });
    if (snapshot.message != null && snapshot.message!.isNotEmpty) {
      showTip(context, snapshot.message!);
    }
  }

  Future<void> _loadMore() async {
    final data = _data;
    if (data == null || !data.hasMore || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final more = await widget.repo.orders(page: _page, state: 2);
      if (!mounted) return;
      setState(() {
        _orders.addAll(more);
        _page += 1;
        _data = HomeSnapshot(
          banners: data.banners,
          express: data.express,
          pending: data.pending,
          soon: data.soon,
          favorites: data.favorites,
          inFactory: _orders,
          waitCount: data.waitCount,
          hasMore: more.length >= 10,
          aiEnabled: data.aiEnabled,
        );
      });
    } on ApiException catch (error) {
      if (mounted) showTip(context, error.message);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return Scaffold(
      backgroundColor: const Color(0xFFF2F7FA),
      body: Column(
        children: [
          _WorkbenchHeader(
            session: widget.session,
            onHospital: _switchHospital,
            onSearch: () => _push(SearchPage(repo: widget.repo)),
            onService: () => _push(CustomerServicePage(repo: widget.repo)),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _loading && data == null
                  ? const Center(child: CircularProgressIndicator())
                  : NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        if (notification.metrics.pixels >
                            notification.metrics.maxScrollExtent - 80) {
                          _loadMore();
                        }
                        return false;
                      },
                      child: ListView(
                        padding: const EdgeInsets.only(bottom: 24),
                        children: [
                          if (data != null) ...[
                            _Banner(items: data.banners, session: widget.session),
                            if (data.express.isNotEmpty)
                              _ExpressStrip(
                                items: data.express,
                                onOpenShipped: () =>
                                    _push(ShippedPage(repo: widget.repo)),
                              ),
                            _MenuGrid(
                              waitCount: data.waitCount,
                              onTap: _openMenu,
                            ),
                            if (data.pending.isNotEmpty)
                              _Section(
                                title: '待处理',
                                onMore: () => _push(PendingPage(repo: widget.repo)),
                                child: SizedBox(
                                  height: 72,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    itemCount: data.pending.length,
                                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                                    itemBuilder: (_, index) => _ChipCard(
                                      item: data.pending[index],
                                      onTap: () => _openOrder(data.pending[index]),
                                    ),
                                  ),
                                ),
                              ),
                            if (data.soon.isNotEmpty)
                              _Section(
                                title: '即将出厂',
                                onMore: () => _push(SoonPage(repo: widget.repo)),
                                child: Column(
                                  children: [
                                    for (final item in data.soon.take(3))
                                      _OrderTile(
                                        item: item,
                                        onTap: () => _openOrder(item),
                                      ),
                                  ],
                                ),
                              ),
                            if (data.favorites.isNotEmpty)
                              _Section(
                                title: '快速下单',
                                child: GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    mainAxisSpacing: 12,
                                    crossAxisSpacing: 12,
                                    childAspectRatio: 0.9,
                                  ),
                                  itemCount: data.favorites.length,
                                  itemBuilder: (_, index) {
                                    final item = data.favorites[index];
                                    return _ProductCard(
                                      item: item,
                                      loved: index == 0,
                                      image: AppConfig.imageUrl(
                                        field(item, const ['listCos', 'rotationCos']),
                                        widget.session.env.cosDomain,
                                      ),
                                      onTap: () => _push(
                                        RecordDetailPage(
                                          title: field(item, const [
                                            'customName',
                                            'productName',
                                          ]),
                                          data: item,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            const _SectionTitle(title: '在厂订单'),
                            if (_orders.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(24),
                                child: Center(child: Text('暂无在厂订单')),
                              ),
                            for (final item in _orders)
                              _OrderTile(item: item, onTap: () => _openOrder(item)),
                            if (_loadingMore)
                              const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(child: CircularProgressIndicator()),
                              ),
                          ],
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: data?.aiEnabled == true
          ? FloatingActionButton(
              backgroundColor: themeBlue,
              onPressed: () {
                showTip(context, 'AI 助手已开启');
              },
              child: const Icon(Icons.smart_toy_outlined),
            )
          : null,
    );
  }

  void _push(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  void _openMenu(String title) {
    switch (title) {
      case '已发货':
        _push(ShippedPage(repo: widget.repo));
      case '产品库':
        _push(ProductLibraryPage(repo: widget.repo));
      case '待下单':
        _push(WaitOrderPage(repo: widget.repo));
      case '实验室':
        _push(LaboratoryPage(repo: widget.repo));
      case '病历':
        _openMedicalRecord();
    }
  }

  Future<void> _openMedicalRecord() async {
    if (widget.session.token.isEmpty) {
      showTip(context, '没有您的病历');
      return;
    }
    try {
      final token = await withLoading(context, widget.repo.medicalRecordToken());
      if (!mounted || token == null || token.isEmpty) {
        if (mounted) showTip(context, '没有您的病历');
        return;
      }
      final url =
          '${widget.session.env.medicalRecordDomain}emr_ysapp/#/?token=${Uri.encodeComponent(token)}';
      _push(SimpleWebPage(title: '病历管理', url: url));
    } on ApiException catch (error) {
      if (mounted) showTip(context, error.message);
    }
  }

  void _openOrder(Map<String, dynamic> item) {
    final id = field(item, const ['id', 'Id', 'orderId']);
    _push(OrderDetailPage(repo: widget.repo, orderId: id, preview: item));
  }

  Future<void> _switchHospital() async {
    try {
      final list = await withLoading(context, widget.repo.hospitals());
      if (!mounted || list == null || list.isEmpty) {
        if (mounted) showTip(context, '暂无诊所');
        return;
      }
      final selected = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        builder: (context) {
          return SafeArea(
            child: ListView(
              children: [
                for (final item in list)
                  ListTile(
                    title: Text(field(item, const ['fullName', 'smallName'])),
                    onTap: () => Navigator.pop(context, item),
                  ),
              ],
            ),
          );
        },
      );
      if (selected == null || !mounted) return;
      final id = field(selected, const ['id', 'Id']);
      await withLoading(context, widget.repo.switchHospital(id));
    } on ApiException catch (error) {
      if (mounted) showTip(context, error.message);
    }
  }
}

class _WorkbenchHeader extends StatelessWidget {
  const _WorkbenchHeader({
    required this.session,
    required this.onHospital,
    required this.onSearch,
    required this.onService,
  });

  final AppSession session;
  final VoidCallback onHospital;
  final VoidCallback onSearch;
  final VoidCallback onService;

  @override
  Widget build(BuildContext context) {
    final avatar = AppConfig.imageUrl(session.avatar, session.env.cosDomain);
    return Container(
      color: themeBlue,
      padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 12, 8, 16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.white24,
            child: avatar == null
                ? const Icon(Icons.person, color: Colors.white)
                : ClipOval(
                    child: Image.network(
                      avatar,
                      width: 32,
                      height: 32,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.person, color: Colors.white),
                    ),
                  ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: InkWell(
              onTap: onHospital,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.19),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        session.hospitalName,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 18),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: onSearch,
            icon: const Icon(Icons.search, color: Colors.white),
          ),
          IconButton(
            onPressed: onService,
            icon: const Icon(Icons.support_agent, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.items, required this.session});

  final List<Map<String, dynamic>> items;
  final AppSession session;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox(height: 8);
    return SizedBox(
      height: 148,
      child: PageView.builder(
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final image = AppConfig.imageUrl(
            field(item, const ['coverCos']),
            session.env.cosDomain,
          );
          return GestureDetector(
            onTap: () {
              final url = field(item, const ['url']);
              if (url.startsWith('http')) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SimpleWebPage(
                      title: field(item, const ['name']).isEmpty
                          ? '详情'
                          : field(item, const ['name']),
                      url: url,
                    ),
                  ),
                );
              }
            },
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: const Color(0xFFD7E9F8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: image == null
                  ? Center(child: Text(field(item, const ['name', 'patient'])))
                  : Image.network(
                      image,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (_, _, _) => Center(
                        child: Text(field(item, const ['name', 'patient'])),
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }
}

class _ExpressStrip extends StatelessWidget {
  const _ExpressStrip({required this.items, required this.onOpenShipped});

  final List<Map<String, dynamic>> items;
  final VoidCallback onOpenShipped;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 16),
        itemBuilder: (_, index) {
          final item = items[index];
          final type = int.tryParse('${item['logisticsType']}') ?? 0;
          final patient = field(item, const ['patientName']);
          final text = type == 1
              ? '$patient · ${field(item, const ['salesmanName'])}'
              : '$patient · ${field(item, const ['logisticName', 'orderNo'])}';
          return InkWell(
            onTap: () async {
              if (type == 1) {
                final phone = field(item, const ['salesmanPhoneNumber']);
                if (phone.isNotEmpty) {
                  await launchUrl(Uri.parse('tel:$phone'));
                }
              } else if (type == 2) {
                onOpenShipped();
              }
            },
            child: Center(child: Text(text, style: const TextStyle(fontSize: 13))),
          );
        },
      ),
    );
  }
}

class _MenuGrid extends StatelessWidget {
  const _MenuGrid({required this.waitCount, required this.onTap});

  final int waitCount;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    const items = [
      ('已发货', Icons.local_shipping_outlined),
      ('产品库', Icons.inventory_2_outlined),
      ('待下单', Icons.assignment_outlined),
      ('实验室', Icons.science_outlined),
      ('病历', Icons.description_outlined),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Row(
        children: [
          for (final item in items)
            Expanded(
              child: InkWell(
                onTap: () => onTap(item.$1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    children: [
                      Badge(
                        isLabelVisible: item.$1 == '待下单' && waitCount > 0,
                        label: Text('$waitCount'),
                        child: Icon(item.$2, color: themeBlue, size: 28),
                      ),
                      const SizedBox(height: 6),
                      Text(item.$1, style: const TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.onMore});

  final String title;
  final Widget child;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SectionTitle(title: title, onMore: onMore),
        child,
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.onMore});

  final String title;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const Spacer(),
          if (onMore != null)
            TextButton(onPressed: onMore, child: const Text('查看更多')),
        ],
      ),
    );
  }
}

class _ChipCard extends StatelessWidget {
  const _ChipCard({required this.item, required this.onTap});

  final Map<String, dynamic> item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 180,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                field(item, const ['patientName', 'name']),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                field(item, const ['orderNo']),
                style: const TextStyle(fontSize: 12, color: Color(0xFF949495)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({required this.item, required this.onTap});

  final Map<String, dynamic> item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final progress = double.tryParse('${item['workSequenceRate']}') ?? 0;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        onTap: onTap,
        title: Text(field(item, const ['patientName', 'name'])),
        subtitle: Text(
          [
            field(item, const ['orderNo']),
            field(item, const ['stateName', 'expectOutStr', 'currentWorkSequence']),
          ].where((text) => text.isNotEmpty).join('  '),
        ),
        trailing: progress > 0
            ? Text('${(progress * 100).round()}%')
            : const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.item,
    required this.loved,
    required this.image,
    required this.onTap,
  });

  final Map<String, dynamic> item;
  final bool loved;
  final String? image;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = field(item, const ['customName', 'productName']);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                      child: image == null
                          ? const ColoredBox(color: Color(0xFFF2F7FA))
                          : Image.network(
                              image!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  const ColoredBox(color: Color(0xFFF2F7FA)),
                            ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      color: loved ? const Color(0xFFFFAB1A) : const Color(0xFF23A0FF),
                      child: Text(
                        loved ? '最爱' : '常用',
                        style: const TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}
