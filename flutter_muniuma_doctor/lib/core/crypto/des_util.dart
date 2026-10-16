import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// 与 iOS 登录密码加密一致：DES/ECB，密钥 `muniuma2`，不足 8 字节用 0x00 补齐，结果做 Base64。
///
/// 当前 pointycastle 只保留三重 DES。三把子密钥相同时，EDE 与单次 DES 等价。
String encryptUseDes(String plainText) {
  final source = utf8.encode(plainText);
  final pad = source.length % 8 == 0 ? 0 : 8 - (source.length % 8);
  final padded = Uint8List(source.length + pad)..setRange(0, source.length, source);
  return base64Encode(_process(padded, true));
}

Uint8List decryptUseDes(String cipherText) {
  return _process(base64Decode(cipherText), false);
}

Uint8List _desKey() {
  final single = utf8.encode('muniuma2');
  return Uint8List.fromList([...single, ...single, ...single]);
}

Uint8List _process(Uint8List input, bool encrypt) {
  final cipher = ECBBlockCipher(DESedeEngine())
    ..init(encrypt, KeyParameter(_desKey()));
  final output = Uint8List(input.length);
  for (var offset = 0; offset < input.length; offset += cipher.blockSize) {
    cipher.processBlock(input, offset, output, offset);
  }
  return output;
}
