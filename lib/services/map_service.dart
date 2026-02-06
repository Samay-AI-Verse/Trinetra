import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../core/config/api_config.dart';

/// Model for Officer location data
class OfficerLocation {
  final String officerId;
  final String officerName;
  final String? badgeNumber;
  final double lat;
  final double lng;
  final bool isOnline;
  final double? accuracy;
  final String timestamp;
  final bool sosActive;
  final String? sosType;
  final String? sosMessage;
  final String? sosTriggeredAt;

  OfficerLocation({
    required this.officerId,
    required this.officerName,
    this.badgeNumber,
    required this.lat,
    required this.lng,
    required this.isOnline,
    this.accuracy,
    required this.timestamp,
    this.sosActive = false,
    this.sosType,
    this.sosMessage,
    this.sosTriggeredAt,
  });

  factory OfficerLocation.fromJson(Map<String, dynamic> json) {
    return OfficerLocation(
      officerId: json['officer_id'] as String,
      officerName: json['officer_name'] as String,
      badgeNumber: json['badge_number'] as String?,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      isOnline: json['is_online'] as bool? ?? true,
      accuracy: json['accuracy'] != null
          ? (json['accuracy'] as num).toDouble()
          : null,
      timestamp:
          json['timestamp'] as String? ?? DateTime.now().toIso8601String(),
      sosActive: json['sos_active'] as bool? ?? false,
      sosType: json['sos_type'] as String?,
      sosMessage: json['sos_message'] as String?,
      sosTriggeredAt: json['sos_triggered_at'] as String?,
    );
  }
}

/// Model for Drone location data
class DroneLocation {
  final String droneId;
  final String? nickname;
  final double lat;
  final double lng;
  final bool isLive;
  final double? speed;
  final double? altitude;
  final double? heading;
  final String timestamp;

  DroneLocation({
    required this.droneId,
    this.nickname,
    required this.lat,
    required this.lng,
    required this.isLive,
    this.speed,
    this.altitude,
    this.heading,
    required this.timestamp,
  });

  factory DroneLocation.fromJson(Map<String, dynamic> json) {
    return DroneLocation(
      droneId: json['drone_id'] as String,
      nickname: json['nickname'] as String?,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      isLive: json['is_live'] as bool? ?? true,
      speed: json['speed'] != null ? (json['speed'] as num).toDouble() : null,
      altitude: json['alt'] != null ? (json['alt'] as num).toDouble() : null,
      heading: json['heading'] != null
          ? (json['heading'] as num).toDouble()
          : null,
      timestamp:
          json['timestamp'] as String? ?? DateTime.now().toIso8601String(),
    );
  }
}

/// Singleton service for managing map WebSocket connection
class MapService {
  static final MapService _instance = MapService._internal();
  factory MapService() => _instance;
  MapService._internal();

  WebSocketChannel? _channel;
  bool _isConnected = false;

  // Streams for real-time updates
  final _officersController =
      StreamController<Map<String, OfficerLocation>>.broadcast();
  final _dronesController =
      StreamController<Map<String, DroneLocation>>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();
  final _sosAlertController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _notificationController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, OfficerLocation>> get officersStream =>
      _officersController.stream;
  Stream<Map<String, DroneLocation>> get dronesStream =>
      _dronesController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;
  Stream<Map<String, dynamic>> get sosAlertStream => _sosAlertController.stream;
  Stream<Map<String, dynamic>> get notificationStream =>
      _notificationController.stream;

  // Current state
  final Map<String, OfficerLocation> _officers = {};
  final Map<String, DroneLocation> _drones = {};

  Map<String, OfficerLocation> get officers => Map.unmodifiable(_officers);
  Map<String, DroneLocation> get drones => Map.unmodifiable(_drones);
  bool get isConnected => _isConnected;

  /// Connect to WebSocket
  Future<void> connect() async {
    if (_isConnected) {
      print('MapService: Already connected');
      return;
    }

    try {
      final wsUrl = ApiConfig.wsLocations;
      print('MapService: Connecting to $wsUrl');

      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _isConnected = true;
      _connectionController.add(true);

      // Listen to WebSocket messages
      _channel!.stream.listen(
        (message) {
          _handleMessage(message);
        },
        onError: (error) {
          print('MapService: WebSocket error: $error');
          _handleDisconnection();
        },
        onDone: () {
          print('MapService: WebSocket connection closed');
          _handleDisconnection();
        },
      );

      print('MapService: Connected successfully');
    } catch (e) {
      print('MapService: Connection error: $e');
      _handleDisconnection();
    }
  }

  /// Handle incoming WebSocket messages
  void _handleMessage(dynamic message) {
    try {
      final data = json.decode(message as String) as Map<String, dynamic>;
      final type = data['type'] as String?;

      switch (type) {
        case 'snapshot':
          _handleSnapshot(data);
          break;
        case 'officer_location_update':
          _handleOfficerUpdate(data);
          break;
        case 'location_update':
          _handleDroneUpdate(data);
          break;
        case 'officer_status':
          _handleOfficerStatus(data);
          break;
        case 'status':
          _handleDroneStatus(data);
          break;
        case 'officer_sos_alert':
          _handleSOSAlert(data);
          break;
        case 'officer_sos_cancelled':
          _handleSOSCancelled(data);
          break;
        case 'notification':
          _handleNotification(data);
          break;
        default:
          print('MapService: Unknown message type: $type');
      }
    } catch (e) {
      print('MapService: Error handling message: $e');
    }
  }

