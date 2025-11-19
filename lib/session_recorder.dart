// Dart imports:
import 'dart:async';
import 'dart:typed_data';

// Flutter imports:
import 'package:flutter/foundation.dart';
import 'package:watchtower_sdk/src/watchtower_api.dart';

// Project imports:
import 'package:watchtower_sdk/watchtower_logger.dart';

var logger = getLogger("session_recorder");

class SessionRecorder {
  static final SessionRecorder _instance = SessionRecorder._internal();
  SessionRecorder._internal();
  factory SessionRecorder() {
    return _instance;
  }

  late final double pixelRatio;
  late final int interval;
  late final String sessionId;

  static StreamController<Uint8List?> screenshotStreamController =
      StreamController<Uint8List?>.broadcast();
  static final StreamController<Uint8List?>
  screenshotLocalStoreStreamController =
      StreamController<Uint8List?>.broadcast();

  static bool isSendToWatchtowerEnabled = true;

  StreamSubscription<Uint8List>? _screenRecordingSubscription;

  void init({
    required String sessionId,
    double pixelRatio = 1.0,
    int interval = 300,
  }) {
    _instance.pixelRatio = pixelRatio;
    _instance.interval = interval;
    _instance.sessionId = sessionId;
    startScreenRecording(interval: interval);
  }

  Future<void> startScreenRecording({required int interval}) async {
    final screenRecorderApi = WatchtowerScreenRecordingApi();

    _screenRecordingSubscription = screenRecorderApi.screenshotStream.listen(
      (Uint8List frame) {
        _handleScreenshot(frame);
      },
      onError: (error) {
        logger.e("Error receiving screenshot: $error");
      },
    );

    await screenRecorderApi.startRecorder(interval);
  }

  void _handleScreenshot(Uint8List frame) {
    // print(frame.length);
    if (isSendToWatchtowerEnabled) {
      if (!screenshotStreamController.isClosed) {
        screenshotStreamController.add(frame);
      }
    } else {
      if (!screenshotLocalStoreStreamController.isClosed) {
        screenshotLocalStoreStreamController.add(frame);
      }
    }
  }

  void dispose() {
    _screenRecordingSubscription?.cancel();
    _screenRecordingSubscription = null;
  }
}
