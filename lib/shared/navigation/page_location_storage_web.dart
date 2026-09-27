import 'package:web/web.dart' as web;

String? readLocation(String key) {
  try {
    return web.window.sessionStorage.getItem(key);
  } catch (_) {
    return null;
  }
}

void writeLocation(String key, String value) {
  try {
    web.window.sessionStorage.setItem(key, value);
  } catch (_) {
    /* Private browsing may block storage. */
  }
}

void clearLocation(String key) {
  try {
    web.window.sessionStorage.removeItem(key);
  } catch (_) {
    /* Storage is optional. */
  }
}
