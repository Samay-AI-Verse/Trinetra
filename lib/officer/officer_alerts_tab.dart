import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import '../services/map_service.dart';

class OfficerAlertsTab extends StatefulWidget {
  const OfficerAlertsTab({super.key});

  @override
  State<OfficerAlertsTab> createState() => _OfficerAlertsTabState();
}

class _OfficerAlertsTabState extends State<OfficerAlertsTab> {
  final MapService _mapService = MapService();
  final List<Map<String, dynamic>> _sosAlerts = [];
  StreamSubscription? _sosSubscription;

  @override
  void initState() {
    super.initState();
    _initializeAlerts();
  }

  void _initializeAlerts() {
    // Subscribe to SOS alerts
    _sosSubscription = _mapService.sosAlertStream.listen((alert) {
      if (mounted) {
        setState(() {
          _sosAlerts.insert(0, {...alert, 'received_at': DateTime.now()});
        });
      }
    });
  }

  @override
  void dispose() {
    _sosSubscription?.cancel();
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
        top: 120,
        bottom: 100,
      ),
      children: [
        // Header
        Text(
          'Emergency Alerts',
          style: GoogleFonts.outfit(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Real-time SOS alerts from nearby officers',
          style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600]),
        ),
        const SizedBox(height: 24),

        // SOS Alerts
        if (_sosAlerts.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(48),
              child: Column(
                children: [
                  Icon(
                    Icons.shield_outlined,
                    size: 64,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No emergency alerts',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'SOS alerts from nearby officers will appear here',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.grey[400],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          ..._sosAlerts.map(
            (alert) => _SOSAlertCard(
              officerName: alert['officer_name'] as String,
              badgeNumber: alert['badge_number'] as String?,
              emergencyType: alert['emergency_type'] as String,
              message: alert['message_text'] as String?,
              time: _getTimeAgo(alert['received_at'] as DateTime),
              lat: (alert['lat'] as num).toDouble(),
              lng: (alert['lng'] as num).toDouble(),
            ),
          ),

        // Placeholder alerts for demo
        if (_sosAlerts.isEmpty) ...[
          _AlertCard(
            type: 'Crowd Gathering',
            time: '12:05 PM',
            status: 'Active',
            color: Colors.orange,
          ),
          _AlertCard(
            type: 'Fight Detected',
            time: '11:45 AM',
            status: 'Investigating',
            color: Colors.red,
          ),
          _AlertCard(
            type: 'Medical Emergency',
            time: '10:30 AM',
            status: 'Resolved',
            color: Colors.green,
          ),
        ],
      ],
    );
  }
}

class _SOSAlertCard extends StatelessWidget {
  final String officerName;
  final String? badgeNumber;
  final String emergencyType;
  final String? message;
  final String time;
  final double lat;
  final double lng;

  const _SOSAlertCard({
    required this.officerName,
    this.badgeNumber,
    required this.emergencyType,
    this.message,
    required this.time,
    required this.lat,
    required this.lng,
  });

  String _getEmergencyTitle() {
    switch (emergencyType) {
      case 'high_emergency':
        return 'HIGH EMERGENCY';
      case 'text_message':
        return 'EMERGENCY MESSAGE';
      default:
        return 'EMERGENCY ALERT';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDC2626), width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFDC2626).withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.shield,
                  color: Color(0xFFDC2626),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getEmergencyTitle(),
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: const Color(0xFFDC2626),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      officerName,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black,
                      ),
                    ),
                    if (badgeNumber != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Badge: $badgeNumber',
                        style: GoogleFonts.inter(
                          color: Colors.grey[600],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  time.toUpperCase(),
                  style: GoogleFonts.inter(
                    color: const Color(0xFFDC2626),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (message != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.message, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      message!,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final String type;
  final String time;
  final String status;
  final Color color;

  const _AlertCard({
    required this.type,
    required this.time,
    required this.status,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.warning_amber_rounded, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: GoogleFonts.inter(
                    color: Colors.grey[500],
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status.toUpperCase(),
              style: GoogleFonts.inter(
                color: Colors.black,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
