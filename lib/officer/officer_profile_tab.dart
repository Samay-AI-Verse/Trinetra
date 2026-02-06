import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../auth/role_selection_screen.dart';
import '../services/officer_location_service.dart';
import '../core/config/api_config.dart';

class OfficerProfileTab extends StatefulWidget {
  const OfficerProfileTab({super.key});

  @override
  State<OfficerProfileTab> createState() => _OfficerProfileTabState();
}

class _OfficerProfileTabState extends State<OfficerProfileTab> {
  final _storage = const FlutterSecureStorage();
  Map<String, dynamic>? _officerData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOfficerData();
  }

  Future<void> _loadOfficerData() async {
    try {
      String? officerId = await _storage.read(key: 'officer_id');
      if (officerId != null) {
        final response = await http.get(
          Uri.parse(ApiConfig.officerDetails(officerId)),
        );

        if (response.statusCode == 200) {
          if (mounted) {
            setState(() {
              _officerData = json.decode(response.body);
              _isLoading = false;
            });
          }
        } else {
          _useLocalFallback();
        }
      } else {
        _useLocalFallback();
      }
    } catch (e) {
      _useLocalFallback();
    }
  }

  Future<void> _useLocalFallback() async {
    String? name = await _storage.read(key: 'officer_name');
    String? id = await _storage.read(key: 'officer_id');
    if (mounted) {
      setState(() {
        _officerData = {
          'full_name': name ?? 'Unknown Officer',
          'officer_id': id ?? 'ID Not Found',
          'status': 'Active',
        };
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

  void _showOfficialDetails() {
    if (_officerData == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Official Information',
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView(
                children: [
                  _buildDetailItem('Full Name', _officerData!['full_name']),
                  _buildDetailItem('Rank', _officerData!['rank']),
                  _buildDetailItem(
                    'Badge Number',
                    _officerData!['badge_number'],
                  ),
                  _buildDetailItem('Service ID', _officerData!['service_id']),
                  const Divider(height: 32),
                  _buildDetailItem('Station', _officerData!['station_name']),
                  _buildDetailItem('District', _officerData!['district']),
                  _buildDetailItem('State', _officerData!['state']),
                  const Divider(height: 32),
                  _buildDetailItem(
                    'Official Email',
                    _officerData!['official_email'],
                  ),
                  _buildDetailItem('Mobile', _officerData!['mobile_number']),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                color: Colors.black,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderIcon() {
    return Center(child: Icon(Icons.person, size: 50, color: Colors.grey[700]));
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
        // Profile Header (New Layout: Image Left, Info Right)
        Container(
          margin: const EdgeInsets.only(bottom: 40),
          child: Row(
            children: [
              // Profile Image
              Container(
                width: 100,
                height: 100,
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
                  child:
                      _officerData?['photo_path'] != null &&
                          _officerData!['photo_path'].toString().startsWith(
                            'http',
                          )
                      ? Image.network(
                          _officerData!['photo_path'],
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _buildPlaceholderIcon(),
                        )
                      : _buildPlaceholderIcon(),
                ),
              ),
              const SizedBox(width: 24),
              // Officer Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _officerData?['full_name'] ?? 'Officer',
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'ID: ${_officerData?['officer_id'] ?? 'N/A'}',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF10B981).withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.circle,
                            size: 8,
                            color: Color(0xFF10B981),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _officerData?['rank'] ?? 'ACTIVE DUTY',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF10B981),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Settings Sections
        _buildSectionHeader('Account'),
        _buildSettingsTile(
          icon: Icons.badge_outlined,
          title: 'Official Information',
          onTap: _showOfficialDetails,
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
