import 'package:web/web.dart' as html;

void autoRedirect() {
  if (html.window.navigator.userAgent.contains('iPhone')) {
    final currentUrl = html.window.location.href;
    final appUrl = currentUrl.replaceFirst('https://', 'ccfapp://');
    html.window.location.assign(appUrl);
  }
}