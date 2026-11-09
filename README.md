# 设备加密工具 - 跨平台实现

## 项目概述

本项目提供了设备ID加密/解密的完整解决方案，包含Python参考实现、C语言实现和Flutter/Dart实现。所有版本完全兼容，支持AES-128-ECB加密、Base64URL编码、相对时间戳处理等功能。

## 文件结构

```text
├── aaa_optimized.py                  # Python参考实现
├── device_encrypt_optimized.h        # C语言头文件
├── device_encrypt_optimized.c        # C语言实现文件
├── flutter/                          # Flutter/Dart实现
│   ├── device_encrypt.dart           # 主要加密解密类
│   ├── crypto_utils.dart             # AES加密工具
│   ├── base64url_codec.dart          # Base64URL编码解码
│   └── scan_controller.dart          # 二维码扫描控制器
└── README.md                         # 本文档
```

## 核心功能

### 1. 设备ID加密
- 支持16字符十六进制设备ID（可带短横线）
- 使用AES-128-ECB加密算法
- 采用2024年基准的相对时间戳优化
- 输出URL安全的Base64编码

### 2. 二维码扫描解密
- 自动识别原始设备ID和加密Token
- 支持时间戳验证和过期检测
- 错误处理和用户友好提示

## Flutter 二维码扫描实现

### 扫描处理逻辑

[`onCodeScanned`](flutter/scan_controller.dart) 方法是Flutter中处理二维码扫描结果的核心函数：

```dart
void onCodeScanned(String code) {
  if (code.isEmpty) {
    Get.snackbar('扫描结果', '未检测到二维码内容，请重试');
    return;
  } else if (code.length == 19 && code.contains("-")) {
    // 原始格式：4EBB-E53F-8F67-263F (兼容模式)
    Get.offNamed(DeviceRoutes.scanBindDevice, arguments: {"deviceCn": code});
  } else {
    // 加密格式：Base64URL编码的token
    DecryptionResult result = DeviceEncrypt.decryptDevice(code);
    if (!result.success) {
      logD(tag: "scanner", "解密失败: ${result.error}, 错误代码: ${result.errorCode}");
      Get.back();
      Get.snackbar('扫描结果', '二维码错误或已过期，请重新获取');
      return;
    } else {
      logD(tag: "scanner", "解密成功: 设备ID=${result.deviceId}, 时间戳=${result.timestamp}");
      final currentTime = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final difference = currentTime - (result.timestamp ?? 0);
      // 如果差值大于300秒（5分钟），认为二维码已过期
      if (difference > 300 || difference < 0) {
        logD(tag: "scanner", "二维码已过期，差值为：$difference秒");
        Get.back();
        Get.snackbar('扫描结果', '二维码错误或已过期，请重新获取');
        return;
      } else {
        Get.offNamed(DeviceRoutes.scanBindDevice, arguments: {"deviceCn": result.deviceId});
      }
    }
  }
}
```

### 处理流程说明

1. **输入验证**：检查扫描内容是否为空
2. **格式识别**：
   - 长度19且包含短横线 → 原始设备ID格式（兼容模式）
   - 其他格式 → 加密Token格式
3. **解密处理**：
   - 调用 [`DeviceEncrypt.decryptDevice`](flutter/device_encrypt.dart) 解密
   - 验证解密结果的成功状态
4. **时效性验证**：
   - 获取当前UTC时间戳
   - 计算与Token中时间戳的差值
   - 超过300秒则视为过期
5. **结果处理**：
   - 成功：跳转到设备绑定页面
   - 失败：显示错误提示并返回

### 关键特性

- **双格式兼容**：同时支持原始设备ID和加密Token
- **时效性控制**：自动检测二维码是否过期（5分钟有效期）
- **错误处理**：详细的日志记录和用户友好的错误提示
- **UTC时间标准**：使用UTC时间避免时区问题

## 编译和链接要求

### C语言实现依赖

本项目的C语言实现依赖以下库：

1. **OpenSSL库** - 用于AES加密和Base64编码
   - libcrypto (OpenSSL的加密库)
   - 需要OpenSSL 1.1.0或更高版本

### Flutter实现依赖

Flutter实现依赖以下包：

```yaml
dependencies:
  encrypt: ^5.0.1           # AES加密
  pointycastle: ^3.7.3      # 原生加密算法
  mobile_scanner: ^3.5.6    # 二维码扫描
  permission_handler: ^11.0.1 # 权限管理
  get: ^4.6.6              # 状态管理
```

### Windows环境编译（C语言）

#### 方法1: 使用vcpkg (推荐)

1. **安装vcpkg**

   ```powershell
   git clone https://github.com/Microsoft/vcpkg.git
   cd vcpkg
   .\bootstrap-vcpkg.bat
   ```

