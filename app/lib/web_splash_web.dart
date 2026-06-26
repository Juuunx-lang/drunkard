import 'dart:js_interop';

@JS('hideDrunkardSplash')
external void _hideDrunkardSplash();

void hideWebSplash() {
  _hideDrunkardSplash();
}
