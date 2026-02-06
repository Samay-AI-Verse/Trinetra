import 'package:flutter/material.dart';
import '../../services/sos_service.dart';
import 'sos_countdown_overlay.dart';

/// Bottom sheet for SOS emergency options - Direct trigger with countdown
class SOSBottomSheet extends StatelessWidget {
  final SOSService sosService;
  final VoidCallback onSOSTriggered;

  const SOSBottomSheet({
    super.key,
    required this.sosService,
    required this.onSOSTriggered,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.shield, color: Color(0xFFDC2626), size: 28),
              const SizedBox(width: 12),
              const Text(
                'Emergency Alert',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 24),

          const SizedBox(height: 32),

          // Single Large Emergency Button
          Center(
            child: _buildCircularEmergencyOption(
              context,
              icon: Icons.sos,
              label: 'HIGH\nEMERGENCY',
              color: const Color(0xFFDC2626),
              size: 120,
              iconSize: 48,
              onTap: () => _triggerHighEmergencyWithCountdown(context),
            ),
          ),
          const SizedBox(height: 32),

          // Cancel button
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  Widget _buildCircularEmergencyOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    double size = 80,
    double iconSize = 32,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.1),
              border: Border.all(color: color, width: 4),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 4,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(icon, color: color, size: iconSize),
          ),
          const SizedBox(height: 16),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: 1.2,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  void _triggerHighEmergencyWithCountdown(BuildContext context) {
    Navigator.pop(context); // Close bottom sheet

    // Show countdown overlay
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => SOSCountdownOverlay(
        onComplete: () async {
          Navigator.pop(context); // Close countdown

          try {
            await sosService.triggerHighEmergency();
            onSOSTriggered();

            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('🚨 Emergency alert sent!'),
                  backgroundColor: Color(0xFFDC2626),
                ),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to send alert: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
        onCancel: () {
          Navigator.pop(context); // Close countdown
        },
      ),
    );
  }

  void _showWalkieTalkieDialog(BuildContext context) {
    Navigator.pop(context); // Close bottom sheet

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.radio, color: Color(0xFF2563EB)),
            SizedBox(width: 12),
            Text('Walkie Talkie'),
          ],
        ),
        content: const Text(
          'Walkie Talkie channel active.\n\n'
          'Press and hold to speak to nearby officers.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.mic),
            label: const Text('Push to Talk'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
