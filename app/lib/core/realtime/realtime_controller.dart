import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../features/auth/data/auth_controller.dart';
import '../../features/bar/data/bar_status_repository.dart';
import '../../features/drinks/data/drinks_repository.dart';
import '../../features/inventory/data/inventory_repository.dart';
import '../../features/orders/data/orders_repository.dart';
import '../constants/api_constants.dart';

final realtimeControllerProvider =
    Provider<RealtimeController>((ref) => RealtimeController(ref)..start());

class RealtimeController {
  RealtimeController(this._ref);

  final Ref _ref;
  io.Socket? _socket;
  String? _connectedToken;

  void start() {
    _ref.listen(authControllerProvider, (previous, next) {
      final user = next.valueOrNull;
      if (user == null) {
        _disconnect();
        return;
      }
      _connect();
    }, fireImmediately: true);

    _ref.onDispose(_disconnect);
  }

  Future<void> _connect() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null || token.isEmpty || token == _connectedToken) {
      return;
    }

    _disconnect();
    final socket = io.io(
      _socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableReconnection()
          .setAuth({'token': token})
          .build(),
    );

    socket
      ..on('order:created', (_) => _ref.invalidate(ordersListProvider))
      ..on('order:updated', (_) => _ref.invalidate(ordersListProvider))
      ..on('bar:status_updated', (_) => _ref.invalidate(barStatusProvider))
      ..on('drinks:updated', (_) {
        _ref.invalidate(drinksListProvider);
        _ref.invalidate(drinkCategoriesProvider);
      })
      ..on('inventory:updated', (_) {
        _ref.invalidate(inventoryProvider);
        _ref.invalidate(drinksListProvider);
      });

    socket.connect();
    _socket = socket;
    _connectedToken = token;
  }

  String get _socketUrl {
    final origin = ApiConstants.origin;
    if (origin.isNotEmpty) {
      return origin;
    }
    return Uri.base.origin;
  }

  void _disconnect() {
    _socket?.dispose();
    _socket = null;
    _connectedToken = null;
  }
}
