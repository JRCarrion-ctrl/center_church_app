// file: lib/features/auth/web_auth_web.dart
import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart';

/// Opens [url] as a popup and waits for auth.html to send back the redirect URL.
Future<String> webAuthenticate(String url) {
  final completer = Completer<String>();

  void complete(String resultUrl) {
    if (!completer.isCompleted) completer.complete(resultUrl);
  }

  // Need to hold JSFunction references so we can remove them later
  late JSFunction messageHandler;
  late JSFunction channelHandler;

  // Listener 1: popup → auth.html calls window.opener.postMessage()
  messageHandler = ((MessageEvent event) {
    final data = event.data.dartify();
    if (data is String && data.contains('code=')) {
      complete(data);
      window.removeEventListener('message', messageHandler);
    }
  }).toJS;
  window.addEventListener('message', messageHandler);

  // Listener 2: new-tab fallback → auth.html uses BroadcastChannel
  final channel = BroadcastChannel('flutter_web_auth_2');
  channelHandler = ((MessageEvent event) {
    final data = event.data.dartify();
    if (data is String && data.contains('code=')) {
      complete(data);
      channel.close();
      window.removeEventListener('message', messageHandler);
    }
  }).toJS;
  channel.addEventListener('message', channelHandler);

  // Open as a centered popup
  const width  = 520;
  const height = 680;
  final left = (window.screen.width  - width)  ~/ 2;
  final top  = (window.screen.height - height) ~/ 2;
  window.open(
    url,
    'zitadel_auth',
    'width=$width,height=$height,left=$left,top=$top,'
    'toolbar=no,menubar=no,scrollbars=yes,resizable=yes',
  );

  return completer.future;
}