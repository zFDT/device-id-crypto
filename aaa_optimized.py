'''
Date: 2025-08-18 11:58:02
LastEditors: zhanghongxin2 zhanghongxin2@dreame.tech
LastEditTime: 2025-08-18 19:05:43
FilePath: \test2\aaa_optimized.py
优化后的设备加密工具 - 移除冗余代码，合并重复功能
'''
from Crypto.Cipher import AES
import struct
import base64
import urllib.parse
from datetime import datetime, timezone
from typing import Tuple, Optional, Literal

# 默认配置
DEFAULT_KEY = b'1234567890abcdef'
ENCODING_TYPES = Literal['base64url']

def _get_time_bytes(timestamp: int) -> bytes:
    """优化的时间戳处理 - 针对2024年后的时间戳优化"""
    # 使用2024年UTC时间作为基准年份（与Dart保持一致）
    base_timestamp = int(datetime(2024, 1, 1, 0, 0, 0, tzinfo=timezone.utc).timestamp())
    relative_timestamp = timestamp - base_timestamp
    print(f"处理后时间搓 {relative_timestamp}")
    # 对于2024年后的时间戳，相对时间戳应该总是正数且在合理范围内
    if relative_timestamp >= 0 and relative_timestamp < (1 << 32):
        # 使用4字节相对编码（前4字节为0标识）
        time_bytes = struct.pack(">I", relative_timestamp)
        return b'\x00' * 4 + time_bytes
    else:
        # 异常情况使用8字节绝对编码
        return struct.pack(">Q", timestamp)

def _parse_time_bytes(time_bytes: bytes) -> int:
    """解析时间戳字节 - 针对2024年后的时间戳优化"""
    if time_bytes[:4] == b'\x00' * 4:
        # 4字节相对编码：前4字节为0，后4字节为相对时间戳
        base_timestamp = int(datetime(2024, 1, 1, 0, 0, 0, tzinfo=timezone.utc).timestamp())
        relative_timestamp = struct.unpack(">I", time_bytes[4:])[0]
        return base_timestamp + relative_timestamp
    else:
        # 8字节绝对编码：直接存储完整时间戳
        return struct.unpack(">Q", time_bytes)[0]

def _validate_device_id(device_cn: str) -> str:
    """验证并清理设备ID"""
    clean_device = device_cn.replace("-", "").upper()
    
    if len(clean_device) != 16 or not all(c in "0123456789ABCDEF" for c in clean_device):
        raise ValueError("device_cn 必须是16字符的十六进制字符串")
    
    return clean_device

def _encode_result(ciphertext: bytes, encoding: ENCODING_TYPES) -> str:
    """根据编码方式返回结果"""
    if encoding == 'base64url':
        encoded = base64.b64encode(ciphertext).decode('ascii')
        encoded = encoded.replace('+', '-').replace('/', '_').rstrip('=')
        return encoded
    else:
        raise ValueError(f"不支持的编码方式: {encoding}")

def _decode_input(ciphertext: str, encoding: ENCODING_TYPES) -> bytes:
    """根据编码方式解码输入"""
    # URL解码（处理可能的URL编码）
    ciphertext = urllib.parse.unquote(ciphertext)
    
    try:
        if encoding == 'base64url':
            # 转换URL安全字符并补充填充
            ciphertext = ciphertext.replace('-', '+').replace('_', '/')
            missing_padding = len(ciphertext) % 4
            if missing_padding:
                ciphertext += '=' * (4 - missing_padding)
            return base64.b64decode(ciphertext)
        else:
            raise ValueError(f"不支持的编码方式: {encoding}")
    except Exception as e:
        raise ValueError(f"解码失败: {e}")

def encrypt_device(device_cn: str, timestamp: Optional[int] = None, 
                  key: Optional[bytes] = None, encoding: ENCODING_TYPES = 'base64url') -> str:
    """
    通用设备加密函数（合并了所有加密功能）
    
    参数:
        device_cn: 设备标识
        timestamp: 时间戳，如果为None则使用当前UTC时间戳
        key: 加密密钥，如果为None则使用默认密钥
        encoding: 编码方式
        
    返回:
        编码后的加密字符串
    """
    # 设置默认值 - 使用与Dart完全一致的UTC时间戳获取方式
    if timestamp is None:
        # 等效于Dart: DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000
        utc_now = datetime.now(timezone.utc)
        timestamp = int(utc_now.timestamp() * 1000) // 1000
    if key is None:
        key = DEFAULT_KEY
    
    if len(key) != 16:
        raise ValueError("密钥必须是16字节长度")
    
    # 验证和清理设备ID
    clean_device = _validate_device_id(device_cn)
    device_bytes = bytes.fromhex(clean_device)
    
    # 处理时间戳
    time_bytes = _get_time_bytes(timestamp)
    
    # 组合成16字节明文
    plaintext = device_bytes + time_bytes
    
    # AES-128-ECB加密
    cipher = AES.new(key, AES.MODE_ECB)
    ciphertext = cipher.encrypt(plaintext)
    
    # 编码结果
    return _encode_result(ciphertext, encoding)

