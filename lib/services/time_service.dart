import 'package:flutter/foundation.dart';
import 'package:ntp/ntp.dart';

class TimeService {
  static int _offset = 0;
  static bool _isSynced = false;

  /// Synchronizes local time with network time.
  /// Should be called at app startup.
  static Future<void> syncTime() async {
    try {
      DateTime networkTime = await NTP.now();
      _offset = networkTime.difference(DateTime.now()).inMilliseconds;
      _isSynced = true;
    } catch (e) {
      debugPrint("NTP Sync Error: $e");
      // Fallback to local time if sync fails
      _offset = 0;
      _isSynced = false;
    }
  }

  /// Returns the current synchronized DateTime.
  static DateTime get now {
    return DateTime.now().add(Duration(milliseconds: _offset));
  }

  static bool get isSynced => _isSynced;
}
