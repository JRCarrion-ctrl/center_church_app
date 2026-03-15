// file: lib/features/auth/web_auth_web.dart
import 'dart:async';
import 'dart:js_interop' as jweb;
import 'package:web/web.dart' as web;
import 'package:flutter/foundation.dart';

String get platformRedirectUri {
  if (kDebugMode) return 'http://localhost:8080/auth.html';
  return '${web.window.location.origin}/auth.html';
}

Future<String> webAuthenticate(String url) {
  final completer = Completer<String>();

  void complete(String resultUrl) {
    if (!completer.isCompleted) completer.complete(resultUrl);
  }

  late jweb.JSFunction messageHandler;
  late jweb.JSFunction channelHandler;

  messageHandler = ((web.MessageEvent event) {
    final data = event.data.dartify();
    if (data is String && data.contains('code=')) {
      complete(data);
      web.window.removeEventListener('message', messageHandler);
    }
  }).toJS;
  web.window.addEventListener('message', messageHandler);

  final channel = web.BroadcastChannel('flutter_web_auth_2');
  channelHandler = ((web.MessageEvent event) {
    final data = event.data.dartify();
    if (data is String && data.contains('code=')) {
      complete(data);
      channel.close();
      web.window.removeEventListener('message', messageHandler);
    }
  }).toJS;
  channel.addEventListener('message', channelHandler);

  const width = 520;
  const height = 680;
  final left = (web.window.screen.width - width) ~/ 2;
  final top = (web.window.screen.height - height) ~/ 2;
  
  web.window.open(
    url,
    'zitadel_auth',
    'width=$width,height=$height,left=$left,top=$top,toolbar=no,menubar=no,scrollbars=yes,resizable=yes',
  );

  return completer.future;
}