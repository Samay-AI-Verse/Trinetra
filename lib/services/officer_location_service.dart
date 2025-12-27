import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/config/api_config.dart';

class OfficerLocationService {
  final _storage = const FlutterSecureStorage();
  Timer? _locationTimer;
  bool _isTracking = false;

  /// Request location permissions
  Future<bool> requestPermissions() async {
    try {
      bool serviceEnabled;
      LocationPermission permission;

      // Check if location services are enabled
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Location services are disabled - return false silently
        return false;
      }

      // Check permission status
      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          // Permissions are denied - return false silently
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        // Permissions are permanently denied - return false silently
        return false;
      }

      return true;
    } catch (e) {
      // Catch any exceptions and return false silently
      print('Location permission error (non-critical): $e');
      return false;
    }
  }

  /// Start tracking officer location
  Future<void> startTracking() async {
    if (_isTracking) {
      print('Location tracking already started');
      return;
    }

    // Get officer details from storage
    String? officerId = await _storage.read(key: 'officer_id');
    String? officerName = await _storage.read(key: 'officer_name');

    if (officerId == null || officerName == null) {
      // Officer not logged in yet - silently skip tracking
      return;
    }

    _isTracking = true;

    // Send initial online status
    await _sendStatus(officerId, officerName, isOnline: true);

    // Start periodic location updates (every 5 seconds)
    // Note: Timer.periodic callbacks cannot be async, so we don't await inside
    _locationTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      // Fire and forget - don't await in Timer callback
      // Wrap in try-catch to prevent exceptions from stopping the timer
      try {
        _sendLocation(officerId, officerName);
      } catch (e) {
        // Error in timer - silently ignore
      }
    });

    // Started location tracking - no print to avoid debugger pauses
  }

  /// Stop tracking officer location
  Future<void> stopTracking() async {
    if (!_isTracking) {
      return;
    }

    _isTracking = false;
    _locationTimer?.cancel();
    _locationTimer = null;

    // Send offline status
    String? officerId = await _storage.read(key: 'officer_id');
    String? officerName = await _storage.read(key: 'officer_name');

    if (officerId != null && officerName != null) {
      await _sendStatus(officerId, officerName, isOnline: false);
    }

    // Stopped location tracking - no print to avoid debugger pauses
  }

  /// Send location to backend
  Future<void> _sendLocation(String officerId, String officerName) async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      await http
          .post(
            Uri.parse(ApiConfig.officerLocation(officerId)),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'lat': position.latitude,
              'lng': position.longitude,
              'officer_name': officerName,
              'accuracy': position.accuracy,
            }),
          )
          .timeout(
            ApiConfig.connectionTimeout,
            onTimeout: () =>
                throw TimeoutException('Location update timed out'),
          );

      // Location sent successfully - no print to avoid debugger pauses
    } catch (e) {
      // Error sending location - silently ignore
    }
  }

  /// Send online/offline status to backend
  Future<void> _sendStatus(
    String officerId,
    String officerName, {
    required bool isOnline,
  }) async {
    try {
      await http
          .post(
            Uri.parse(ApiConfig.officerStatus(officerId)),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'is_online': isOnline,
              'officer_name': officerName,
            }),
          )
          .timeout(
            ApiConfig.connectionTimeout,
            onTimeout: () => throw TimeoutException('Status update timed out'),
          );

      // Status sent successfully - no print to avoid debugger pauses
    } catch (e) {
      // Error sending status - silently ignore
    }
  }

  bool get isTracking => _isTracking;
}
