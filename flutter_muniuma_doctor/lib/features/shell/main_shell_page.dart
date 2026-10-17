import 'package:flutter/material.dart';
import 'package:flutter_muniuma_doctor/core/session/app_session.dart';
import 'package:flutter_muniuma_doctor/features/auth/login_page.dart';
import 'package:flutter_muniuma_doctor/features/message/message_page.dart';
import 'package:flutter_muniuma_doctor/features/place_order/choice_basic_info_page.dart';
import 'package:flutter_muniuma_doctor/features/workbench/sub_pages.dart';
import 'package:flutter_muniuma_doctor/features/workbench/workbench_page.dart';
import 'package:flutter_muniuma_doctor/features/workbench/workbench_repository.dart';

class MainShellPage extends StatefulWidget {
  const MainShellPage({
    super.key,
    required this.session,
    required this.repo,
  });

  final AppSession session;
  final WorkbenchRepository repo;

  @override
  State<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends State<MainShellPage> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      WorkbenchPage(session: widget.session, repo: widget.repo),
      MessagePage(session: widget.session, api: widget.repo.api),
      const SizedBox.shrink(),
      OrdersPage(repo: widget.repo),
      MorePage(session: widget.session),
    ];
    return Scaffold(
      body: IndexedStack(
        index: _index == 2 ? 0 : _index,
        children: [
          pages[0],
          SafeArea(child: pages[1]),
          const SizedBox.shrink(),
          SafeArea(child: pages[3]),
          SafeArea(child: pages[4]),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        indicatorColor: const Color(0x1423A0FF),
        onDestinationSelected: (index) {
          if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChoiceBasicInfoPage(
                  session: widget.session,
                  api: widget.repo.api,
                ),
              ),
            );
            return;
          }
          setState(() => _index = index);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: '工作台'),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            label: '消息',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle, color: themeBlue, size: 32),
            label: '下单',
          ),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: '订单'),
          NavigationDestination(icon: Icon(Icons.more_horiz), label: '更多'),
        ],
      ),
    );
  }
}
