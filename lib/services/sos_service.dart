import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/config/api_config.dart';

/// Service for handling SOS emergency alerts
class SOSService {
  final _storage = const FlutterSecureStorage();

  /// Trigger high emergency SOS
  Future<Map<String, dynamic>> triggerHighEmergency() async {
    try {
      // Get current location
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );

      // Get officer details
      String? officerId = await _storage.read(key: 'officer_id');
      String? officerName = await _storage.read(key: 'officer_name');
      String? badgeNumber = await _storage.read(key: 'badge_number');

      if (officerId == null || officerName == null) {
        throw Exception('Officer not logged in');
      }

      // Send SOS request
      final response = await http
          .post(
            Uri.parse(ApiConfig.sosTrigger(officerId)),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'lat': position.latitude,
              'lng': position.longitude,
              'officer_name': officerName,
              'badge_number': badgeNumber,
              'emergency_type': 'high_emergency',
            }),
          )
          .timeout(
            ApiConfig.connectionTimeout,
            onTimeout: () => throw TimeoutException('SOS request timed out'),
          );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ SOS triggered successfully');
        return data;
      } else {
        throw Exception('Failed to trigger SOS: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error triggering SOS: $e');
      rethrow;
    }
  }

  /// Trigger text message emergency
  Future<Map<String, dynamic>> triggerTextEmergency(String message) async {
    try {
      // Get current location
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );

      // Get officer details
      String? officerId = await _storage.read(key: 'officer_id');
      String? officerName = await _storage.read(key: 'officer_name');
      String? badgeNumber = await _storage.read(key: 'badge_number');

      if (officerId == null || officerName == null) {
        throw Exception('Officer not logged in');
      }

      // Send SOS request
      final response = await http
          .post(
            Uri.parse(ApiConfig.sosTrigger(officerId)),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'lat': position.latitude,
              'lng': position.longitude,
              'officer_name': officerName,
              'badge_number': badgeNumber,
              'emergency_type': 'text_message',
              'message_text': message,
            }),
          )
          .timeout(
            ApiConfig.connectionTimeout,
            onTimeout: () => throw TimeoutException('SOS request timed out'),
          );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Text emergency sent successfully');
        return data;
      } else {
        throw Exception(
          'Failed to send text emergency: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('❌ Error sending text emergency: $e');
      rethrow;
    }
  }

  /// Cancel active SOS
  Future<void> cancelSOS() async {
    try {
      String? officerId = await _storage.read(key: 'officer_id');

      if (officerId == null) {
        throw Exception('Officer not logged in');
      }

      final response = await http
          .post(
            Uri.parse(ApiConfig.sosCancel(officerId)),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'reason': 'cancelled_by_officer'}),
          )
          .timeout(
            ApiConfig.connectionTimeout,
            onTimeout: () => throw TimeoutException('Cancel request timed out'),
          );

      if (response.statusCode == 200) {
        print('✅ SOS cancelled successfully');
      } else {
        throw Exception('Failed to cancel SOS: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error cancelling SOS: $e');
      rethrow;
    }
  }

  /// Get current officer location
  Future<Position> getCurrentLocation() async {
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 5),
    );
  }
}
