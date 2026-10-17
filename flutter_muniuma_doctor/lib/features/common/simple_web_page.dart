import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class SimpleWebPage extends StatefulWidget {
  const SimpleWebPage({
    super.key,
    required this.title,
    required this.url,
    this.onPlaceOrder,
  });

  final String title;
  final String url;
  final void Function(Map<String, dynamic> payload)? onPlaceOrder;

  @override
  State<SimpleWebPage> createState() => _SimpleWebPageState();
}

class _SimpleWebPageState extends State<SimpleWebPage> {
  late final WebViewController _controller = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..addJavaScriptChannel(
      'placeAnOrder',
      onMessageReceived: (message) {
        final handler = widget.onPlaceOrder;
        if (handler == null) return;
        final raw = message.message;
        Map<String, dynamic> payload = {};
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map) payload = Map<String, dynamic>.from(decoded);
        } catch (_) {
          payload = {'patientName': raw};
        }
        handler(payload);
      },
    )
    ..loadRequest(Uri.parse(widget.url));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: WebViewWidget(controller: _controller),
    );
  }
}
