import 'dart:async';

import 'package:flutter/services.dart';

import 'payment_parser.dart';

class SoundboxPlatform {
  static const _control = MethodChannel('soundbox/control');
  static const _notifications = EventChannel('soundbox/notifications');

  Stream<PaymentNotification> get notifications => _notifications
      .receiveBroadcastStream()
      .map((dynamic raw) => Map<String, dynamic>.from(raw as Map))
      .map(
        (m) => PaymentNotification(
          m['package'] as String? ?? '',
          m['title'] as String? ?? '',
          m['body'] as String? ?? '',
          DateTime.fromMillisecondsSinceEpoch(m['observedAt'] as int),
        ),
      );

  Future<bool> hasNotificationAccess() async =>
      await _control.invokeMethod<bool>('notificationAccess') ?? false;
  Future<void> openNotificationAccess() =>
      _control.invokeMethod<void>('openNotificationAccess');
  Future<DateTime?> lastConnectedAt() async {
    final value = await _control.invokeMethod<int>('lastConnectedAt') ?? 0;
    return value == 0 ? null : DateTime.fromMillisecondsSinceEpoch(value);
  }

  Future<bool> announce(String text, {String language = 'en-IN'}) async =>
      await _control.invokeMethod<bool>('announce', {
        'text': text,
        'language': language,
      }) ??
      false;
}
