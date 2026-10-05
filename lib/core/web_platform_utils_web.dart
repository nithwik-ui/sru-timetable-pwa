// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class WebPlatformUtils {
  static bool get isStandalonePwa {
    return html.window.matchMedia('(display-mode: standalone)').matches ||
        (html.window.navigator as dynamic).standalone == true;
  }

  static bool get isAppleMobileWeb {
    final userAgent = html.window.navigator.userAgent.toLowerCase();
    final isIOS = userAgent.contains('iphone') || userAgent.contains('ipad') || userAgent.contains('ipod');
    final isMacTouch = html.window.navigator.platform?.toLowerCase().contains('mac') == true &&
        html.window.navigator.maxTouchPoints != null &&
        html.window.navigator.maxTouchPoints! > 1;
    return isIOS || isMacTouch;
  }

  static bool get isDesktopWeb {
    final userAgent = html.window.navigator.userAgent.toLowerCase();
    final isAndroid = userAgent.contains('android');
    return !isAppleMobileWeb && !isAndroid;
  }
}
