import 'package:flutter/material.dart';
import 'package:screen_protector/screen_protector.dart';
import 'dart:io';
import '../core/widgets/creative_app_bar.dart';
import '../core/widgets/creative_bottom_nav.dart';
import '../services/officer_location_service.dart';
import '../services/map_service.dart';
import 'officer_map_tab.dart';
import 'officer_alerts_tab.dart';
import 'officer_profile_tab.dart';
import 'officer_notifications_tab.dart';

class OfficerHome extends StatefulWidget {
  const OfficerHome({super.key});

  @override
  State<OfficerHome> createState() => _OfficerHomeState();
}

class _OfficerHomeState extends State<OfficerHome> {
  final OfficerLocationService _locationService = OfficerLocationService();
  final MapService _mapService = MapService();
  bool _locationPermissionAsked = false;

  @override
  void initState() {
    super.initState();
    _secureScreen();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    // Initialize MapService WebSocket connection
    await _mapService.connect();
    print('✅ MapService connected for notifications and alerts');

    // Initialize location tracking
    await _initializeLocationTracking();
  }

  Future<void> _secureScreen() async {
    if (Platform.isAndroid) {
      await ScreenProtector.preventScreenshotOn();
    }
  }

  Future<void> _initializeLocationTracking() async {
    // Wait a bit for the screen to load
    await Future.delayed(const Duration(milliseconds: 500));

    if (!_locationPermissionAsked && mounted) {
      _locationPermissionAsked = true;
      await _requestLocationPermission();
    }
  }

  Future<void> _requestLocationPermission() async {
    bool granted = await _locationService.requestPermissions();

    if (granted) {
      // Start tracking location silently
      await _locationService.startTracking();
    } else {
      // Permission denied - show dialog
      if (mounted) {
        _showPermissionDialog();
      }
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Permission Required'),
        content: const Text(
          'Trinetra needs your location to:\n\n'
          '• Coordinate emergency response\n'
          '• Show your position to command center\n'
          '• Enable real-time tracking\n\n'
          'Please grant location permission to continue.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _requestLocationPermission();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
            ),
            child: const Text('Grant Permission'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _locationService.stopTracking();
    _mapService.disconnect();
    super.dispose();
  }

  int _currentIndex = 0;

  final List<Widget> _tabs = const [
    OfficerMapTab(),
    OfficerNotificationsTab(),
    OfficerAlertsTab(),
    OfficerProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      extendBody: true,
      extendBodyBehindAppBar: true, // For full screen map behind app bar
      appBar: CreativeAppBar(
        title: (_currentIndex == 0 || _currentIndex == 3) ? 'TRINETRA' : '',
      ),
      body: _tabs[_currentIndex],
      bottomNavigationBar: CreativeBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: [
          CreativeNavItem(icon: Icons.map_outlined, label: 'MAP'),
          CreativeNavItem(
            icon: Icons.notifications_none_rounded,
            label: 'NOTIFY',
          ),
          CreativeNavItem(icon: Icons.warning_amber_rounded, label: 'ALERTS'),
          CreativeNavItem(icon: Icons.person_outline, label: 'PROFILE'),
        ],
      ),
    );
  }
}
