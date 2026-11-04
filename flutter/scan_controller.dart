/*
 * @Date: 2025-08-18 19:10:57
 * @LastEditors: zhanghongxin2 zhanghongxin2@dreame.tech
 * @LastEditTime: 2025-08-18 19:11:16
 * @FilePath: \test2\flutter\scan_controller.dart
 */
import 'package:dreame_threed/common/utils/log_utils.dart';
import 'package:dreame_threed/routes/device_routes.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../common/utils/device_encrypt.dart';

class ScanPageViewController extends GetxController with GetSingleTickerProviderStateMixin {
  ScanPageViewController();

  bool hasPermission = false;
  RxBool isTorchOn = false.obs;
  MobileScannerController? scannerController;
  late AnimationController animationController;
  late Animation<double> animation;

  @override
  void onInit() {
    super.onInit();
    _initScanner();
    _checkInitialPermission();
    _initAnimation();
  }

  void _initAnimation() {
    animationController = AnimationController(
      duration: const Duration(milliseconds: 1500), // 动画持续时间
      vsync: this,
    )..repeat(reverse: true); // 重复动画，来回移动

    animation = Tween<double>(begin: -1.0, end: 1.0).animate(
      CurvedAnimation(parent: animationController, curve: Curves.easeInOut),
    );
  }

  void _initScanner() {
    scannerController = MobileScannerController();
  }

  // 检查相机权限
  Future<bool> checkCameraPermission() async {
    var status = await Permission.camera.status;
    if (status.isGranted) {
      return true;
    }

    if (status.isDenied) {
      status = await Permission.camera.request();
      return status.isGranted;
    }

    // 如果权限被永久拒绝，引导用户去设置中开启
    if (status.isPermanentlyDenied) {
      await showDialog(
        context: Get.context!,
        builder: (context) => AlertDialog(
          title: const Text('需要相机权限'),
          content: const Text('请在设置中允许访问相机以使用扫描功能'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                openAppSettings();
              },
              child: const Text('去设置'),
            ),
          ],
        ),
      );
      return false;
    }

    return false;
  }

  Future<void> _checkInitialPermission() async {
    final status = await Permission.camera.status;
    hasPermission = status.isGranted;
    update(['scanner']);
  }

  void updatePermission(bool permission) {
    hasPermission = permission;
    update(['scanner']);
  }

  void toggleTorch() {
    if (scannerController != null) {
      isTorchOn.value = !isTorchOn.value;
      scannerController!.toggleTorch();
      // update(['scanpageview']);
    }
  }

  void onCodeScanned(String code) {
    if (code.isEmpty) {
      Get.snackbar('扫描结果', '未检测到二维码内容，请重试');
      return;
    } else if (code.length == 19 && code.contains("-")) {
      // FIXME:临时保留原始方案
      // 处理扫描到的二维码数据
      Get.offNamed(DeviceRoutes.scanBindDevice, arguments: {"deviceCn": code});
    } else {
      // 处理加密后的二维码数据
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
        // 如果差值大于300秒，认为二维码已过期
        if (difference > 300 || difference < 0) {
          logD(tag: "scanner", "二维码已过期，差值为：$difference");
          Get.back();
          Get.snackbar('扫描结果', '二维码错误或已过期，请重新获取');
          return;
        } else {
          Get.offNamed(DeviceRoutes.scanBindDevice, arguments: {"deviceCn": result.deviceId});
        }
      }
    }
  }

  @override
  void onClose() {
    animationController.stop();
    animationController.dispose();
    scannerController?.dispose();
    super.onClose();
  }
}
