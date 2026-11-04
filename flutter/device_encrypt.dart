import 'dart:typed_data';

import 'package:dreame_threed/common/utils/log_utils.dart';

import 'base64url_codec.dart';
import 'crypto_utils.dart';

/// 设备加密结果
class EncryptionResult {
  /// 加密成功标志
  final bool success;

  /// 加密后的token（URL安全的Base64Url编码）
  final String? token;

  /// 错误信息
  final String? error;

  /// 错误代码
  final int? errorCode;

  const EncryptionResult.success(this.token)
      : success = true,
        error = null,
        errorCode = null;

  const EncryptionResult.failure(this.error, this.errorCode)
      : success = false,
        token = null;
}

/// 设备解密结果
class DecryptionResult {
  /// 解密成功标志
  final bool success;

  /// 设备ID（格式化后的，如：4EBB-E53F-8F67-263F）
  final String? deviceId;

  /// UTC时间戳
  final int? timestamp;

  /// 错误信息
  final String? error;

  /// 错误代码
  final int? errorCode;

  const DecryptionResult.success(this.deviceId, this.timestamp)
      : success = true,
        error = null,
        errorCode = null;

  const DecryptionResult.failure(this.error, this.errorCode)
      : success = false,
        deviceId = null,
        timestamp = null;
}

/// 内部使用的明文构建结果
class _PlaintextResult {
  /// 构建成功标志
  final bool success;

  /// 明文数据
  final Uint8List? data;

  /// 错误信息
  final String? error;

  /// 错误代码
  final int? errorCode;

  const _PlaintextResult.success(this.data)
      : success = true,
        error = null,
        errorCode = null;

  const _PlaintextResult.failure(this.error, this.errorCode)
      : success = false,
        data = null;
}

/// Flutter设备加密类
///
/// 提供设备ID的加密和解密功能，返回URL安全的Base64Url编码token
/// 与Python版本完全兼容，使用UTC标准时间
class DeviceEncrypt {
  /// 默认密钥（仅用于测试，生产环境请使用安全的密钥）
  static final Uint8List _defaultKey = CryptoUtils.createKey('1234567890abcdef');

  /// 设备ID加密（使用当前UTC时间）
  ///
  /// [deviceId] 设备ID（16字符十六进制，可含短横线，如"4EBB-E53F-8F67-263F"）
  /// [key] 可选的16字节AES密钥，不提供则使用默认密钥
  ///
  /// 返回[EncryptionResult]，包含加密结果或错误信息
  ///
  /// 特性：
  /// - 使用UTC标准时间，避免时区问题
  /// - 返回URL安全的Base64Url编码（约22字符）
  /// - 支持带短横线和不带短横线的设备ID格式
  static EncryptionResult encryptDevice(String deviceId, {Uint8List? key}) {
    return encryptDeviceWithTime(deviceId, DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000, key: key);
  }

  /// 设备ID加密（使用指定时间戳）
  ///
  /// [deviceId] 设备ID（16字符十六进制，可含短横线）
  /// [timestamp] Unix时间戳（UTC）
  /// [key] 可选的16字节AES密钥，不提供则使用默认密钥
  ///
  /// 返回[EncryptionResult]，包含加密结果或错误信息
  static EncryptionResult encryptDeviceWithTime(String deviceId, int timestamp, {Uint8List? key}) {
    try {
      key ??= _defaultKey;

      // 验证密钥长度
      if (key.length != 16) {
        return const EncryptionResult.failure('密钥必须是16字节长度', -1);
      }

      // 构建明文
      final plaintextResult = _buildPlaintext(deviceId, timestamp);
      if (!plaintextResult.success) {
        return EncryptionResult.failure(plaintextResult.error!, plaintextResult.errorCode!);
      }

      // AES加密
      final ciphertext = CryptoUtils.aesEcbEncrypt(plaintextResult.data!, key);

      // Base64Url编码（URL安全）
      final token = Base64UrlCodec.encode(ciphertext);

      return EncryptionResult.success(token);
    } catch (e) {
      return EncryptionResult.failure('加密过程发生错误: $e', -5);
    }
  }

  /// 设备token解密
  ///
  /// [token] 加密的token（Base64Url编码）
  /// [key] 可选的16字节AES密钥，不提供则使用默认密钥
  ///
  /// 返回[DecryptionResult]，包含解密结果或错误信息
  static DecryptionResult decryptDevice(String token, {Uint8List? key}) {
    try {
      key ??= _defaultKey;

      // 验证密钥长度
      if (key.length != 16) {
        return const DecryptionResult.failure('密钥必须是16字节长度', -1);
      }
      logD(tag: "scanner", "长度成功");

      // 验证Base64Url格式
      if (!Base64UrlCodec.isValidBase64Url(token)) {
        return const DecryptionResult.failure('无效的Base64Url token格式', -2);
      }
      logD(tag: "scanner", "Base64Url token格式成功");

      // Base64Url解码
      final ciphertext = Base64UrlCodec.decode(token);
      if (ciphertext.length != 16) {
        return const DecryptionResult.failure('解码后的密文必须是16字节长度', -3);
      }
      logD(tag: "scanner", "解码后的密文 成功 $ciphertext");

      // AES解密
      final plaintext = CryptoUtils.aesEcbDecrypt(ciphertext, key);
      logD(tag: "scanner", " CryptoUtils.aesEcbDecrypt 成功 $plaintext");

      // 解析明文
      return _parsePlaintext(plaintext);
    } catch (e) {
      return DecryptionResult.failure('解密过程发生错误: $e', -5);
    }
  }

