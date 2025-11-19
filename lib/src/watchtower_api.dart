// Dart imports:
import 'dart:async';

// Flutter imports:
import 'package:flutter/services.dart';

class WatchtowerScreenRecordingApi {
  static const MethodChannel _methodChannel = MethodChannel(
    'com.watchtower.plugin/screen_recording',
  );
  static const EventChannel _eventChannel = EventChannel(
    'com.watchtower.plugin/screen_recording_stream',
  );

  Future<void> startRecorder(int interval) async {
    try {
      await _methodChannel.invokeMethod('startRecorder', {
        'interval': interval,
      });
    } on PlatformException catch (e) {
      throw Exception('Failed to start recorder: ${e.message}');
    }
  }

  Stream<Uint8List> get screenshotStream {
    return _eventChannel.receiveBroadcastStream().map((dynamic event) {
      if (event is Uint8List) {
        return event;
      }
      throw Exception('Invalid frame data type');
    });
  }
}
