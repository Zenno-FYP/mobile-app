import 'dart:async';
import 'dart:developer' as developer;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../../core/config/env_config.dart';
import 'models/chat_models.dart';

/// Singleton-ish socket wrapper around the `/chat` Socket.IO namespace.
///
/// The lifetime is tied to a Riverpod provider so it gets disposed when the
/// auth session ends or the app exits.
class ChatSocketService {
  io.Socket? _socket;
  final _newMessageController = StreamController<NewMessageEvent>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();

  Stream<NewMessageEvent> get onNewMessage => _newMessageController.stream;
  Stream<bool> get onConnectionChanged => _connectionController.stream;
  bool get isConnected => _socket?.connected ?? false;

  /// Single-flight connect: callers may invoke [connect] concurrently (e.g.
  /// the thread screen calling it right before [sendMessage] while the inbox
  /// is also wiring it up on its post-frame callback). We share one in-flight
  /// future so they all wait on the same handshake.
  Future<void>? _connectFuture;

  Future<void> connect() async {
    if (_socket?.connected == true) return;
    final inFlight = _connectFuture;
    if (inFlight != null) return inFlight;
    final fut = _doConnect();
    _connectFuture = fut;
    try {
      await fut;
    } finally {
      _connectFuture = null;
    }
  }

  Future<void> _doConnect() async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null) {
      throw const SocketSendException('Not signed in.');
    }

    _socket?.dispose();
    final socket = io.io(
      '${EnvConfig.socketOrigin}/chat',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableReconnection()
          .setReconnectionAttempts(5)
          .setReconnectionDelay(1500)
          .disableAutoConnect()
          .build(),
    );
    _socket = socket;

    // Persistent listeners (kept for the lifetime of the socket so we
    // continue to forward state changes on every reconnect).
    socket
      ..onConnect((_) {
        developer.log('chat socket: connected');
        _connectionController.add(true);
      })
      ..onDisconnect((_) {
        developer.log('chat socket: disconnected');
        _connectionController.add(false);
      })
      ..onConnectError((e) => developer.log('chat socket: connect error', error: e))
      ..onError((e) => developer.log('chat socket: error', error: e))
      ..on('chat:new_message', _handleNewMessage);

    // One-shot listeners that resolve the handshake future. We use named
    // closures + manual `off` instead of `once` so we can also cancel them
    // from the timeout branch below without interfering with the persistent
    // listeners above.
    final completer = Completer<void>();
    Timer? timeout;
    late void Function(dynamic) onConnectOnce;
    late void Function(dynamic) onErrorOnce;

    onConnectOnce = (_) {
      socket.off('connect', onConnectOnce);
      socket.off('connect_error', onErrorOnce);
      timeout?.cancel();
      if (!completer.isCompleted) completer.complete();
    };
    onErrorOnce = (dynamic e) {
      socket.off('connect', onConnectOnce);
      socket.off('connect_error', onErrorOnce);
      timeout?.cancel();
      if (!completer.isCompleted) {
        completer.completeError(
          SocketSendException('Cannot reach chat server: $e'),
        );
      }
    };

    socket.on('connect', onConnectOnce);
    socket.on('connect_error', onErrorOnce);

    timeout = Timer(const Duration(seconds: 8), () {
      socket.off('connect', onConnectOnce);
      socket.off('connect_error', onErrorOnce);
      if (!completer.isCompleted) {
        completer.completeError(
          const SocketSendException('Chat server connect timed out.'),
        );
      }
    });

    socket.connect();
    return completer.future;
  }

  void _handleNewMessage(dynamic data) {
    if (data is! Map) return;
    try {
      _newMessageController.add(NewMessageEvent(
        conversationId: data['conversation_id'] as String? ?? '',
        message: ChatMessage.fromJson(
          (data['message'] as Map).cast<String, dynamic>(),
        ),
      ));
    } catch (e) {
      developer.log('chat socket: failed to parse new message', error: e);
    }
  }

  /// Sends a text message to the recipient and resolves with the server-
  /// confirmed ack payload, or rejects with a [SocketSendException] if the
  /// gateway returns `ok: false` or the socket is offline.
  Future<ChatMessage> sendMessage({
    required String recipientUserId,
    required String text,
  }) async {
    // If we lost the socket (cold start, backgrounded, token refresh), try
    // to reconnect once before failing. This keeps the UX smooth: the user
    // taps send, we transparently re-handshake, then deliver the message.
    if (_socket == null || _socket?.connected != true) {
      try {
        await connect();
      } catch (e) {
        return Future.error(
          e is SocketSendException
              ? e
              : SocketSendException('Not connected to chat server: $e'),
        );
      }
    }
    final socket = _socket;
    if (socket == null || !socket.connected) {
      return Future.error(
        const SocketSendException('Not connected to chat server.'),
      );
    }

    final completer = Completer<ChatMessage>();
    socket.emitWithAck(
      'send_message',
      {'recipientUserId': recipientUserId, 'text': text},
      ack: (dynamic ack) {
        try {
          if (ack is! Map) {
            completer.completeError(
              const SocketSendException('Invalid server response.'),
            );
            return;
          }
          if (ack['ok'] != true) {
            completer.completeError(SocketSendException(
              ack['error']?.toString() ?? 'Failed to send message.',
            ));
            return;
          }
          final message = ack['message'];
          if (message is! Map) {
            completer.completeError(
              const SocketSendException('Server returned no message payload.'),
            );
            return;
          }
          completer.complete(
            ChatMessage.fromJson(message.cast<String, dynamic>()),
          );
        } catch (e, st) {
          completer.completeError(e, st);
        }
      },
    );
    return completer.future;
  }

  void markRead({required String conversationId}) {
    _socket?.emit('mark_read', {'conversationId': conversationId});
  }

  Future<void> reconnect() async {
    _socket?.disconnect();
    await connect();
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  void dispose() {
    disconnect();
    _newMessageController.close();
    _connectionController.close();
  }
}

class NewMessageEvent {
  const NewMessageEvent({required this.conversationId, required this.message});
  final String conversationId;
  final ChatMessage message;
}

class SocketSendException implements Exception {
  const SocketSendException(this.message);
  final String message;
  @override
  String toString() => message;
}
