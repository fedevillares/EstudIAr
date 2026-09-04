import 'dart:async';
import 'dart:io';

class ConnectivityService {
  ConnectivityService._();

  static Stream<bool> onlineStatusStream() async* {
    yield await isOnline();
    while (true) {
      await Future.delayed(const Duration(seconds: 5));
      yield await isOnline();
    }
  }

  static Future<bool> isOnline() async {
    return _hasRealInternet();
  }

  static Future<bool> _hasRealInternet() async {
    try {
      final result = await InternetAddress.lookup('one.one.one.one')
          .timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}