2. **安装OpenSSL**

   ```powershell
   .\vcpkg install openssl:x64-windows
   ```

3. **编译项目**

   ```powershell
   # 使用Visual Studio编译器
   cl /I"vcpkg\installed\x64-windows\include" device_encrypt_optimized.c /link vcpkg\installed\x64-windows\lib\libcrypto.lib
   
   # 或者使用MinGW
   gcc -I"vcpkg\installed\x64-windows\include" -L"vcpkg\installed\x64-windows\lib" device_encrypt_optimized.c -lcrypto -o device_encrypt_optimized.exe
   ```

#### 方法2: 手动安装OpenSSL

1. **下载OpenSSL for Windows**
   - 从 [Shining Light Productions](https://slproweb.com/products/Win32OpenSSL.html) 下载
   - 或者从 [OpenSSL官网](https://www.openssl.org/source/) 编译

2. **设置环境变量**

   ```powershell
   # 假设OpenSSL安装在 C:\OpenSSL-Win64
   $env:OPENSSL_ROOT_DIR = "C:\OpenSSL-Win64"
   $env:PATH += ";C:\OpenSSL-Win64\bin"
   ```

3. **编译命令**

   ```powershell
   # 使用MSVC
   cl /I"C:\OpenSSL-Win64\include" device_encrypt_optimized.c /link "C:\OpenSSL-Win64\lib\libcrypto.lib"
   
   # 使用MinGW
   gcc -I"C:\OpenSSL-Win64\include" -L"C:\OpenSSL-Win64\lib" device_encrypt_optimized.c -lcrypto -o device_encrypt_optimized.exe
   ```

### Linux环境编译

#### Ubuntu/Debian

```bash
# 安装依赖
sudo apt-get update
sudo apt-get install libssl-dev

# 编译
gcc -o device_encrypt_optimized device_encrypt_optimized.c -lcrypto
```

#### CentOS/RHEL/Fedora

```bash
# CentOS/RHEL
sudo yum install openssl-devel
# 或者 Fedora
sudo dnf install openssl-devel

# 编译
gcc -o device_encrypt_optimized device_encrypt_optimized.c -lcrypto
```

### macOS环境编译

#### 使用Homebrew

```bash
# 安装OpenSSL
brew install openssl

# 编译 (注意macOS可能需要指定OpenSSL路径)
gcc -I$(brew --prefix openssl)/include -L$(brew --prefix openssl)/lib \
    -o device_encrypt_optimized device_encrypt_optimized.c -lcrypto
```

## 使用示例

### C语言示例

创建测试文件 `test_example.c`:

```c
#include "device_encrypt_optimized.h"
#include <stdio.h>
#include <time.h>
#include <string.h>

int main() {
    // 测试参数
    const char *device_id = "1234567890ABCDEF";
    uint32_t timestamp = (uint32_t)time(NULL);
    uint8_t key[16] = "1234567890abcdef";
    
    // 加密
    char token[256] = {0};
    int result = encrypt_device(device_id, timestamp, key, token, sizeof(token));
    if (result == ENCRYPT_SUCCESS) {
        printf("加密成功: %s\n", token);
        
        // 解密
        char decrypted_device[32] = {0};
        uint32_t decrypted_timestamp = 0;
        result = decrypt_device(token, key, decrypted_device, sizeof(decrypted_device), &decrypted_timestamp);
        
        if (result == ENCRYPT_SUCCESS) {
            printf("解密成功:\n");
            printf("  设备ID: %s\n", decrypted_device);
            printf("  时间戳: %u\n", decrypted_timestamp);
        } else {
            printf("解密失败: %d\n", result);
        }
    } else {
        printf("加密失败: %d\n", result);
    }
    
    return 0;
}
```

### Python示例

```python
from aaa_optimized import encrypt_device, decrypt_device
import time

# 测试参数
device_id = "4EBB-E53F-8F67-263F"
timestamp = int(time.time())
key = b'1234567890abcdef'

# 加密
token = encrypt_device(device_id, timestamp, key)
print(f"加密结果: {token}")

# 解密
decrypted_device, decrypted_timestamp = decrypt_device(token, key)
print(f"解密结果: {decrypted_device}, 时间戳: {decrypted_timestamp}")
```

### Flutter示例

```dart
import 'flutter/device_encrypt.dart';

// 加密示例
void encryptExample() {
  const deviceId = "4EBB-E53F-8F67-263F";
  final result = DeviceEncrypt.encryptDevice(deviceId);
  
  if (result.success) {
    print('加密成功: ${result.token}');
  } else {
    print('加密失败: ${result.error}');
  }
}

// 解密示例
void decryptExample(String token) {
  final result = DeviceEncrypt.decryptDevice(token);
  
  if (result.success) {
    print('解密成功: 设备ID=${result.deviceId}, 时间戳=${result.timestamp}');
  } else {
    print('解密失败: ${result.error}');
  }
}
```

## 二维码生成建议

### 推荐的二维码生成流程

1. **服务端生成**：
   ```python
   # 使用Python版本生成加密Token
   token = encrypt_device(device_id, current_timestamp, secret_key)
   # 生成二维码图片，内容为token
   ```

2. **有效期控制**：
   - 建议二维码有效期设置为5分钟（300秒）
   - 可根据实际需求调整 [`onCodeScanned`](flutter/scan_controller.dart) 中的过期时间判断

3. **安全考虑**：
   - 使用强随机的16字节密钥
   - 定期轮换加密密钥
   - 记录扫描日志用于安全审计

## 常见问题排查

### 1. C语言链接错误：找不到OpenSSL库

**错误信息：**

```text
undefined reference to `AES_set_encrypt_key'
undefined reference to `EVP_ENCODE_CTX_new'
```

**解决方法：**

- 确保安装了OpenSSL开发库
- 检查库路径是否正确
- 添加 `-lcrypto` 链接选项

### 2. Flutter解密失败

**常见原因：**

- Base64URL格式不正确
- 加密密钥不匹配
- 数据长度不符合要求

**排查步骤：**

1. 检查日志中的详细错误信息
2. 验证token格式是否为有效的Base64URL
3. 确认使用相同的密钥进行加密和解密

### 3. 二维码扫描无响应

**可能原因：**

- 相机权限未授予
- 二维码格式不正确
- 扫描器初始化失败

**解决方法：**

- 检查 [`checkCameraPermission`](flutter/scan_controller.dart) 权限状态
- 验证二维码内容格式
- 查看扫描器初始化日志

### 4. 时间戳验证失败

**常见问题：**

- 设备时间不准确
- 时区设置错误
- 网络延迟导致的时间差

**解决建议：**

- 使用NTP同步设备时间
- 统一使用UTC时间
- 适当调整过期时间容忍度

## 性能注意事项

1. **内存管理**: 所有函数都使用栈分配，避免了动态内存分配的开销
2. **线程安全**: OpenSSL的EVP接口在正确使用下是线程安全的
3. **Flutter性能优化**:
   - 使用原生AES实现避免填充问题
   - 缓存扫描控制器减少初始化开销
   - 异步处理解密操作避免UI阻塞

## 版本兼容性

本项目的所有实现版本完全兼容：

- **算法兼容**: 使用相同的AES-128-ECB加密算法
- **编码兼容**: 使用相同的Base64URL编码方式  
- **时间兼容**: 使用相同的2024年基准时间戳处理
- **数据兼容**: 生成的加密结果可以跨语言互相解密

## CMake支持

创建 `CMakeLists.txt` 文件：

```cmake
cmake_minimum_required(VERSION 3.10)
project(device_encrypt)

# 设置C标准
set(CMAKE_C_STANDARD 99)

# 查找OpenSSL
find_package(OpenSSL REQUIRED)

# 创建库
add_library(device_encrypt_optimized device_encrypt_optimized.c)
target_link_libraries(device_encrypt_optimized OpenSSL::Crypto)
target_include_directories(device_encrypt_optimized PUBLIC .)

# 创建测试程序
add_executable(test_example test_example.c)
target_link_libraries(test_example device_encrypt_optimized)
```

使用CMake编译：

```bash
mkdir build
cd build
cmake ..
cmake --build .
```

## 许可证

本项目采用MIT许可证，详见LICENSE文件。

## 技术特色与复盘

### 技术亮点

- **跨语言算法一致性**：同一套 AES-128-ECB + Base64URL + 相对时间戳方案，用 **Python / C / Dart（Flutter）三种语言**实现且结果完全互通——这是 IoT 场景「固件（C）+ 后端（Python）+ App（Dart）」跨端联调的核心能力。
- **安全设计**：二维码 token 带相对时间戳并做 5 分钟过期校验，防止重放；URL-safe Base64 保证二维码可直接扫描。
- **C 层性能优化**：栈分配避免动态内存、OpenSSL EVP 接口线程安全、Flutter 侧异步解密不阻塞 UI——兼顾正确性与工程细节。

### 个人贡献

- 独立设计并实现三端加解密方案，从协议定义（时间戳格式、编码方式）到三端落地、跨端一致性校验全部完成。

### 收获与规划

- **收获**：沉淀了「跨语言算法对齐」的方法论——先定 Python 参考实现 → C/Dart 对齐 → 用 crosscheck 脚本验证一致性，这套流程可复用到任何跨端加解密/协议场景。
- **规划**：可作为公司设备绑定链路的公开参考实现（已脱敏），继续补充 fuzz 测试与密钥轮换机制说明。
