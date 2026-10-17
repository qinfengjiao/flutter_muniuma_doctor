import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:flutter_muniuma_doctor/core/network/api_client.dart';
import 'package:flutter_muniuma_doctor/features/place_order/place_order_draft.dart';
import 'package:flutter_muniuma_doctor/features/place_order/place_order_repository.dart';
import 'package:flutter_muniuma_doctor/features/place_order/place_order_ui.dart';

const _maxPhotos = 10;

Future<void> pickOrderPhotos(BuildContext context, List<String> photos) async {
  if (photos.isNotEmpty) {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => _PhotoListPage(photos: photos)),
    );
    return;
  }
  await _appendPhotos(context, photos);
}

Future<void> _appendPhotos(BuildContext context, List<String> photos) async {
  if (photos.length >= _maxPhotos) return;
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text('拍照'),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            title: const Text('从相册选择'),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
  if (source == null || !context.mounted) return;
  final picker = ImagePicker();
  final remain = _maxPhotos - photos.length;
  try {
    if (source == ImageSource.camera) {
      final file = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
      if (file != null) photos.add(file.path);
    } else {
      final files = await picker.pickMultiImage(imageQuality: 85, limit: remain);
      photos.addAll(files.take(remain).map((item) => item.path));
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('无法打开相册或相机')));
    }
  }
}

class _PhotoListPage extends StatefulWidget {
  const _PhotoListPage({required this.photos});

  final List<String> photos;

  @override
  State<_PhotoListPage> createState() => _PhotoListPageState();
}

class _PhotoListPageState extends State<_PhotoListPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('已选图片（${widget.photos.length}）'),
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () async {
              await _appendPhotos(context, widget.photos);
              if (mounted) setState(() {});
            },
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        itemCount: widget.photos.length,
        itemBuilder: (_, index) {
          return Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(File(widget.photos[index]), fit: BoxFit.cover),
              ),
              Positioned(
                right: 4,
                top: 4,
                child: GestureDetector(
                  onTap: () => setState(() => widget.photos.removeAt(index)),
                  child: const CircleAvatar(
                    radius: 12,
                    backgroundColor: Colors.black54,
                    child: Icon(Icons.close, size: 14, color: Colors.white),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

Future<void> recordOrderAudio(BuildContext context, List<OrderAudio> audios) async {
  if (audios.isNotEmpty) {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (context) => _AudioListSheet(audios: audios),
    );
    return;
  }
  final audio = await showModalBottomSheet<OrderAudio>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => const _RecordSheet(),
  );
  if (audio != null) audios.add(audio);
}

class _AudioListSheet extends StatefulWidget {
  const _AudioListSheet({required this.audios});

  final List<OrderAudio> audios;

  @override
  State<_AudioListSheet> createState() => _AudioListSheetState();
}

class _AudioListSheetState extends State<_AudioListSheet> {
  final _player = AudioPlayer();
  String? _playing;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          const Text('录音备注', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          for (var i = 0; i < widget.audios.length; i++)
            ListTile(
              title: Text('录音 ${widget.audios[i].seconds}秒'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () async {
                      if (_playing == widget.audios[i].path) {
                        await _player.stop();
                        setState(() => _playing = null);
                        return;
                      }
                      await _player.play(DeviceFileSource(widget.audios[i].path));
                      setState(() => _playing = widget.audios[i].path);
                    },
                    icon: Icon(_playing == widget.audios[i].path ? Icons.stop : Icons.play_arrow),
                  ),
                  IconButton(
                    onPressed: () => setState(() => widget.audios.removeAt(i)),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
          TextButton(
            onPressed: () async {
              final audio = await showModalBottomSheet<OrderAudio>(
                context: context,
                backgroundColor: Colors.transparent,
                builder: (context) => const _RecordSheet(),
              );
              if (audio != null) setState(() => widget.audios.add(audio));
            },
            child: const Text('继续录音'),
          ),
        ],
      ),
    );
  }
}

class _RecordSheet extends StatefulWidget {
  const _RecordSheet();

  @override
  State<_RecordSheet> createState() => _RecordSheetState();
}

