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

      final user = _supabase.auth.currentUser;

      if (user != null) {
        await registerCurrentDevice();
      }

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
        debugPrint('No authenticated user. FCM token not registered.');
        return;
      }

      final token = await _messaging.getToken();

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

    await _supabase.from('push_tokens').upsert(
      {
        'user_id': user.id,
        'token': token,
        'platform': platform,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'token',
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
