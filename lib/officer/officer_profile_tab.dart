import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../auth/role_selection_screen.dart';
import '../services/officer_location_service.dart';

class OfficerProfileTab extends StatefulWidget {
  const OfficerProfileTab({super.key});

  @override
  State<OfficerProfileTab> createState() => _OfficerProfileTabState();
}

class _OfficerProfileTabState extends State<OfficerProfileTab> {
  final _storage = const FlutterSecureStorage();
  String _officerName = 'Officer';
  String _officerId = 'Loading...';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOfficerData();
  }

  Future<void> _loadOfficerData() async {
    String? name = await _storage.read(key: 'officer_name');
    String? id = await _storage.read(key: 'officer_id');

    if (mounted) {
      setState(() {
        _officerName = name ?? 'Unknown Officer';
        _officerId = id ?? 'ID Not Found';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    // Stop location tracking service before logout
    final locationService = OfficerLocationService();
    await locationService.stopTracking();

    // ONLY clear the binding flag
    // Keep PIN and officer_id so user can login again with same PIN
    await _storage.delete(key: 'is_bound');

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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.only(
        left: 24,
        right: 24,
        top: 100,
        bottom: 100,
      ),
      children: [
        // Profile Header
        Center(
          child: Column(
            children: [
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: Colors.grey[200]!, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Center(
                    child: Icon(
                      Icons.person,
                      size: 50,
                      color: Colors.grey[700],
                    ),
                    // In future: Image.network(_profileImageUrl) if available
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _officerName,
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              Text(
                'ID: $_officerId',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: const Color(0xFF10B981).withOpacity(0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.circle,
                      size: 10,
                      color: Color(0xFF10B981),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'ACTIVE DUTY',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF10B981),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 48),

        // Settings Sections
        _buildSectionHeader('Account'),
        _buildSettingsTile(
          icon: Icons.badge_outlined,
          title: 'Official Information',
          onTap: () {},
        ),
        _buildSettingsTile(
          icon: Icons.history,
          title: 'Shift History',
          onTap: () {},
        ),

        // Preferences Section REMOVED
        const SizedBox(height: 24),
        _buildSectionHeader('Support'),
        _buildSettingsTile(
          icon: Icons.help_outline,
          title: 'Help Center',
          onTap: () {},
        ),

        const SizedBox(height: 48),

        // Logout
        Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red[100]!),
            color: Colors.red[50],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _handleLogout(context),
              child: Center(
                child: Text(
                  'Log Out',
                  style: GoogleFonts.inter(
                    color: Colors.red[600],
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Widget _buildSectionHeader(String title) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12, left: 4),
    child: Text(
      title.toUpperCase(),
      style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Colors.grey[500],
        letterSpacing: 1.2,
      ),
    ),
  );
}

Widget _buildSettingsTile({
  required IconData icon,
  required String title,
  required VoidCallback onTap,
}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.grey[100]!),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.02),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: Colors.black),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
