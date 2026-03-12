import 'dart:convert';
import 'dart:io';

import 'package:web_socket_channel/web_socket_channel.dart';

class MessageTransportService {
  const MessageTransportService();

  Future<void> broadcastUdp(
    Map<String, dynamic> payload, {
    String host = '255.255.255.255',
    int port = 8888,
  }) async {
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    try {
      socket.broadcastEnabled = true;
      socket.send(
        utf8.encode(jsonEncode(payload)),
        InternetAddress(host),
        port,
      );
    } finally {
      socket.close();
    }
  }

  Future<void> sendViaExistingChannel(
    WebSocketChannel? channel,
    Map<String, dynamic> payload,
  ) async {
    if (channel == null) {
      return;
    }
    channel.sink.add(jsonEncode(payload));
  }

  Future<void> sendViaDirectWebSocket({
    required String serverUrl,
    required Map<String, dynamic> registerPayload,
    required Map<String, dynamic> payload,
    Duration settleDelay = const Duration(milliseconds: 500),
  }) async {
    final channel = WebSocketChannel.connect(Uri.parse(serverUrl));
    try {
      channel.sink.add(jsonEncode(registerPayload));
      await Future.delayed(settleDelay);
      channel.sink.add(jsonEncode(payload));
      await Future.delayed(settleDelay);
    } finally {
      channel.sink.close();
    }
  }

  @Deprecated('Use sendViaDirectWebSocket')
  Future<void> sendViaTemporaryWebSocket({
    required String serverUrl,
    required Map<String, dynamic> registerPayload,
    required Map<String, dynamic> payload,
    Duration settleDelay = const Duration(milliseconds: 500),
  }) {
    return sendViaDirectWebSocket(
      serverUrl: serverUrl,
      registerPayload: registerPayload,
      payload: payload,
      settleDelay: settleDelay,
    );
  }
}