  /// Handle initial snapshot
  void _handleSnapshot(Map<String, dynamic> data) {
    print('MapService: Received snapshot');

    // Process officers
    final officersList = data['officers'] as List<dynamic>? ?? [];
    _officers.clear();
    for (var officerData in officersList) {
      final officer = _parseOfficerFromSnapshot(
        officerData as Map<String, dynamic>,
      );
      if (officer != null) {
        _officers[officer.officerId] = officer;
      }
    }

    // Process drones
    final dronesList = data['drones'] as List<dynamic>? ?? [];
    _drones.clear();
    for (var droneData in dronesList) {
      final drone = _parseDroneFromSnapshot(droneData as Map<String, dynamic>);
      if (drone != null) {
        _drones[drone.droneId] = drone;
      }
    }

    print(
      'MapService: Loaded ${_officers.length} officers, ${_drones.length} drones',
    );
    _officersController.add(Map.from(_officers));
    _dronesController.add(Map.from(_drones));
  }

  /// Parse officer from snapshot
  OfficerLocation? _parseOfficerFromSnapshot(Map<String, dynamic> data) {
    try {
      final lastLocation = data['last_location'] as Map<String, dynamic>?;
      if (lastLocation == null) return null;

      return OfficerLocation(
        officerId: data['officer_id'] as String,
        officerName: data['officer_name'] as String,
        badgeNumber: data['badge_number'] as String?,
        lat: (lastLocation['lat'] as num).toDouble(),
        lng: (lastLocation['lng'] as num).toDouble(),
        isOnline: data['is_online'] as bool? ?? false,
        accuracy: lastLocation['accuracy'] != null
            ? (lastLocation['accuracy'] as num).toDouble()
            : null,
        timestamp:
            lastLocation['timestamp'] as String? ??
            DateTime.now().toIso8601String(),
        sosActive: data['sos_active'] as bool? ?? false,
        sosType: data['sos_type'] as String?,
        sosMessage: data['sos_message'] as String?,
        sosTriggeredAt: data['sos_triggered_at'] as String?,
      );
    } catch (e) {
      print('MapService: Error parsing officer: $e');
      return null;
    }
  }

  /// Parse drone from snapshot
  DroneLocation? _parseDroneFromSnapshot(Map<String, dynamic> data) {
    try {
      final lastLocation = data['last_location'] as Map<String, dynamic>?;
      if (lastLocation == null) return null;

      return DroneLocation(
        droneId: data['drone_id'] as String,
        nickname: data['nickname'] as String?,
        lat: (lastLocation['lat'] as num).toDouble(),
        lng: (lastLocation['lng'] as num).toDouble(),
        isLive: data['is_live'] as bool? ?? false,
        speed: lastLocation['speed'] != null
            ? (lastLocation['speed'] as num).toDouble()
            : null,
        altitude: lastLocation['alt'] != null
            ? (lastLocation['alt'] as num).toDouble()
            : null,
        heading: lastLocation['heading'] != null
            ? (lastLocation['heading'] as num).toDouble()
            : null,
        timestamp:
            lastLocation['timestamp'] as String? ??
            DateTime.now().toIso8601String(),
      );
    } catch (e) {
      print('MapService: Error parsing drone: $e');
      return null;
    }
  }

  /// Handle officer location update
  void _handleOfficerUpdate(Map<String, dynamic> data) {
    try {
      final officer = OfficerLocation.fromJson(data);
      _officers[officer.officerId] = officer;
      _officersController.add(Map.from(_officers));
      print('MapService: Updated officer ${officer.officerId}');
    } catch (e) {
      print('MapService: Error handling officer update: $e');
    }
  }

  /// Handle drone location update
  void _handleDroneUpdate(Map<String, dynamic> data) {
    try {
      print('🚁 DRONE UPDATE RECEIVED: $data');
      final drone = DroneLocation.fromJson(data);
      _drones[drone.droneId] = drone;
      _dronesController.add(Map.from(_drones));
      print(
        '✅ MapService: Updated drone ${drone.droneId} at (${drone.lat}, ${drone.lng}), isLive: ${drone.isLive}',
      );
      print('📊 Total drones in memory: ${_drones.length}');
    } catch (e) {
      print('❌ MapService: Error handling drone update: $e');
      print('❌ Problem data: $data');
    }
  }

