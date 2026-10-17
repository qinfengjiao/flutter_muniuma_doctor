import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:flutter_muniuma_doctor/core/network/api_client.dart';
import 'package:flutter_muniuma_doctor/core/session/app_session.dart';
import 'package:flutter_muniuma_doctor/features/place_order/place_order_page.dart';
import 'package:flutter_muniuma_doctor/features/place_order/place_order_repository.dart';
import 'package:flutter_muniuma_doctor/features/place_order/place_order_ui.dart';

const _example =
    '举例：\n患者姓名是张三\n下单D2数码氧化锆全瓷牙的左上123牙位\n百丹特系统标准植体\n左上12连体，左上3单独\n使用口扫取模\n...';

class AudioPlaceOrderPage extends StatefulWidget {
  const AudioPlaceOrderPage({
    super.key,
    required this.repo,
    required this.session,
    required this.hospital,
    required this.factory,
    required this.doctor,
  });

  final PlaceOrderRepository repo;
  final AppSession session;
  final Map<String, dynamic> hospital;
  final Map<String, dynamic> factory;
  final Map<String, dynamic> doctor;

  @override
  State<AudioPlaceOrderPage> createState() => _AudioPlaceOrderPageState();
}

class _AudioPlaceOrderPageState extends State<AudioPlaceOrderPage> {
  final _text = TextEditingController();
  final _recorder = AudioRecorder();
  final _files = <Map<String, dynamic>>[];
  final _recognized = <String>[];
  Timer? _timer;
  StreamSubscription<Amplitude>? _levels;
  int _seconds = 0;
  double _level = 0;
  bool _recording = false;
  bool _started = false;
  bool _busy = false;

  @override
  void dispose() {
    _timer?.cancel();
    _levels?.cancel();
    _recorder.dispose();
    _text.dispose();
    super.dispose();
  }

