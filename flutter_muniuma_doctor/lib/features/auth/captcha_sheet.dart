import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_muniuma_doctor/core/network/api_client.dart';
import 'package:flutter_muniuma_doctor/features/auth/auth_repository.dart';

const _themeBlue = Color(0xFF007FFF);

Future<bool> verifyAndSendCode({
  required BuildContext context,
  required AuthRepository auth,
  required Future<void> Function(String guid, int x) send,
}) async {
  try {
    final challenge = await auth.fetchCaptcha();
    if (!context.mounted) return false;
    final passed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _CaptchaDialog(
          auth: auth,
          initial: challenge,
          onPassed: (guid, x) async {
            await send(guid, x);
          },
        );
      },
    );
    return passed == true;
  } on ApiException catch (error) {
    if (context.mounted) showTip(context, error.message);
    return false;
  }
}

class _CaptchaDialog extends StatefulWidget {
  const _CaptchaDialog({
    required this.auth,
    required this.initial,
    required this.onPassed,
  });

  final AuthRepository auth;
  final CaptchaChallenge initial;
  final Future<void> Function(String guid, int x) onPassed;

  @override
  State<_CaptchaDialog> createState() => _CaptchaDialogState();
}

class _CaptchaDialogState extends State<_CaptchaDialog> {
  late CaptchaChallenge _challenge = widget.initial;
  ui.Image? _background;
  ui.Image? _slider;
  double _offset = 0;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _decode(widget.initial);
  }

  @override
  void dispose() {
    _background?.dispose();
    _slider?.dispose();
    super.dispose();
  }

  Future<void> _decode(CaptchaChallenge challenge) async {
    final background = await _decodeImage(challenge.background);
    final slider = await _decodeImage(challenge.slider);
    if (!mounted) {
      background?.dispose();
      slider?.dispose();
      return;
    }
    _background?.dispose();
    _slider?.dispose();
    setState(() {
      _challenge = challenge;
      _background = background;
      _slider = slider;
      _offset = 0;
      _error = null;
    });
  }

  Future<void> _refresh() async {
    setState(() => _busy = true);
    try {
      final next = await widget.auth.fetchCaptcha();
      await _decode(next);
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit(double displayWidth) async {
    final background = _background;
    if (background == null || _busy) return;
    final scale = displayWidth / background.width;
    final x = (_offset / scale).round();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.auth.checkCaptcha(_challenge.guid, x);
      await widget.onPassed(_challenge.guid, x);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (error) {
      setState(() => _error = error.message);
      await _refresh();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const imageWidth = 300.0;
    final background = _background;
    final slider = _slider;
    final imageHeight = background == null
        ? 160.0
        : imageWidth * background.height / background.width;
    final pieceWidth = slider == null || background == null
        ? 48.0
        : slider.width * (imageWidth / background.width);
    final maxOffset = (imageWidth - pieceWidth).clamp(0, imageWidth).toDouble();

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('安全验证', style: TextStyle(color: Color(0xFF9F9F9F))),
                ),
                IconButton(
                  onPressed: _busy ? null : _refresh,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const Text('拖动下方滑块完成拼图'),
            const SizedBox(height: 12),
            Center(
              child: SizedBox(
                width: imageWidth,
                height: imageHeight,
                child: background == null
                    ? const Center(child: CircularProgressIndicator())
                    : Stack(
                        children: [
                          RawImage(
                            image: background,
                            width: imageWidth,
                            height: imageHeight,
                            fit: BoxFit.fill,
                          ),
                          Positioned(
                            left: _offset,
                            top: 0,
                            child: RawImage(
                              image: slider,
                              width: pieceWidth,
                              height: imageHeight,
                              fit: BoxFit.fill,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            Slider(
              value: maxOffset == 0 ? 0 : _offset.clamp(0, maxOffset),
              max: maxOffset == 0 ? 1 : maxOffset,
              activeColor: _themeBlue,
              onChanged: _busy || maxOffset == 0
                  ? null
                  : (value) => setState(() => _offset = value),
              onChangeEnd: (_) => _submit(imageWidth),
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
            if (_busy) const LinearProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

Future<ui.Image?> _decodeImage(String raw) async {
  final bytes = _base64Bytes(raw);
  if (bytes == null) return null;
  final completer = Completer<ui.Image>();
  ui.decodeImageFromList(bytes, completer.complete);
  return completer.future;
}

Uint8List? _base64Bytes(String raw) {
  var value = raw.trim();
  final comma = value.indexOf(',');
  if (value.startsWith('data:image') && comma >= 0) {
    value = value.substring(comma + 1);
  }
  try {
    return base64Decode(value);
  } catch (_) {
    return null;
  }
}

void showTip(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

Future<T?> withLoading<T>(BuildContext context, Future<T> future) async {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );
  try {
    return await future;
  } finally {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }
}

bool isPhone(String value) => RegExp(r'^1[3-9]\d{9}$').hasMatch(value);

bool isPasswordValid(String value) {
  if (value.length <= 8) return false;
  final hasLetter = RegExp(r'[A-Za-z]').hasMatch(value);
  final hasDigit = RegExp(r'\d').hasMatch(value);
  return hasLetter && hasDigit;
}
