import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:http/http.dart' as http;

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('🔔 Background message received: ${message.notification?.title}');
  // Handle background message here if needed
}

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

  // Firebase Messaging
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  // Backend URL - Update this with your deployed backend URL
  static const String backendUrl =
      'overprosperous-aviana-nontextually.ngrok-free.dev';
  static const String wsUrl = 'wss://$backendUrl/ws/notifications';
  static const String httpUrl = 'https://$backendUrl';

  bool _isInitialized = false;
  String? _currentOfficerId;
  String? _fcmToken;

  /// Stream of incoming notifications
  Stream<Map<String, dynamic>> get notificationStream =>
      _notificationController.stream;

  /// Initialize the notification service
  Future<void> initialize(String officerId) async {
    if (_isInitialized) return;

    _currentOfficerId = officerId;

    // Initialize Firebase Cloud Messaging
    await _initializeFirebaseMessaging();

    // Initialize local notifications
    await _initializeLocalNotifications();

    // Connect to WebSocket for real-time updates
    await _connectWebSocket();

    _isInitialized = true;
    print('✅ NotificationService initialized for officer: $officerId');
  }

  /// Initialize Firebase Cloud Messaging
  Future<void> _initializeFirebaseMessaging() async {
    try {
      // Request permission for notifications
      NotificationSettings settings = await _firebaseMessaging
          .requestPermission(
            alert: true,
            announcement: false,
            badge: true,
            carPlay: false,
            criticalAlert: true,
            provisional: false,
            sound: true,
          );

      print('📱 FCM Permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        // Get FCM token
        _fcmToken = await _firebaseMessaging.getToken();
        print('🔔 FCM Token: $_fcmToken');

        // Register token with backend
        if (_fcmToken != null && _currentOfficerId != null) {
          await _registerFCMToken(_fcmToken!);
        }

        // Listen for token refresh
        _firebaseMessaging.onTokenRefresh.listen((newToken) {
          print('🔄 FCM Token refreshed: $newToken');
          _fcmToken = newToken;
          if (_currentOfficerId != null) {
            _registerFCMToken(newToken);
          }
        });

        // Handle foreground messages
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

        // Handle background messages
        FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler,
        );

        // Handle notification taps when app is in background/terminated
        FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

        // Check if app was opened from a notification
        RemoteMessage? initialMessage = await _firebaseMessaging
            .getInitialMessage();
        if (initialMessage != null) {
          _handleNotificationTap(initialMessage);
        }

        print('✅ Firebase Cloud Messaging initialized');
      } else {
        print('⚠️ Notification permissions denied');
      }
    } catch (e) {
      print('❌ Error initializing FCM: $e');
    }
  }

  /// Register FCM token with backend
  Future<void> _registerFCMToken(String token) async {
    try {
      final response = await http.post(
        Uri.parse('$httpUrl/api/fcm/register-token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'officer_id': _currentOfficerId,
          'fcm_token': token,
          'device_info': {
            'platform': 'android',
            'registered_at': DateTime.now().toIso8601String(),
          },
        }),
      );

      if (response.statusCode == 200) {
        print('✅ FCM token registered with backend');
      } else {
        print('❌ Failed to register FCM token: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error registering FCM token: $e');
    }
  }

  /// Handle foreground FCM messages
  void _handleForegroundMessage(RemoteMessage message) {
    print('📨 Foreground FCM message: ${message.notification?.title}');

    final notification = message.notification;
    final data = message.data;

    if (notification != null) {
      // Show local notification for foreground messages
      _showLocalNotification(
        title: notification.title ?? 'Notification',
        body: notification.body ?? '',
        isEmergency:
            data['notification_type'] == 'emergency' ||
            data['type'] == 'officer_sos_alert',
        payload: jsonEncode(data),
      );

      // Add to stream for in-app display
      _notificationController.add({
        'title': notification.title,
        'message': notification.body,
        'notification_type': data['notification_type'] ?? 'normal',
        'type': data['type'],
        ...data,
        'received_at': DateTime.now().toIso8601String(),
      });
    }
  }

  /// Handle notification tap (when app opened from notification)
  void _handleNotificationTap(RemoteMessage message) {
    print('📱 Notification tapped: ${message.notification?.title}');

    final data = message.data;
    _notificationController.add({
      ...data,
      'tapped': true,
      'received_at': DateTime.now().toIso8601String(),
    });

    // You can add navigation logic here
    // For example, navigate to specific screen based on notification type
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
      onDidReceiveNotificationResponse: _onLocalNotificationTapped,
    );

    // Create notification channels for Android
    await _createNotificationChannels();

    print('✅ Local notifications initialized');
  }

  /// Create Android notification channels
  Future<void> _createNotificationChannels() async {
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidPlugin != null) {
      // Normal notifications channel
      const normalChannel = AndroidNotificationChannel(
        'trinetra_notifications',
        'Notifications',
        description: 'General notifications from command center',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      // Emergency alerts channel
      const emergencyChannel = AndroidNotificationChannel(
        'trinetra_emergency',
        'Emergency Alerts',
        description: 'Critical emergency alerts from officers',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        ledColor: Color(0xFFDC2626),
      );

      await androidPlugin.createNotificationChannel(normalChannel);
      await androidPlugin.createNotificationChannel(emergencyChannel);

      print('✅ Notification channels created');
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

    // Show local notification (FCM will handle this if enabled)
    // This is a fallback for WebSocket notifications
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
      isEmergency ? 'trinetra_emergency' : 'trinetra_notifications',
      isEmergency ? 'Emergency Alerts' : 'Notifications',
      channelDescription: isEmergency
          ? 'Critical emergency alerts from officers'
          : 'General notifications',
      importance: isEmergency ? Importance.max : Importance.high,
      priority: isEmergency ? Priority.max : Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      color: isEmergency ? const Color(0xFFDC2626) : const Color(0xFF00D4FF),
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

  /// Handle local notification tap
  void _onLocalNotificationTapped(NotificationResponse response) {
    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!);
        print('📱 Local notification tapped: ${data['title']}');
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

  /// Get current FCM token
  String? get fcmToken => _fcmToken;

  /// Dispose resources
  void dispose() {
    _channel?.sink.close(status.goingAway);
    _notificationController.close();
    _isInitialized = false;
  }
}