def decrypt_device(ciphertext: str, key: Optional[bytes] = None, 
                  encoding: ENCODING_TYPES = 'base64url') -> Tuple[str, int]:
    """
    通用设备解密函数（合并了所有解密功能）
    
    参数:
        ciphertext: 编码后的加密字符串
        key: 解密密钥
        encoding: 编码方式
        
    返回:
        (device_cn, timestamp) 元组
    """
    if key is None:
        key = DEFAULT_KEY
    
    if len(key) != 16:
        raise ValueError("密钥必须是16字节长度")
    
    # 解码输入
    cipher_bytes = _decode_input(ciphertext, encoding)
    
    if len(cipher_bytes) != 16:
        raise ValueError("解码后的密文必须是16字节长度")
    
    # AES-128-ECB解密
    cipher = AES.new(key, AES.MODE_ECB)
    plaintext = cipher.decrypt(cipher_bytes)
    
    # 分割设备ID和时间戳
    device_bytes = plaintext[:8]
    time_bytes = plaintext[8:]
    
    # 转换设备ID为带短横线的格式
    device_hex = device_bytes.hex().upper()
    formatted_device = f"{device_hex[:4]}-{device_hex[4:8]}-{device_hex[8:12]}-{device_hex[12:16]}"
    
    # 解析时间戳
    timestamp = _parse_time_bytes(time_bytes)
    
    return formatted_device, timestamp

def create_url_with_token(base_url: str, device_cn: str, timestamp: Optional[int] = None, 
                         key: Optional[bytes] = None, param_name: str = 'token',
                         encoding: ENCODING_TYPES = 'base64url') -> str:
    """
    创建包含加密参数的GET请求URL
    
    参数:
        base_url: 基础URL
        device_cn: 设备标识
        timestamp: 时间戳（可选，默认当前时间）
        key: 加密密钥（可选）
        param_name: 参数名称（默认'token'）
        encoding: 编码方式
        
    返回:
        完整的GET请求URL
    """
    encrypted_token = encrypt_device(device_cn, timestamp, key, encoding)
    
    # 构建URL
    separator = '&' if '?' in base_url else '?'
    return f"{base_url}{separator}{param_name}={encrypted_token}"

# 兼容性函数（保留原始接口）
def fixed_length_encrypt(device_cn: str, timestamp: int, key: bytes) -> str:
    """兼容原始版本，返回base64url编码字符串"""
    return encrypt_device(device_cn, timestamp, key, 'base64url')

def fixed_length_decrypt(ciphertext: str, key: bytes) -> Tuple[str, int]:
    """兼容原始版本，解析base64url编码字符串"""
    return decrypt_device(ciphertext, key, 'base64url')

def encrypt_for_get_request(device_cn: str, timestamp: Optional[int] = None, 
                           key: Optional[bytes] = None, encoding: ENCODING_TYPES = 'base64url') -> str:
    """兼容GET请求函数"""
    return encrypt_device(device_cn, timestamp, key, encoding)

def decrypt_from_get_request(ciphertext: str, key: Optional[bytes] = None, 
                            encoding: ENCODING_TYPES = 'base64url') -> Tuple[str, int]:
    """兼容GET请求函数"""
    return decrypt_device(ciphertext, key, encoding)

# 使用示例
if __name__ == "__main__":
    # 测试数据
    test_devices = [
        "4EBB-E53F-8F67-263F",
        "1234-5678-9ABC-DEF0",
        "FFFF-EEEE-DDDD-CCCC"
    ]
    test_timestamp = int(datetime.now(timezone.utc).timestamp() * 1000)  // 1000 # 等效于Dart方式
    secret_key = DEFAULT_KEY

    print("设备加密工具优化版本")
    print(f"使用UTC时间戳: {test_timestamp}")
    print(f"对应时间: {datetime.fromtimestamp(test_timestamp, timezone.utc)}")
    print()
    
    for test_device in test_devices:
        print(f"测试设备: {test_device}")
        print(f"时间戳: {test_timestamp}")
        # 测试base64url编码
        try:
            # 加密
            encrypted = encrypt_device(test_device, test_timestamp, secret_key, 'base64url')
            print(f"BASE64URL: {encrypted} (长度: {len(encrypted)})")
            
            # 验证解密
            dec_device, dec_timestamp = decrypt_device(encrypted, secret_key, 'base64url')
            is_valid = (dec_device == test_device and dec_timestamp == test_timestamp)
            print(f"  验证: {'✓' if is_valid else '✗'}")
            
        except Exception as e:
            print(f"BASE64URL: 错误 - {e}")
        
        print()
        
        # 测试URL生成
        base_url = "https://api.example.com/device"
        full_url = create_url_with_token(base_url, test_device)
        print(f"完整URL: {full_url}")
        print("=" * 50)
        print()
    
