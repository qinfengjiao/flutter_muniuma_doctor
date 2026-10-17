import 'package:flutter/material.dart';
import 'package:flutter_muniuma_doctor/core/network/api_client.dart';
import 'package:flutter_muniuma_doctor/features/message/message_repository.dart';

class TrialFeedbackPage extends StatefulWidget {
  const TrialFeedbackPage({
    super.key,
    required this.repo,
    required this.orderId,
    required this.title,
    required this.done,
  });

  final MessageRepository repo;
  final String orderId;
  final String title;
  final bool done;

  @override
  State<TrialFeedbackPage> createState() => _TrialFeedbackPageState();
}

class _TrialFeedbackPageState extends State<TrialFeedbackPage> {
  final _detail = TextEditingController();
  final _pass = <String, bool>{};
  List<Map<String, dynamic>> _items = const [];
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _detail.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = widget.done
          ? await widget.repo.trialResults(widget.orderId)
          : await widget.repo.trialOptions(widget.orderId);
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
        for (final item in list) {
          final id = _trialId(item);
          if (id.isNotEmpty) _pass[id] = true;
        }
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    }
  }

  Future<void> _submit() async {
    final trails = <Map<String, dynamic>>[];
    for (final item in _items) {
      final id = _trialId(item);
      if (id.isEmpty) continue;
      trails.add({
        'orderTrialId': id,
        'isPass': _pass[id] ?? true,
        'triProblemStr': '',
        'trialProblemSolveStr': '',
        'onceAgainTrialId': '',
        'trialProblemSolveIds': '',
        'detail': _detail.text.trim(),
      });
    }
    if (trails.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有可提交的试戴项')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await widget.repo.submitTrial(orderId: widget.orderId, trails: trails);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('提交成功')),
      );
      Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.done ? '试戴结果' : '试戴反馈')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!),
                      TextButton(onPressed: _load, child: const Text('重试')),
                    ],
                  ),
                )
              : _items.isEmpty
                  ? const Center(child: Text('暂无试戴数据'))
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              widget.title,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _items.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 12),
                            itemBuilder: (_, index) => widget.done
                                ? _resultCard(_items[index])
                                : _optionCard(_items[index], index),
                          ),
                        ),
                        if (!widget.done) _submitBar(),
                      ],
                    ),
    );
  }

  Widget _optionCard(Map<String, dynamic> item, int index) {
    final id = _trialId(item);
    final title = _optionTitle(item, index);
    final passed = _pass[id] ?? true;
    return Card(
      elevation: 0,
      color: const Color(0xFFF7F8F9),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title),
            const SizedBox(height: 8),
            Row(
              children: [
                ChoiceChip(
                  label: const Text('合格'),
                  selected: passed,
                  onSelected: (_) => setState(() => _pass[id] = true),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('不合格'),
                  selected: !passed,
                  onSelected: (_) => setState(() => _pass[id] = false),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultCard(Map<String, dynamic> item) {
    const labels = {
      'productName': '产品',
      'trialName': '试戴',
      'tooth': '牙位',
      'isPass': '结果',
      'detail': '备注',
      'triProblemStr': '问题',
      'trialProblemSolveStr': '处理',
      'completionTime': '时间',
    };
    final rows = <Widget>[];
    for (final entry in labels.entries) {
      final value = item[entry.key];
      if (value == null || '$value'.isEmpty) continue;
      final text = entry.key == 'isPass'
          ? (asBool(value) ? '合格' : '不合格')
          : '$value';
      rows.add(Text('${entry.value}：$text'));
    }
    if (rows.isEmpty) {
      rows.add(const Text('已反馈'));
    }
    return Card(
      elevation: 0,
      color: const Color(0xFFF7F8F9),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: rows,
        ),
      ),
    );
  }

  Widget _submitBar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          children: [
            TextField(
              controller: _detail,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: '备注',
                filled: true,
                fillColor: Color(0xFFF7F8F9),
                border: OutlineInputBorder(borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                child: Text(_submitting ? '提交中...' : '提交反馈'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _trialId(Map<String, dynamic> item) =>
      field(item, const ['orderTrialId', 'id', 'Id']);

  String _optionTitle(Map<String, dynamic> item, int index) {
    final title = field(item, const [
      'productName',
      'trialName',
      'name',
      'fullProductName',
      'tooth',
    ]);
    return title.isEmpty ? '试戴项 ${index + 1}' : title;
  }
}
