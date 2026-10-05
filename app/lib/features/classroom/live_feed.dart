import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/api/api_client.dart';
import '../../core/config.dart';

class LiveEvent {
  const LiveEvent(this.type, this.data, this.receivedAt);

  final String type;
  final Map<String, dynamic> data;
  final DateTime receivedAt;
}

class LiveFeedState {
  const LiveFeedState({this.connected = false, this.events = const []});

  final bool connected;
  final List<LiveEvent> events;
}

/// Teacher dashboard subscription to `/classrooms/{id}/live`, with automatic
/// reconnect (exponential backoff) and keep-alive pings.
class LiveFeed extends Notifier<LiveFeedState> {
  LiveFeed(this.classroomId);

  final int classroomId;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  Timer? _ping;
  Timer? _reconnect;
  var _attempt = 0;
  var _disposed = false;

  @override
  LiveFeedState build() {
    ref.onDispose(() {
      _disposed = true;
      _close();
      _reconnect?.cancel();
    });
    Future.microtask(_connect);
    return const LiveFeedState();
  }

  void _connect() {
    if (_disposed) return;
    final token = ref.read(tokenStorageProvider).token;
    final uri = Uri.parse(
      '${AppConfig.wsBaseUrl}/classrooms/$classroomId/live?token=$token',
    );
    final channel = WebSocketChannel.connect(uri);
    _channel = channel;
    channel.ready.then((_) {
      if (_disposed) return;
      _attempt = 0;
      state = LiveFeedState(connected: true, events: state.events);
      _ping = Timer.periodic(
        const Duration(seconds: 25),
        (_) => channel.sink.add('ping'),
      );
    }, onError: (_) => _scheduleReconnect());

    _sub = channel.stream.listen(
      (message) {
        final data = jsonDecode(message as String) as Map<String, dynamic>;
        state = LiveFeedState(
          connected: true,
          events: [
            LiveEvent(data['type'] as String, data, DateTime.now()),
            ...state.events.take(49),
          ],
        );
      },
      onDone: _scheduleReconnect,
      onError: (_) => _scheduleReconnect(),
    );
  }

  void _scheduleReconnect() {
    _close();
    if (_disposed) return;
    state = LiveFeedState(connected: false, events: state.events);
    final delay = Duration(seconds: min(30, 1 << _attempt++));
    _reconnect?.cancel();
    _reconnect = Timer(delay, _connect);
  }

  void _close() {
    _ping?.cancel();
    _sub?.cancel();
    _channel?.sink.close();
    _channel = null;
  }
}

final liveFeedProvider = NotifierProvider.autoDispose
    .family<LiveFeed, LiveFeedState, int>(LiveFeed.new);
