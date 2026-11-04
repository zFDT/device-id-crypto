/*
 * @Date: 2025-08-18 19:11:26
 * @LastEditors: zhanghongxin2 zhanghongxin2@dreame.tech
 * @LastEditTime: 2025-08-18 19:11:26
 * @FilePath: \test2\flutter\base64url_codec.dart
 */
///  @Author: zhanghongxin2
///  @Date: 2025-01-18
///  @Description: Base64编码解码器，支持标准Base64和Base64Url格式，与Python版本兼容
import 'dart:convert';
import 'dart:typed_data';

/// Base64编码解码器
/// 支持标准Base64和Base64Url两种格式，与Python版本完全兼容
class Base64UrlCodec {
  /// 将字节数据编码为URL安全的Base64字符串
  ///
  /// [data] 要编码的字节数据
  /// 返回URL安全的Base64编码字符串（替换+为-，/为_，移除填充=）
  static String encode(Uint8List data) {
    if (data.isEmpty) {
      return '';
    }

    // 标准Base64编码
    String encoded = base64.encode(data);

    // 转换为URL安全格式：+ -> -, / -> _, 移除填充=
    encoded = encoded.replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '');

    return encoded;
  }

  /// 将Base64字符串解码为字节数据（自动检测格式）
  ///
  /// [encoded] Base64编码字符串（支持标准Base64和Base64Url格式）
  /// 返回解码后的字节数据
  /// 抛出[ArgumentError] 如果解码失败
  static Uint8List decode(String encoded) {
    if (encoded.isEmpty) {
      return Uint8List(0);
    }

    try {
      // 检测编码类型
      final isBase64Url = encoded.contains('-') || encoded.contains('_');

      String standardBase64;
      if (isBase64Url) {
        // Base64Url -> 标准Base64：- -> +, _ -> /
        standardBase64 = encoded.replaceAll('-', '+').replaceAll('_', '/');
      } else {
        // 已经是标准Base64格式
        standardBase64 = encoded;
      }

      // 补充填充字符
      final missingPadding = standardBase64.length % 4;
      if (missingPadding != 0) {
        standardBase64 += '=' * (4 - missingPadding);
      }

      // 标准Base64解码
      final decoded = base64.decode(standardBase64);
      return Uint8List.fromList(decoded);
    } catch (e) {
      throw ArgumentError('Base64解码失败: $e');
    }
  }

  /// 验证字符串是否为有效的Base64编码（支持两种格式）
  ///
  /// [encoded] 要验证的字符串
  /// 返回true如果字符串是有效的Base64格式
  static bool isValidBase64Url(String encoded) {
    if (encoded.isEmpty) {
      return true;
    }

    // 检测是否为Base64Url格式
    final isBase64Url = encoded.contains('-') || encoded.contains('_');

    if (isBase64Url) {
      // Base64Url只包含：A-Z, a-z, 0-9, -, _
      final validPattern = RegExp(r'^[A-Za-z0-9\-_]*$');
      if (!validPattern.hasMatch(encoded)) {
        return false;
      }
    } else {
      // 标准Base64只包含：A-Z, a-z, 0-9, +, /
      final validPattern = RegExp(r'^[A-Za-z0-9+/]*$');
      if (!validPattern.hasMatch(encoded)) {
        return false;
      }
    }

    // 尝试解码验证
    try {
      decode(encoded);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 检测编码类型
  ///
  /// [encoded] Base64编码字符串
  /// 返回编码类型描述
  static String detectEncodingType(String encoded) {
    if (encoded.contains('-') || encoded.contains('_')) {
      return 'Base64Url';
    } else {
      return 'Standard Base64';
    }
  }
}