  /// Handle officer status update
  void _handleOfficerStatus(Map<String, dynamic> data) {
    try {
      final officerId = data['officer_id'] as String;
      final isOnline = data['is_online'] as bool;

      if (_officers.containsKey(officerId)) {
        final officer = _officers[officerId]!;
        _officers[officerId] = OfficerLocation(
          officerId: officer.officerId,
          officerName: officer.officerName,
          badgeNumber: officer.badgeNumber,
          lat: officer.lat,
          lng: officer.lng,
          isOnline: isOnline,
          accuracy: officer.accuracy,
          timestamp: officer.timestamp,
          sosActive: officer.sosActive,
          sosType: officer.sosType,
          sosMessage: officer.sosMessage,
          sosTriggeredAt: officer.sosTriggeredAt,
        );
        _officersController.add(Map.from(_officers));
      }
    } catch (e) {
      print('MapService: Error handling officer status: $e');
    }
  }

  /// Handle drone status update
  void _handleDroneStatus(Map<String, dynamic> data) {
    try {
      final droneId = data['drone_id'] as String;
      final isLive = data['is_live'] as bool;

      if (_drones.containsKey(droneId)) {
        final drone = _drones[droneId]!;
        _drones[droneId] = DroneLocation(
          droneId: drone.droneId,
          nickname: drone.nickname,
          lat: drone.lat,
          lng: drone.lng,
          isLive: isLive,
          speed: drone.speed,
          altitude: drone.altitude,
          heading: drone.heading,
          timestamp: drone.timestamp,
        );
        _dronesController.add(Map.from(_drones));
      }
    } catch (e) {
      print('MapService: Error handling drone status: $e');
    }
  }

  /// Handle disconnection
  void _handleDisconnection() {
    _isConnected = false;
    _connectionController.add(false);
    _channel = null;
  }

  /// Disconnect from WebSocket
  void disconnect() {
    if (_channel != null) {
      _channel!.sink.close();
      _channel = null;
    }
    _handleDisconnection();
  }

  /// Handle SOS alert
  void _handleSOSAlert(Map<String, dynamic> data) {
    try {
      print('🚨 SOS ALERT RECEIVED: ${data['officer_id']}');

      final officerId = data['officer_id'] as String;
      final lat = (data['lat'] as num).toDouble();
      final lng = (data['lng'] as num).toDouble();

      // Update officer state with SOS
      if (_officers.containsKey(officerId)) {
        final officer = _officers[officerId]!;
        _officers[officerId] = OfficerLocation(
          officerId: officer.officerId,
          officerName: officer.officerName,
          badgeNumber: officer.badgeNumber,
          lat: lat,
          lng: lng,
          isOnline: officer.isOnline,
          accuracy: officer.accuracy,
          timestamp:
              data['triggered_at'] as String? ??
              DateTime.now().toIso8601String(),
          sosActive: true,
          sosType: data['emergency_type'] as String?,
          sosMessage: data['message_text'] as String?,
          sosTriggeredAt: data['triggered_at'] as String?,
        );
      } else {
        // Create new officer entry
        _officers[officerId] = OfficerLocation(
          officerId: officerId,
          officerName: data['officer_name'] as String,
          badgeNumber: data['badge_number'] as String?,
          lat: lat,
          lng: lng,
          isOnline: true,
          accuracy: null,
          timestamp:
              data['triggered_at'] as String? ??
              DateTime.now().toIso8601String(),
          sosActive: true,
          sosType: data['emergency_type'] as String?,
          sosMessage: data['message_text'] as String?,
          sosTriggeredAt: data['triggered_at'] as String?,
        );
      }

      _officersController.add(Map.from(_officers));
      _sosAlertController.add(data);
      print('✅ SOS alert processed');
    } catch (e) {
      print('❌ Error handling SOS alert: $e');
    }
  }

  /// Handle SOS cancellation
  void _handleSOSCancelled(Map<String, dynamic> data) {
    try {
      print('❌ SOS CANCELLED: ${data['officer_id']}');

      final officerId = data['officer_id'] as String;

      if (_officers.containsKey(officerId)) {
        final officer = _officers[officerId]!;
        _officers[officerId] = OfficerLocation(
          officerId: officer.officerId,
          officerName: officer.officerName,
          badgeNumber: officer.badgeNumber,
          lat: officer.lat,
          lng: officer.lng,
          isOnline: officer.isOnline,
          accuracy: officer.accuracy,
          timestamp: officer.timestamp,
          sosActive: false,
          sosType: null,
          sosMessage: null,
          sosTriggeredAt: null,
        );
        _officersController.add(Map.from(_officers));
      }

      print('✅ SOS cancellation processed');
    } catch (e) {
      print('❌ Error handling SOS cancellation: $e');
    }
  }

  /// Handle normal notification
  void _handleNotification(Map<String, dynamic> data) {
    try {
      print('📬 NOTIFICATION RECEIVED: ${data['notification_type']}');

      // Only process normal notifications (emergency ones are handled as SOS alerts)
      if (data['notification_type'] == 'normal') {
        _notificationController.add(data);
        print('✅ Notification processed: ${data['title']}');
      }
    } catch (e) {
      print('❌ Error handling notification: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    disconnect();
    _officersController.close();
    _dronesController.close();
    _connectionController.close();
    _sosAlertController.close();
    _notificationController.close();
  }
}