class _RecordSheetState extends State<_RecordSheet> {
  final _recorder = AudioRecorder();
  Timer? _timer;
  int _seconds = 0;
  bool _cancel = false;
  bool _recording = false;
  String? _path;

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (!await _recorder.hasPermission()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请允许使用麦克风')));
      }
      return;
    }
    final dir = await getTemporaryDirectory();
    _path = '${dir.path}/order_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: _path!);
    _seconds = 0;
    _cancel = false;
    _recording = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      _seconds += 1;
      if (_seconds >= 60) {
        await _finish(false);
      } else if (mounted) {
        setState(() {});
      }
    });
    if (mounted) setState(() {});
  }

  Future<void> _finish(bool cancel) async {
    _timer?.cancel();
    _timer = null;
    if (!_recording) return;
    _recording = false;
    final path = await _recorder.stop();
    if (!mounted) return;
    if (cancel || _cancel) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已取消')));
      setState(() => _seconds = 0);
      return;
    }
    if (_seconds < 3) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('说话太短')));
      setState(() => _seconds = 0);
      return;
    }
    Navigator.pop(context, OrderAudio(path ?? _path!, _seconds));
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height,
      child: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (!_recording) Navigator.pop(context);
              },
            ),
          ),
        SizedBox(
          height: 128,
          width: double.infinity,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              const Positioned.fill(
                child: Image(
                  image: AssetImage('assets/place_order/img_按住说话背板.png'),
                  fit: BoxFit.fill,
                ),
              ),
              Positioned(
                bottom: 45,
                left: 0,
                right: 0,
                child: GestureDetector(
                  onLongPressStart: (_) => _start(),
                  onLongPressMoveUpdate: (details) {
                    _cancel = details.localOffsetFromOrigin.dy < -40;
                    setState(() {});
                  },
                  onLongPressEnd: (_) => _finish(_cancel),
                  onLongPressCancel: () => _finish(true),
                  child: Text(
                    _recording ? (_cancel ? '松开取消' : '录音中 $_seconds″  上滑取消') : '按住录音',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: orderInk),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
      ),
    );
  }
}

Future<String?> editOrderRemark(
  BuildContext context, {
  required String initial,
  required PlaceOrderRepository repo,
  required String factoryId,
  required String hospitalDoctorId,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _RemarkDialog(
      initial: initial,
      repo: repo,
      factoryId: factoryId,
      hospitalDoctorId: hospitalDoctorId,
    ),
  );
}

class _RemarkDialog extends StatefulWidget {
  const _RemarkDialog({
    required this.initial,
    required this.repo,
    required this.factoryId,
    required this.hospitalDoctorId,
  });

  final String initial;
  final PlaceOrderRepository repo;
  final String factoryId;
  final String hospitalDoctorId;

  @override
  State<_RemarkDialog> createState() => _RemarkDialogState();
}

class _RemarkDialogState extends State<_RemarkDialog> {
  late final TextEditingController _text = TextEditingController(text: widget.initial);
  List<String> _history = const [];
  int _requestId = 0;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _text.dispose();
    super.dispose();
  }

  void _search(String raw) {
    final keyword = raw.trim();
    _debounce?.cancel();
    if (keyword.isEmpty) {
      setState(() => _history = const []);
      return;
    }
    final requestId = ++_requestId;
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      try {
        final list = await widget.repo.doctorRemarks(
          factoryId: widget.factoryId,
          hospitalDoctorId: widget.hospitalDoctorId,
          keyword: keyword,
        );
        if (!mounted || requestId != _requestId) return;
        setState(() => _history = list);
      } on ApiException {
        if (mounted && requestId == _requestId) setState(() => _history = const []);
      }
    });
  }

  Future<void> _close() async {
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: const Text('是否保存当前备注信息？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('不保存', style: TextStyle(color: Color(0xFFFA4D32)))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('保存')),
        ],
      ),
    );
    if (!mounted) return;
    if (save == true) {
      Navigator.pop(context, _text.text);
    } else if (save == false) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tableHeight = (_history.length * 30.0).clamp(0, 240).toDouble();
    return Center(
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: 275,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text('文字备注', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        ),
                        IconButton(onPressed: _close, icon: const Icon(Icons.close, size: 18)),
                      ],
                    ),
                    TextField(
                      controller: _text,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        hintText: '请输入文字备注',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: _search,
                    ),
                    if (tableHeight > 0)
                      SizedBox(
                        height: tableHeight,
                        child: ListView.builder(
                          itemExtent: 30,
                          itemCount: _history.length,
                          itemBuilder: (_, index) {
                            final item = _history[index];
                            return InkWell(
                              onTap: () {
                                _text.text = item;
                                _text.selection = TextSelection.collapsed(offset: item.length);
                                _search(item);
                              },
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(item, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 40,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: orderBlue,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => Navigator.pop(context, _text.text),
                        child: const Text('确定'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
