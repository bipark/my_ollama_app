import 'dart:io';
import 'package:flutter/widgets.dart';

bool isDesktopOrTablet() {
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    return true;
  }
  
  // Check if running on iPad
  if (Platform.isIOS) {
    final window = WidgetsBinding.instance.window;
    final size = window.physicalSize;
    final pixelRatio = window.devicePixelRatio;
    final width = size.width / pixelRatio;
    
    // iPad typically has a width greater than 768 points
    return width >= 768;
  }
  
  return false;
}
