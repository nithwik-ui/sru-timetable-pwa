import 'dart:html' as html;
import 'package:flutter/foundation.dart';

bool isStandaloneWeb() {
  if (!kIsWeb) return false;
  
  // Apple specific standalone check
  final isIosStandalone = (html.window.navigator as dynamic).standalone == true;
  if (isIosStandalone) return true;
  
  // Standard PWA display mode check
  return html.window.matchMedia('(display-mode: standalone)').matches ||
         html.window.matchMedia('(display-mode: fullscreen)').matches ||
         html.window.matchMedia('(display-mode: minimal-ui)').matches;
}

bool isIosWeb() {
  if (!kIsWeb) return false;
  final userAgent = html.window.navigator.userAgent.toLowerCase();
  return userAgent.contains('iphone') || userAgent.contains('ipad') || userAgent.contains('ipod');
}
