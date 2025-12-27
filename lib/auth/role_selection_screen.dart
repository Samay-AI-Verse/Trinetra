import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'registration_flow.dart';
import 'officer_auth_status.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  Future<void> _handleOfficerTap(BuildContext context) async {
    const storage = FlutterSecureStorage();
    String? officerId = await storage.read(key: 'officer_id');

    if (context.mounted) {
      if (officerId != null) {
        // Returning user - go directly to device binding (OTP + PIN)
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const DeviceBindingScreen()),
        );
      } else {
        // New user - show full registration
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const RegistrationFlow()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 60),
              // Brand Header
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.security,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'TRINETRA',
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Intelligent\\nSurveillance Node',
                style: GoogleFonts.inter(
                  fontSize: 40,
                  height: 1.1,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  letterSpacing: -1.5,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Select your operational mode to begin.',
                style: GoogleFonts.inter(fontSize: 16, color: Colors.grey[600]),
              ),
              const Spacer(),
              _MinimalistCard(
                title: 'OFFICER',
                subtitle: 'Command & Control',
                icon: Icons.admin_panel_settings_outlined,
                isActive: true,
                onTap: () => _handleOfficerTap(context),
              ),
              const SizedBox(height: 16),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}

class _MinimalistCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _MinimalistCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Fixed: Use Material to ensure InkWell ripple is visible
    return Material(
      color: isActive ? Colors.black : Colors.grey[100],
      borderRadius: BorderRadius.circular(16),
      elevation: isActive ? 10 : 0,
      shadowColor: isActive
          ? Colors.black.withOpacity(0.3)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            // Removed color here to allow Material color to show
            border: isActive ? null : Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.white.withOpacity(0.1)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 28,
                  color: isActive ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isActive ? Colors.white : Colors.black,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: isActive ? Colors.white70 : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward,
                color: isActive ? Colors.white : Colors.black,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
