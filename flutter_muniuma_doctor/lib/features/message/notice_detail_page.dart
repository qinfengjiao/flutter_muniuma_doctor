import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class NoticeDetailPage extends StatefulWidget {
  const NoticeDetailPage({
    super.key,
    required this.title,
    required this.time,
    required this.content,
  });

  final String title;
  final String time;
  final String content;

  @override
  State<NoticeDetailPage> createState() => _NoticeDetailPageState();
}

class _NoticeDetailPageState extends State<NoticeDetailPage> {
  late final WebViewController _controller = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..loadHtmlString(_document(widget.content));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('消息详情')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              widget.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              widget.time,
              style: const TextStyle(color: Color(0xFF9F9F9F), fontSize: 12),
            ),
          ),
          const Divider(height: 1),
          Expanded(child: WebViewWidget(controller: _controller)),
        ],
      ),
    );
  }
}

String _document(String content) {
  final body = content.trim().isEmpty ? '<p>暂无内容</p>' : content;
  if (body.toLowerCase().contains('<html')) return body;
  return '''
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
  body { font-size: 16px; color: #2C2C2E; margin: 16px; word-break: break-word; }
  img { max-width: 100%; height: auto; }
</style>
</head>
<body>$body</body>
</html>
''';
}
