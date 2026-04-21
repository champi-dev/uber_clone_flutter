import 'package:socket_io_client/socket_io_client.dart' as io;
import '../constants/api_config.dart';

class SocketClient {
  io.Socket? _socket;

  io.Socket connect(String token) {
    _socket?.dispose();
    _socket = io.io(
      ApiConfig.wsUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );
    _socket!.connect();
    return _socket!;
  }

  io.Socket? get socket => _socket;

  void joinRide(String rideId) => _socket?.emit('ride:join', rideId);
  void leaveRide(String rideId) => _socket?.emit('ride:leave', rideId);

  void dispose() {
    _socket?.dispose();
    _socket = null;
  }
}
