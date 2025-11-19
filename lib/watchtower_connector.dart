import 'dart:async';

import 'package:async/async.dart';
import 'package:grpc/grpc.dart';
import 'package:grpc/service_api.dart' as grpc_services_api;

import 'package:watchtower_sdk/watchtower_logger.dart';
import 'package:watchtower_sdk/watchtower_proto/proto/server.pbgrpc.dart';

var logger = getLogger("watchtower_connector");

class WatchtowerConnector {
  final String host;
  final int port;
  final bool useTls;
  final int pingInetrval;
  final Function(bool state)? onConnectionStateChanged;

  bool isGrpcChannelReady = false;
  late WatchTowerApiClient stub;
  late RestartableTimer pingTimer;
  ClientChannel? _currentChannel;
  Timer? _reconnectTimer;
  bool _isReconnecting = false;
  StreamSubscription<ConnectionState>? _stateSubscription;

  WatchtowerConnector({
    this.host = '127.0.0.1',
    this.port = 8008,
    this.useTls = false,
    this.pingInetrval = 5,
    this.onConnectionStateChanged,
  });

  Future<void> createChannel() async {
    logger.d("Create watchtower connection");
    _reconnectTimer?.cancel();
    _isReconnecting = false;

    await _stateSubscription?.cancel();
    await _currentChannel?.shutdown();

    final channel = ClientChannel(
      host,
      port: port,
      options: ChannelOptions(
        credentials: useTls
            ? ChannelCredentials.secure(
                onBadCertificate: (certificate, host) {
                  logger.e("Certificate validation error");
                  logger.e("Certificate $certificate");
                  logger.e("Certificate $host");
                  return false;
                },
              )
            : const ChannelCredentials.insecure(),
        codecRegistry: CodecRegistry(
          codecs: const [GzipCodec(), IdentityCodec()],
        ),
      ),
    );

    _currentChannel = channel;
    _monitorChannelState(channel);
    channel.createConnection();
    stub = _createStub(channel);

    pingTimer = RestartableTimer(Duration(seconds: pingInetrval), () {
      try {
        stub.ping(PingRequest());
      } catch (e) {
        logger.w("Watchtower ping error: $e");
      }
    });
    pingTimer.cancel();
  }

  WatchTowerApiClient _createStub(grpc_services_api.ClientChannel channel) {
    return WatchTowerApiClient(
      channel,
      options: CallOptions(timeout: const Duration(seconds: 30)),
    );
  }

  void _monitorChannelState(ClientChannel channel) {
    _stateSubscription = channel.onConnectionStateChanged.listen(
      (state) {
        logger.d("Connection state: $state, ${state.name}");
        if (state.name == "idle") {
          isGrpcChannelReady = false;
          pingTimer.reset();
          _scheduleReconnect();
        } else if (state.name == "ready") {
          isGrpcChannelReady = true;
          pingTimer.reset();
          _reconnectTimer?.cancel();
          _isReconnecting = false;
        }
        if (onConnectionStateChanged != null) {
          onConnectionStateChanged!(isGrpcChannelReady);
        }
      },
      onError: (error) {
        logger.e("Connection state error: $error");
      },
      cancelOnError: false,
    );
  }

  void _scheduleReconnect() {
    if (_isReconnecting) return;

    _isReconnecting = true;
    _reconnectTimer?.cancel();

    logger.w("🔄 Reconnecting in 1 second...");
    _reconnectTimer = Timer(const Duration(seconds: 1), () {
      logger.i("🔌 Reconnecting...");
      createChannel();
    });
  }

  Future<void> dispose() async {
    _reconnectTimer?.cancel();
    pingTimer.cancel();
    await _stateSubscription?.cancel();
    await _currentChannel?.shutdown();
  }

  void pingWatchtower() {}
}
