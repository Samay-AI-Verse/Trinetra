import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:http/http.dart' as http;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // WebSocket for real-time notifications
  WebSocketChannel? _channel;
  final StreamController<Map<String, dynamic>> _notificationController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Local notifications plugin
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // Backend URL - Update this with your deployed backend URL
  static const String backendUrl =
      'overprosperous-aviana-nontextually.ngrok-free.dev';
  static const String wsUrl = 'wss://$backendUrl/ws/notifications';
  static const String httpUrl = 'https://$backendUrl';

  bool _isInitialized = false;
  String? _currentOfficerId;

  /// Stream of incoming notifications
  Stream<Map<String, dynamic>> get notificationStream =>
      _notificationController.stream;

  /// Initialize the notification service
  Future<void> initialize(String officerId) async {
    if (_isInitialized) return;

    _currentOfficerId = officerId;

    // Initialize local notifications
    await _initializeLocalNotifications();

    // Connect to WebSocket for real-time updates
    await _connectWebSocket();

    _isInitialized = true;
    print('✅ NotificationService initialized for officer: $officerId');
  }

  /// Initialize local notifications (for background/closed app)
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request permissions for Android 13+
    await _requestNotificationPermissions();
  }

  /// Request notification permissions
  Future<void> _requestNotificationPermissions() async {
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
    }

    final iosPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();

    if (iosPlugin != null) {
      await iosPlugin.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  /// Connect to WebSocket for real-time notifications
  Future<void> _connectWebSocket() async {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _channel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message);
            _handleWebSocketMessage(data);
          } catch (e) {
            print('❌ Error parsing WebSocket message: $e');
          }
        },
        onError: (error) {
          print('❌ WebSocket error: $error');
          _reconnectWebSocket();
        },
        onDone: () {
          print('⚠️ WebSocket connection closed');
          _reconnectWebSocket();
        },
      );

      print('✅ WebSocket connected to: $wsUrl');
    } catch (e) {
      print('❌ Failed to connect WebSocket: $e');
      _reconnectWebSocket();
    }
  }

  /// Reconnect WebSocket after delay
  Future<void> _reconnectWebSocket() async {
    await Future.delayed(const Duration(seconds: 5));
    if (_isInitialized) {
      print('🔄 Reconnecting WebSocket...');
      await _connectWebSocket();
    }
  }

  /// Handle incoming WebSocket messages
  void _handleWebSocketMessage(Map<String, dynamic> data) {
    final type = data['type'] as String?;

    if (type == 'notification') {
      _handleNotification(data);
    } else if (type == 'officer_sos_alert') {
      _handleEmergencyAlert(data);
    }
  }

  /// Handle regular notification
  void _handleNotification(Map<String, dynamic> data) {
    final notificationType = data['notification_type'] as String;
    final title = data['title'] as String;
    final message = data['message'] as String;
    final targetOfficerIds = data['target_officer_ids'] as List?;

    // Check if this notification is for current officer
    if (targetOfficerIds != null &&
        !targetOfficerIds.contains(_currentOfficerId)) {
      return; // Not for this officer
    }

    // Add to stream for in-app display
    _notificationController.add(data);

    // Show local notification
    if (notificationType == 'emergency') {
      _showLocalNotification(
        title: title,
        body: message,
        isEmergency: true,
        payload: jsonEncode(data),
      );
    } else {
      _showLocalNotification(
        title: title,
        body: message,
        isEmergency: false,
        payload: jsonEncode(data),
      );
    }
  }

  /// Handle emergency alert
  void _handleEmergencyAlert(Map<String, dynamic> data) {
    final officerName = data['officer_name'] as String;
    final emergencyType = data['emergency_type'] as String;
    final messageText = data['message_text'] as String?;
    final lat = data['lat'];
    final lng = data['lng'];

    // Add to stream for in-app display
    _notificationController.add(data);

    // Show critical local notification
    _showLocalNotification(
      title: '🚨 EMERGENCY ALERT - $officerName',
      body: messageText ?? '$emergencyType at ($lat, $lng)',
      isEmergency: true,
      payload: jsonEncode(data),
    );
  }

  /// Show local notification (works even when app is closed)
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    required bool isEmergency,
    String? payload,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      isEmergency ? 'emergency_channel' : 'normal_channel',
      isEmergency ? 'Emergency Alerts' : 'Notifications',
      channelDescription: isEmergency
          ? 'Critical emergency alerts from officers'
          : 'General notifications',
      importance: isEmergency ? Importance.max : Importance.high,
      priority: isEmergency ? Priority.max : Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      sound: isEmergency
          ? const RawResourceAndroidNotificationSound('emergency_sound')
          : null,
      color: isEmergency ? const Color(0xFFDC2626) : null,
      styleInformation: BigTextStyleInformation(body),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.critical,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      notificationDetails,
      payload: payload,
    );

    print('📱 Local notification shown: $title');
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!);
        print('📱 Notification tapped: ${data['title']}');
        // You can navigate to specific screen here
        _notificationController.add({...data, 'tapped': true});
      } catch (e) {
        print('❌ Error handling notification tap: $e');
      }
    }
  }

  /// Fetch past notifications from backend
  Future<List<Map<String, dynamic>>> fetchNotifications() async {
    if (_currentOfficerId == null) return [];

    try {
      final response = await http.get(
        Uri.parse('$httpUrl/api/notifications/$_currentOfficerId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final notifications = data['notifications'] as List;
        return notifications.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      print('❌ Error fetching notifications: $e');
    }

    return [];
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await http.post(
        Uri.parse('$httpUrl/api/notifications/$notificationId/read'),
      );
    } catch (e) {
      print('❌ Error marking notification as read: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _channel?.sink.close(status.goingAway);
    _notificationController.close();
    _isInitialized = false;
  }
}
