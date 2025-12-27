import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../auth/role_selection_screen.dart';
import '../services/officer_location_service.dart';

class OfficerProfileTab extends StatelessWidget {
  const OfficerProfileTab({super.key});

  Future<void> _handleLogout(BuildContext context) async {
    const storage = FlutterSecureStorage();

    // Stop location tracking service before logout
    final locationService = OfficerLocationService();
    await locationService.stopTracking();

    // ONLY clear the binding flag
    // Keep PIN and officer_id so user can login again with same PIN
    await storage.delete(key: 'is_bound');

    // Navigate to role selection
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
        (route) => false,
      );
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
        Center(
          child: Column(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey[200]!, width: 4),
                ),
                child: const Icon(Icons.person, size: 50, color: Colors.white),
              ),
              const SizedBox(height: 16),
              Text(
                'Officer Unit 01',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                'ID: OFF-2025-X',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green[100]!),
                ),
                child: Text(
                  'ON DUTY',
                  style: GoogleFonts.inter(
                    color: Colors.green[700],
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 48),
        _ProfileItem(icon: Icons.history, title: 'Shift History'),
        _ProfileItem(icon: Icons.notifications_none, title: 'Notifications'),
        _ProfileItem(icon: Icons.settings_outlined, title: 'Settings'),
        _ProfileItem(icon: Icons.help_outline, title: 'Support'),
        const SizedBox(height: 48),
        TextButton(
          onPressed: () => _handleLogout(context),
          style: TextButton.styleFrom(
            foregroundColor: Colors.red,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: Text(
            'LOGOUT',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

class _ProfileItem extends StatelessWidget {
  final IconData icon;
  final String title;

  const _ProfileItem({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.black),
        title: Text(
          title,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 14,
          color: Colors.grey,
        ),
        onTap: () {},
      ),
    );
  }
}