  /// 构建16字节明文（设备ID + 时间戳）
  static _PlaintextResult _buildPlaintext(String deviceId, int timestamp) {
    try {
      // 清理设备ID（移除短横线并转换为大写）
      final cleanDeviceId = deviceId.replaceAll('-', '').toUpperCase();

      // 验证设备ID格式
      if (cleanDeviceId.length != 16) {
        return const _PlaintextResult.failure('设备ID必须是16字符的十六进制字符串', -2);
      }

      final validChars = RegExp(r'^[0-9A-F]+$');
      if (!validChars.hasMatch(cleanDeviceId)) {
        return const _PlaintextResult.failure('设备ID包含无效字符', -1);
      }

      // 转换设备ID为8字节
      final deviceBytes = Uint8List(8);
      for (int i = 0; i < 8; i++) {
        final hexByte = cleanDeviceId.substring(i * 2, i * 2 + 2);
        deviceBytes[i] = int.parse(hexByte, radix: 16);
      }

      // 计算相对时间戳（基于当前年份UTC）
      final baseTimestamp = _getYearBaseTimestampUtc();
      final relativeTimestamp = timestamp >= baseTimestamp ? timestamp - baseTimestamp : 0;

      // 构建16字节明文：[8字节设备ID][4字节零][4字节相对时间戳]
      final plaintext = Uint8List(16);
      plaintext.setRange(0, 8, deviceBytes); // 设备ID
      plaintext.setRange(8, 12, [0, 0, 0, 0]); // 中间4字节置零

      // 相对时间戳（大端序）
      plaintext[12] = (relativeTimestamp >> 24) & 0xFF;
      plaintext[13] = (relativeTimestamp >> 16) & 0xFF;
      plaintext[14] = (relativeTimestamp >> 8) & 0xFF;
      plaintext[15] = relativeTimestamp & 0xFF;

      return _PlaintextResult.success(plaintext);
    } catch (e) {
      return _PlaintextResult.failure('构建明文失败: $e', -3);
    }
  }

  /// 解析16字节明文
  static DecryptionResult _parsePlaintext(Uint8List plaintext) {
    try {
      if (plaintext.length != 16) {
        return const DecryptionResult.failure('明文长度必须是16字节', -4);
      }

      // 提取设备ID（前8字节）
      final deviceBytes = plaintext.sublist(0, 8);
      final deviceHex = deviceBytes.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join();
      final formattedDeviceId =
          '${deviceHex.substring(0, 4)}-${deviceHex.substring(4, 8)}-${deviceHex.substring(8, 12)}-${deviceHex.substring(12, 16)}';

      // 提取时间戳（后8字节）
      final timeBytes = plaintext.sublist(8, 16);

      // 检查是否使用了相对时间戳（中间4字节为0）
      final baseTimestamp = _getYearBaseTimestampUtc();
      int timestamp;

      if (timeBytes[0] == 0 && timeBytes[1] == 0 && timeBytes[2] == 0 && timeBytes[3] == 0) {
        // 使用相对时间戳
        final relativeTimestamp = (timeBytes[4] << 24) | (timeBytes[5] << 16) | (timeBytes[6] << 8) | timeBytes[7];
        timestamp = baseTimestamp + relativeTimestamp;
      } else {
        // 使用绝对时间戳（8字节）
        timestamp = 0;
        for (int i = 0; i < 8; i++) {
          timestamp = (timestamp << 8) | timeBytes[i];
        }
      }

      return DecryptionResult.success(formattedDeviceId, timestamp);
    } catch (e) {
      return DecryptionResult.failure('解析明文失败: $e', -4);
    }
  }

  /// 获取2024年份的UTC基准时间戳（1月1日 00:00:00）
  static int _getYearBaseTimestampUtc() {
    final yearStart = DateTime.utc(2024, 1, 1, 0, 0, 0, 0, 0);
    return yearStart.millisecondsSinceEpoch ~/ 1000;
  }

  /// 创建完整的GET请求URL（可选功能）
  ///
  /// [baseUrl] 基础URL
  /// [deviceId] 设备ID
  /// [paramName] 参数名称（默认'token'）
  /// [key] 可选的加密密钥
  ///
  /// 返回完整的URL字符串，如果加密失败则返回null
  static String? createUrl(String baseUrl, String deviceId, {String paramName = 'token', Uint8List? key}) {
    final result = encryptDevice(deviceId, key: key);
    if (!result.success) {
      return null;
    }

    final separator = baseUrl.contains('?') ? '&' : '?';
    return '$baseUrl$separator$paramName=${result.token}';
  }
}
