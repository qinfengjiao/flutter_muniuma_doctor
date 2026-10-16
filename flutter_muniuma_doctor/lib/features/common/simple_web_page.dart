import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class SimpleWebPage extends StatefulWidget {
  const SimpleWebPage({super.key, required this.title, required this.url});

  final String title;
  final String url;

  @override
  State<SimpleWebPage> createState() => _SimpleWebPageState();
}

class _SimpleWebPageState extends State<SimpleWebPage> {
  late final WebViewController _controller = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..loadRequest(Uri.parse(widget.url));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: WebViewWidget(controller: _controller),
    );
  }
}
