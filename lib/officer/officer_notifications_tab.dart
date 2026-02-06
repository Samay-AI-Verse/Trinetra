import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import '../services/map_service.dart';

class OfficerNotificationsTab extends StatefulWidget {
  const OfficerNotificationsTab({super.key});

  @override
  State<OfficerNotificationsTab> createState() =>
      _OfficerNotificationsTabState();
}

class _OfficerNotificationsTabState extends State<OfficerNotificationsTab> {
  final MapService _mapService = MapService();
  final List<Map<String, dynamic>> _notifications = [];
  StreamSubscription? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  void _initializeNotifications() {
    // Subscribe to notifications
    _notificationSubscription = _mapService.notificationStream.listen((
      notification,
    ) {
      if (mounted) {
        setState(() {
          _notifications.insert(0, {
            ...notification,
            'received_at': DateTime.now(),
          });
        });
      }
    });
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  String _getTimeAgo(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(
        left: 24,
        right: 24,
        top: 60, // Moved up more
        bottom: 100,
      ),
      children: [
        // Header
        Center(
          child: Column(
            children: [
              Text(
                'Notifications',
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Messages from control room and updates',
                style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Notifications List
        if (_notifications.isEmpty) ...[
          const _NotificationCard(
            title: 'Control Room Update',
            message: 'This is a demo notification to verify the UI layout.',
            time: 'Just now',
            notificationType: 'info',
          ),
        ] else
          ..._notifications.map(
            (notification) => _NotificationCard(
              title: notification['title'] as String,
              message: notification['message'] as String,
              time: _getTimeAgo(notification['received_at'] as DateTime),
              notificationType: notification['notification_type'] as String,
            ),
          ),
      ],
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final String title;
  final String message;
  final String time;
  final String notificationType;

  const _NotificationCard({
    required this.title,
    required this.message,
    required this.time,
    required this.notificationType,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF00D4FF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.info_outline,
              color: Color(0xFF00D4FF),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      time,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