  void _tip(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggle() async {
    if (_busy) return;
    if (_recording) {
      await _stop(upload: true);
    } else {
      await _start();
    }
  }

  Future<void> _start() async {
    if (!await _recorder.hasPermission()) {
      if (mounted) _tip('请允许使用麦克风');
      return;
    }
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/voice_order_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
    _seconds = 0;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _seconds += 1;
      if (_seconds >= 60) {
        _stop(upload: true);
      } else if (mounted) {
        setState(() {});
      }
    });
    _levels?.cancel();
    _levels = _recorder.onAmplitudeChanged(const Duration(milliseconds: 120)).listen((amp) {
      final level = ((amp.current + 50) / 50).clamp(0.0, 1.0);
      if (mounted) setState(() => _level = level);
    });
    if (!mounted) return;
    setState(() {
      _recording = true;
      _started = true;
    });
  }

  Future<void> _stop({required bool upload}) async {
    if (!_recording) return;
    _timer?.cancel();
    _timer = null;
    await _levels?.cancel();
    _levels = null;
    final seconds = _seconds;
    _recording = false;
    final path = await _recorder.stop();
    if (!mounted) return;
    setState(() => _level = 0);
    if (!upload || path == null || path.isEmpty) return;
    if (seconds < 3) {
      _tip('说话太短');
      return;
    }
    await _recognize(path);
  }

  Future<void> _recognize(String path) async {
    setState(() => _busy = true);
    try {
      final uploaded = await widget.repo.uploadFiles([path]);
      final models = jsonDecode(uploaded);
      if (models is! List || models.isEmpty) {
        throw ApiException('语音上传失败');
      }
      final file = asMap(models.first);
      final url = field(file, const ['url']);
      if (url.isEmpty) throw ApiException('语音上传失败');
      _files.add(file);
      final text = await widget.repo.speechText(
        speechUrl: url,
        factoryId: field(widget.factory, const ['factoryId', 'FactoryId']),
      );
      _recognized.add(text);
      _text.text = '${_text.text}$text';
      _text.selection = TextSelection.collapsed(offset: _text.text.length);
    } on ApiException catch (error) {
      if (mounted) _tip(error.message);
    } catch (_) {
      if (mounted) _tip('语音上传失败');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    final speechText = _text.text.trim();
    if (speechText.isEmpty) {
      _tip('请输入文本');
      return;
    }
    if (_recording) await _stop(upload: true);
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final speech = await widget.repo.createOrderBySpeech(
        speechSourceUrl: jsonEncode(_files).replaceAll(r'\', ''),
        speechSourceText: _recognized.join(),
        speechText: speechText,
        hospitalDoctorId: field(widget.doctor, const [
          'hospitalDoctorId',
          'HospitalDoctorId',
        ]),
        factoryId: field(widget.factory, const ['factoryId', 'FactoryId']),
      );
      speech['orderText'] = speechText;
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlaceOrderPage(
            repo: widget.repo,
            session: widget.session,
            hospital: widget.hospital,
            factory: widget.factory,
            doctor: widget.doctor,
            speech: speech,
            speechAudioCos: _files.isEmpty ? '' : jsonEncode(_files),
          ),
        ),
      );
    } on ApiException catch (error) {
      if (mounted) _tip(error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final titleHeight = MediaQuery.sizeOf(context).width * 62 / 375;
    return OrderBluePage(
      title: '语音下单',
      child: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F8),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              _example,
              style: TextStyle(color: Color(0xFF3F3F3F), fontSize: 14, height: 1.45),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Stack(
                children: [
                  const Positioned.fill(
                    child: OrderIcon('bg_语音输入', fit: BoxFit.fill),
                  ),
                  Column(
                    children: [
                      OrderIcon('audio_img_标题', width: double.infinity, height: titleHeight, fit: BoxFit.fill),
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Column(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _text,
                                  maxLines: null,
                                  expands: true,
                                  textAlignVertical: TextAlignVertical.top,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: orderInk,
                                  ),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.fromLTRB(12, 12, 12, 0),
                                  ),
                                ),
                              ),
                              SizedBox(
                                height: 96,
                                child: Stack(
                                  children: [
                                    Positioned(
                                      left: 0,
                                      right: 0,
                                      bottom: 42,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          _SoundBars(level: _level),
                                          const SizedBox(width: 10),
                                          GestureDetector(
                                            onTap: _toggle,
                                            child: const OrderIcon('icon_麦克风', width: 29, height: 36),
                                          ),
                                          const SizedBox(width: 10),
                                          Transform.flip(
                                            flipX: true,
                                            child: _SoundBars(level: _level),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Positioned(
                                      left: 0,
                                      right: 0,
                                      bottom: 14,
                                      child: Center(child: _actionButton()),
                                    ),
                                    const Positioned(
                                      right: 12,
                                      bottom: 20,
                                      child: Text(
                                        'AI识别',
                                        style: TextStyle(color: Color(0xFFD7D8D8), fontSize: 10),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(16, 20, 16, 20 + MediaQuery.paddingOf(context).bottom),
                        child: SizedBox(
                          height: 44,
                          width: double.infinity,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: orderBlue,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            ),
                            onPressed: _busy ? null : _submit,
                            child: const Text('提交下单', style: TextStyle(fontSize: 18)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_busy)
                    const Positioned.fill(
                      child: ColoredBox(
                        color: Color(0x33000000),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton() {
    if (_recording) {
      return GestureDetector(
        onTap: _toggle,
        child: Container(
          width: 111,
          height: 25,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFECF1FF),
            borderRadius: BorderRadius.circular(12.5),
          ),
          child: const Text(
            '停止语音输入',
            style: TextStyle(color: Color(0xFF2F7BEF), fontSize: 14),
          ),
        ),
      );
    }
    if (_started) {
      return GestureDetector(
        onTap: _toggle,
        child: const OrderIcon('icon_continue_record_audio', width: 83, height: 25),
      );
    }
    return GestureDetector(
      onTap: _toggle,
      child: const OrderIcon('start_recording', width: 83, height: 25),
    );
  }
}

class _SoundBars extends StatelessWidget {
  const _SoundBars({required this.level});

  final double level;

  @override
  Widget build(BuildContext context) {
    const pattern = [0.35, 0.55, 0.8, 1, 0.7, 0.45, 0.9, 0.6];
    return SizedBox(
      width: 80,
      height: 28,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (final item in pattern)
            Container(
              width: 3,
              height: 6 + 22 * item * level,
              decoration: BoxDecoration(
                color: const Color(0xFF2F7BEF),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    );
  }
}
