import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Hands control back to the app that was foreground before Trun On opened.
final class ExternalAppNavigationService {
  const ExternalAppNavigationService();

  static const _channel = MethodChannel(
    'com.orialthq.ori_beauty/app_navigation/v1',
  );

  /// Returns whether Android accepted the request.
  ///
  /// When Trun On was added on top of the sharing app's task, Android finishes
  /// this activity. Otherwise it moves Trun On's task to the background.
  Future<bool> returnToPreviousApp() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    try {
      return await _channel.invokeMethod<bool>('returnToPreviousApp') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
