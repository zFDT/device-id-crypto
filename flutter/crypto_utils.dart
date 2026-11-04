import 'dart:typed_data';

import 'package:encrypt/encrypt.dart';
import 'package:pointycastle/export.dart';

/// 加密工具类
/// 使用pointycastle提供原生AES-128-ECB加密和解密功能，避免填充问题
class CryptoUtils {
  /// AES-128-ECB加密（使用原生实现）
  ///
  /// [plaintext] 明文数据（必须是16字节）
  /// [key] AES密钥（必须是16字节）
  /// 返回加密后的数据
  static Uint8List aesEcbEncrypt(Uint8List plaintext, Uint8List key) {
    if (plaintext.length != 16) {
      throw ArgumentError('Plaintext must be exactly 16 bytes, got ${plaintext.length}');
    }
    if (key.length != 16) {
      throw ArgumentError('Key must be exactly 16 bytes, got ${key.length}');
    }

    try {
      // 使用pointycastle原生AES实现，避免填充问题
      final cipher = AESEngine()..init(true, KeyParameter(key));
      final encrypted = Uint8List(16);
      cipher.processBlock(plaintext, 0, encrypted, 0);
      return encrypted;
    } catch (e) {
      // 降级到encrypt包
      try {
        final encrypter = Encrypter(AES(Key(key), mode: AESMode.ecb, padding: null));
        final encrypted = encrypter.encryptBytes(plaintext);
        return encrypted.bytes;
      } catch (e2) {
        throw ArgumentError('AES加密失败: $e2');
      }
    }
  }

  /// AES-128-ECB解密（使用原生实现）
  ///
  /// [ciphertext] 密文数据（必须是16字节）
  /// [key] AES密钥（必须是16字节）
  /// 返回解密后的数据
  static Uint8List aesEcbDecrypt(Uint8List ciphertext, Uint8List key) {
    if (ciphertext.length != 16) {
      throw ArgumentError('Ciphertext must be exactly 16 bytes, got ${ciphertext.length}');
    }
    if (key.length != 16) {
      throw ArgumentError('Key must be exactly 16 bytes, got ${key.length}');
    }

    try {
      // 使用pointycastle原生AES实现，避免填充问题
      final cipher = AESEngine()..init(false, KeyParameter(key));
      final decrypted = Uint8List(16);
      cipher.processBlock(ciphertext, 0, decrypted, 0);
      return decrypted;
    } catch (e) {
      // 降级到encrypt包
      try {
        final encrypter = Encrypter(AES(Key(key), mode: AESMode.ecb, padding: null));
        final encrypted = Encrypted(ciphertext);
        final decryptedBytes = encrypter.decryptBytes(encrypted);
        return Uint8List.fromList(decryptedBytes);
      } catch (e2) {
        // 最后尝试默认填充
        try {
          final encrypter = Encrypter(AES(Key(key), mode: AESMode.ecb));
          final encrypted = Encrypted(ciphertext);
          final decryptedBytes = encrypter.decryptBytes(encrypted);
          return Uint8List.fromList(decryptedBytes);
        } catch (e3) {
          throw ArgumentError('AES解密失败: 原生实现=$e, 无填充=$e2, 默认填充=$e3');
        }
      }
    }
  }

  /// 生成16字节密钥
  ///
  /// [keyString] 密钥字符串
  /// 返回16字节的密钥数据
  static Uint8List createKey(String keyString) {
    if (keyString.length >= 16) {
      return Uint8List.fromList(keyString.codeUnits.take(16).toList());
    }

    // 如果密钥不足16字节，重复填充
    final List<int> keyBytes = [];
    while (keyBytes.length < 16) {
      for (int i = 0; i < keyString.length && keyBytes.length < 16; i++) {
        keyBytes.add(keyString.codeUnitAt(i));
      }
    }

    return Uint8List.fromList(keyBytes);
  }

  /// 从十六进制字符串创建密钥
  ///
  /// [hexString] 十六进制字符串（如："1234567890abcdef1234567890abcdef"）
  /// 返回16字节的密钥数据
  static Uint8List createKeyFromHex(String hexString) {
    // 移除可能的空格和短横线
    final cleanHex = hexString.replaceAll(RegExp(r'[\s-]'), '');

    if (cleanHex.length < 32) {
      throw ArgumentError('Hex string must be at least 32 characters for 16 bytes');
    }

    final keyBytes = <int>[];
    for (int i = 0; i < 32; i += 2) {
      final hexByte = cleanHex.substring(i, i + 2);
      keyBytes.add(int.parse(hexByte, radix: 16));
    }

    return Uint8List.fromList(keyBytes);
  }
}
