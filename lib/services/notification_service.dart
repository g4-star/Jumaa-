import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> initialize() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      debugPrint(
        'FCM permission status: ${settings.authorizationStatus}',
      );

      // Device registration is handled explicitly after authentication.
      // Do not register during startup/session restoration.

      _messaging.onTokenRefresh.listen((token) async {
        debugPrint('FCM token refreshed.');

        if (_supabase.auth.currentUser != null) {
          await _saveToken(token);
        }
      });
    } catch (e) {
      debugPrint('Notification initialization failed: $e');
    }
  }

  Future<void> registerCurrentDevice() async {
    try {
      final user = _supabase.auth.currentUser;

      if (user == null) {
        debugPrint('FCM REGISTER: No authenticated user. Token not registered.');
        return;
      }

      debugPrint('FCM REGISTER: authenticated user=${user.id}');
      debugPrint('FCM REGISTER: email=${user.email}');

      final token = await _messaging.getToken();

      if (token != null && token.isNotEmpty) {
        debugPrint(
          'FCM TOKEN DEBUG: ${token.substring(0, token.length > 12 ? 12 : token.length)}...',
        );
      }

      if (token == null || token.isEmpty) {
        debugPrint('FCM token unavailable.');
        return;
      }

      await _saveToken(token);

      debugPrint('FCM device token registered.');
    } catch (e) {
      debugPrint('Failed to register FCM device: $e');
    }
  }

  Future<void> _saveToken(String token) async {
    final user = _supabase.auth.currentUser;

    if (user == null) return;

    final platform = kIsWeb
        ? 'web'
        : Platform.isIOS
            ? 'ios'
            : 'android';

    await _supabase.rpc(
      'register_push_token',
      params: {
        'p_token': token,
        'p_platform': platform,
      },
    );
  }

  Future<void> removeCurrentDevice() async {
    try {
      final user = _supabase.auth.currentUser;

      if (user == null) return;

      final token = await _messaging.getToken();

      if (token == null || token.isEmpty) return;

      await _supabase
          .from('push_tokens')
          .delete()
          .eq('user_id', user.id)
          .eq('token', token);

      await _messaging.deleteToken();

      debugPrint('FCM device token removed.');
    } catch (e) {
      debugPrint('Failed to remove FCM device token: $e');
    }
  }
}
