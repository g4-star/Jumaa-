import 'package:firebase_messaging/firebase_messaging.dart';
import 'notification_service.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class JumaaPermissionService {
  JumaaPermissionService._();

  static final JumaaPermissionService instance = JumaaPermissionService._();

  /// Request notification permission using the existing Firebase Messaging
  /// implementation.
  Future<AuthorizationStatus> requestNotifications() {
    return NotificationService.instance.requestPermission();
  }

  /// Check/request location permission.
  ///
  /// This does not fetch the user's location. It only handles permission.
  Future<LocationPermission> requestLocation() async {
    try {
      // First check whether the phone's Location/GPS service is enabled.
      // If it is OFF, open the system Location settings so the user can
      // enable it just like other location-based apps.
      var serviceEnabled =
          await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        debugPrint(
          'JUMAA location service is disabled. '
          'Opening device Location settings.',
        );

        final opened = await Geolocator.openLocationSettings();

        if (!opened) {
          debugPrint(
            'JUMAA could not open device Location settings.',
          );
          return LocationPermission.denied;
        }

        // The user has returned from system settings.
        // Check the service state again.
        serviceEnabled =
            await Geolocator.isLocationServiceEnabled();

        if (!serviceEnabled) {
          debugPrint(
            'JUMAA location service is still disabled.',
          );
          return LocationPermission.denied;
        }
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      debugPrint(
        'JUMAA location permission: $permission',
      );

      return permission;
    } catch (e) {
      debugPrint(
        'JUMAA location permission failed: $e',
      );
      return LocationPermission.denied;
    }
  }

  /// Check whether location is ready to use.
  Future<bool> canUseLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return false;
      }

      final permission = await Geolocator.checkPermission();

      return permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    } catch (e) {
      debugPrint('JUMAA location availability check failed: $e');
      return false;
    }
  }

  /// Opens Android/iOS app settings when a permission has been
  /// permanently denied.
  Future<bool> openSettings() async {
    try {
      return await Geolocator.openAppSettings();
    } catch (e) {
      debugPrint('JUMAA could not open app settings: $e');
      return false;
    }
  }
}
