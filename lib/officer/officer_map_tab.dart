import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:async';
import '../services/map_service.dart';
import '../services/sos_service.dart';
import 'widgets/sos_button.dart';
import 'widgets/sos_bottom_sheet.dart';
import 'widgets/sos_alert_banner.dart';
import 'package:image_picker/image_picker.dart';
import 'face_scan_screen.dart';

class OfficerMapTab extends StatefulWidget {
  const OfficerMapTab({super.key});

  @override
  State<OfficerMapTab> createState() => _OfficerMapTabState();
}

class _OfficerMapTabState extends State<OfficerMapTab> {
  final MapController _mapController = MapController();
  final MapService _mapService = MapService();
  final SOSService _sosService = SOSService();
  final _storage = const FlutterSecureStorage();

  // Current officer location
  LatLng? _currentLocation;
  String? _currentOfficerId;

  // Map data
  Map<String, OfficerLocation> _officers = {};
  Map<String, DroneLocation> _drones = {};

  // Subscriptions
  StreamSubscription? _officersSubscription;
  StreamSubscription? _dronesSubscription;
  StreamSubscription? _sosAlertSubscription;
  Timer? _locationUpdateTimer;

  // Location tracking state
  double? _currentAccuracy;
  bool _isTrackingLocation = false;

  // SOS state
  bool _isMySosActive = false;
  Map<String, dynamic>? _currentSOSAlert;

  @override
  void initState() {
    super.initState();
    _initializeMap();
    _startLiveLocationTracking();
  }

  Future<void> _initializeMap() async {
    // Get current officer ID
    _currentOfficerId = await _storage.read(key: 'officer_id');

    // Connect to WebSocket
    await _mapService.connect();

    // Subscribe to updates
    _officersSubscription = _mapService.officersStream.listen((officers) {
      if (mounted) {
        setState(() {
          _officers = officers;
          _updateCurrentLocation();
        });
      }
    });

    _dronesSubscription = _mapService.dronesStream.listen((drones) {
      print(
        '📡 OfficerMapTab: Received drones update - ${drones.length} drones',
      );
      drones.forEach((id, drone) {
        print(
          '   - Drone $id: (${drone.lat}, ${drone.lng}), isLive: ${drone.isLive}',
        );
      });
      if (mounted) {
        setState(() {
          _drones = drones;
          print('🗺️ Map state updated with ${_drones.length} drones');
        });
      }
    });

    // Subscribe to SOS alerts
    _sosAlertSubscription = _mapService.sosAlertStream.listen((alert) {
      print('🚨 SOS Alert received in map tab');
      if (mounted && alert['officer_id'] != _currentOfficerId) {
        setState(() {
          _currentSOSAlert = alert;
        });
      }

      // Check if this is my SOS
      if (mounted && alert['officer_id'] == _currentOfficerId) {
        setState(() {
          _isMySosActive = true;
        });
      }
    });
  }

  void _updateCurrentLocation() {
    if (_currentOfficerId != null && _officers.containsKey(_currentOfficerId)) {
      final officer = _officers[_currentOfficerId!]!;
      _currentLocation = LatLng(officer.lat, officer.lng);

      // Update my SOS status
      if (officer.sosActive && !_isMySosActive) {
        setState(() {
          _isMySosActive = true;
        });
      } else if (!officer.sosActive && _isMySosActive) {
        setState(() {
          _isMySosActive = false;
        });
      }
    }
  }

