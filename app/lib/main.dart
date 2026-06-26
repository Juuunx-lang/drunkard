import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'web_splash_stub.dart'
    if (dart.library.js_interop) 'web_splash_web.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    Future<void>.delayed(const Duration(milliseconds: 900), hideWebSplash);
  });
  runApp(const ProviderScope(child: DrunkardApp()));
}