  /// Start continuous live location tracking
  void _startLiveLocationTracking() {
    if (_isTrackingLocation) return;

    _isTrackingLocation = true;

    // Get initial location immediately
    _updateLiveLocation();

    // Update location every 5 seconds
    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted && _isTrackingLocation) {
        _updateLiveLocation();
      }
    });
  }

  /// Stop live location tracking
  void _stopLiveLocationTracking() {
    _isTrackingLocation = false;
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = null;
  }

  /// Update live location (called by timer)
  Future<void> _updateLiveLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      // OPTIMIZATION 1: Get last known location immediately (instant feedback)
      // This provides immediate visual feedback while waiting for fresh GPS fix
      Position? lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null && mounted) {
        setState(() {
          _currentLocation = LatLng(lastKnown.latitude, lastKnown.longitude);
          _currentAccuracy = lastKnown.accuracy;
        });
      }

      // OPTIMIZATION 2: Get fresh location with high accuracy (faster than 'best')
      // High accuracy: ~10m precision, 2-5 seconds
      // Best accuracy: ~5m precision, 20-30 seconds (too slow for UX)
      Position position =
          await Geolocator.getCurrentPosition(
            desiredAccuracy:
                LocationAccuracy.high, // Changed from 'best' to 'high'
            forceAndroidLocationManager: false,
          ).timeout(
            const Duration(seconds: 5), // Reduced from 8 to 5 seconds
            onTimeout: () {
              throw TimeoutException('GPS timeout');
            },
          );

      if (mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
          _currentAccuracy = position.accuracy;
        });
      }
    } catch (e) {
      // Silently fail - don't spam user with errors during live tracking
      print('Live location update failed: $e');
    }
  }

  /// Center map on current location
  void _centerOnCurrentLocation() {
    if (_currentLocation != null) {
      _mapController.move(_currentLocation!, 15.0);
    }
  }

  /// Build animated current location marker
  Widget _buildAnimatedCurrentLocationMarker() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 1.0),
      duration: const Duration(milliseconds: 1500),
      curve: Curves.easeOut,
      onEnd: () {
        // Restart animation by triggering rebuild
        if (mounted) setState(() {});
      },
      builder: (context, value, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Outer pulsing circle
            Container(
              width: 80 * value,
              height: 80 * value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withOpacity(0.2 * (1 - value)),
                border: Border.all(
                  color: Colors.black.withOpacity(0.4 * (1 - value)),
                  width: 2,
                ),
              ),
            ),
            // Inner dot
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _stopLiveLocationTracking();
    _officersSubscription?.cancel();
    _dronesSubscription?.cancel();
    _sosAlertSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // FlutterMap
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter:
                _currentLocation ??
                const LatLng(19.1383, 77.3210), // Default to Nanded
            initialZoom: 13.0,
            minZoom: 5.0,
            maxZoom: 18.0,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
          ),
          children: [
            // Tile Layer - CartoDB Positron (Light Mode)
            TileLayer(
              urlTemplate:
                  'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
              subdomains: const ['a', 'b', 'c', 'd'],
              userAgentPackageName: 'com.trinetra.app',
            ),

            // Accuracy Circle Layer (if available)
            if (_currentLocation != null && _currentAccuracy != null)
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: _currentLocation!,
                    radius: _currentAccuracy!,
                    useRadiusInMeter: true,
                    color: Colors.black.withOpacity(0.05),
                    borderColor: Colors.black.withOpacity(0.2),
                    borderStrokeWidth: 2,
                  ),
                ],
              ),

            // Drone Markers Layer (only real connected drones)
            MarkerLayer(markers: _buildDroneMarkers()),

            // Officer Markers Layer
            MarkerLayer(markers: _buildOfficerMarkers()),

            // Current Location Marker with Pulse Animation
            if (_currentLocation != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: _currentLocation!,
                    width: 80,
                    height: 80,
                    child: _buildAnimatedCurrentLocationMarker(),
                  ),
                ],
              ),
          ],
        ),

        // My Location Button (simplified - just centers map)
        Positioned(
          right: 24,
          bottom: 110,
          child: FloatingActionButton(
            backgroundColor: Colors.black,
            onPressed: _centerOnCurrentLocation,
            tooltip: 'Center on my location',
            child: const Icon(Icons.my_location, color: Colors.white),
          ),
        ),

        // SOS Button
        // SOS Button (Top/First)
        Positioned(
          right: 24,
          bottom: 270,
          child: SOSButton(
            isActive: _isMySosActive,
            onPressed: _handleSOSButtonPress,
          ),
        ),

        // Face Scan Button (Bottom/Second)
        Positioned(right: 24, bottom: 190, child: _buildFaceScanButton()),

        // SOS Alert Banner
        if (_currentSOSAlert != null)
          Positioned(
            top: 100,
            left: 0,
            right: 0,
            child: SOSAlertBanner(
              officerName: _currentSOSAlert!['officer_name'] as String,
              badgeNumber: _currentSOSAlert!['badge_number'] as String?,
              emergencyType: _currentSOSAlert!['emergency_type'] as String,
              message: _currentSOSAlert!['message_text'] as String?,
              sosLocation: LatLng(
                (_currentSOSAlert!['lat'] as num).toDouble(),
                (_currentSOSAlert!['lng'] as num).toDouble(),
              ),
              currentLocation: _currentLocation,
              onNavigate: () {
                _mapController.move(
                  LatLng(
                    (_currentSOSAlert!['lat'] as num).toDouble(),
                    (_currentSOSAlert!['lng'] as num).toDouble(),
                  ),
                  16.0,
                );
              },
              onDismiss: () {
                setState(() {
                  _currentSOSAlert = null;
                });
              },
            ),
          ),

        // Stats Card - Bottom Left
        Positioned(
          left: 24,
          bottom: 110, // Above bottom navigation bar
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person, size: 16, color: Colors.black),
                    const SizedBox(width: 4),
                    Text(
                      '${_officers.length}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.flight, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      '${_drones.length}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Build drone markers (only real connected drones)
  List<Marker> _buildDroneMarkers() {
    print('🎨 Building drone markers... Total drones: ${_drones.length}');

    // Filter to only show live/connected drones
    final liveDrones = _drones.values.where((drone) => drone.isLive).toList();
    print('   Live drones: ${liveDrones.length}');

    final markers = liveDrones.map((drone) {
      print(
        '   Creating marker for drone ${drone.droneId} at (${drone.lat}, ${drone.lng})',
      );
      return Marker(
        point: LatLng(drone.lat, drone.lng),
        width: 40,
        height: 40,
        child: GestureDetector(
          onTap: () => _showDroneInfo(drone),
          child: Image.asset(
            'assets/icons/drone_marker.png',
            width: 40,
            height: 40,
          ),
        ),
      );
    }).toList();

    print('✅ Created ${markers.length} drone markers');
    return markers;
  }

  /// Build officer markers (excluding current officer)
  List<Marker> _buildOfficerMarkers() {
    return _officers.values
        .where(
          (officer) =>
              officer.isOnline && officer.officerId != _currentOfficerId,
        )
        .map((officer) {
          // Use red marker for SOS, normal marker otherwise
          final markerWidget = officer.sosActive
              ? _buildSOSMarker(officer)
              : _buildNormalOfficerMarker(officer);

          return Marker(
            point: LatLng(officer.lat, officer.lng),
            width: 40,
            height: 40,
            child: GestureDetector(
              onTap: () => _showOfficerInfo(officer),
              child: markerWidget,
            ),
          );
        })
        .toList();
  }

  /// Build normal officer marker
  Widget _buildNormalOfficerMarker(OfficerLocation officer) {
    return Opacity(
      opacity: 0.7,
      child: Image.asset(
        'assets/icons/officer_marker.png',
        width: 40,
        height: 40,
      ),
    );
  }

  /// Build SOS officer marker with pulsing animation
  Widget _buildSOSMarker(OfficerLocation officer) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.8, end: 1.2),
      duration: const Duration(milliseconds: 1500),
      curve: Curves.easeOut,
      onEnd: () {
        if (mounted) setState(() {});
      },
      builder: (context, value, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Pulsing circle
            Container(
              width: 40 * value,
              height: 40 * value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFDC2626).withOpacity(0.3 * (1.2 - value)),
                border: Border.all(
                  color: const Color(
                    0xFFDC2626,
                  ).withOpacity(0.5 * (1.2 - value)),
                  width: 2,
                ),
              ),
            ),
            // Red marker icon
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFDC2626),
              ),
              child: const Icon(Icons.emergency, color: Colors.white, size: 24),
            ),
          ],
        );
      },
    );
  }

  /// Show drone information
  void _showDroneInfo(DroneLocation drone) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.flight, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        drone.nickname ?? drone.droneId,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Drone ID: ${drone.droneId}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              'Location',
              '${drone.lat.toStringAsFixed(6)}, ${drone.lng.toStringAsFixed(6)}',
            ),
            if (drone.altitude != null)
              _buildInfoRow(
                'Altitude',
                '${drone.altitude!.toStringAsFixed(1)} m',
              ),
            if (drone.speed != null)
              _buildInfoRow('Speed', '${drone.speed!.toStringAsFixed(1)} m/s'),
            if (drone.heading != null)
              _buildInfoRow('Heading', '${drone.heading!.toStringAsFixed(0)}°'),
            _buildInfoRow('Status', drone.isLive ? '🟢 Live' : '🔴 Offline'),
          ],
        ),
      ),
    );
  }

  /// Show officer information
  void _showOfficerInfo(OfficerLocation officer) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  officer.sosActive ? Icons.emergency : Icons.person,
                  size: 32,
                  color: officer.sosActive
                      ? const Color(0xFFDC2626)
                      : Colors.black,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            officer.officerName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (officer.sosActive) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDC2626),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'SOS',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (officer.badgeNumber != null)
                        Text(
                          'Badge: ${officer.badgeNumber}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              'Location',
              '${officer.lat.toStringAsFixed(6)}, ${officer.lng.toStringAsFixed(6)}',
            ),
            if (officer.accuracy != null)
              _buildInfoRow(
                'Accuracy',
                '${officer.accuracy!.toStringAsFixed(1)} m',
              ),
            _buildInfoRow(
              'Status',
              officer.isOnline ? '🟢 Online' : '🔴 Offline',
            ),
            if (officer.sosActive) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFDC2626).withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.emergency,
                          color: Color(0xFFDC2626),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'EMERGENCY ALERT',
                          style: TextStyle(
                            color: const Color(0xFFDC2626),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    if (officer.sosMessage != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        officer.sosMessage!,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  /// Handle SOS button press
  void _handleSOSButtonPress() {
    if (_isMySosActive) {
      // Cancel SOS
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cancel Emergency'),
          content: const Text(
            'Are you sure you want to cancel the emergency alert?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('No'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await _sosService.cancelSOS();
                  setState(() {
                    _isMySosActive = false;
                  });
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Emergency alert cancelled'),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to cancel SOS: $e')),
                    );
                  }
                }
              },
              child: const Text('Yes, Cancel'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    } else {
      // Trigger SOS Options
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => SOSBottomSheet(
          sosService: _sosService,
          onSOSTriggered: () {
            setState(() {
              _isMySosActive = true;
            });
          },
        ),
      );
    }
  }

  void _handleFaceScan() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const FaceScanScreen()),
    );
  }

  Widget _buildFaceScanButton() {
    return GestureDetector(
      onTap: _handleFaceScan,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black, // Distinct from red SOS
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
        ),
        child: const Icon(
          Icons.face_retouching_natural,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }
}
