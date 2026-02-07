import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'auth/role_selection_screen.dart';
import 'auth/registration_flow.dart';
import 'auth/officer_auth_status.dart';
import 'officer/officer_home.dart';
import 'core/config/api_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  try {
    await Firebase.initializeApp();
    print('✅ Firebase initialized successfully');
  } catch (e) {
    print('❌ Firebase initialization failed: $e');
  }

  runApp(const TrinetraApp());
}

class TrinetraApp extends StatelessWidget {
  const TrinetraApp({super.key});

  Future<Widget> _getInitialScreen() async {
    const storage = FlutterSecureStorage();

    // First, check local storage
    String? isBound = await storage.read(key: 'is_bound');
    String? registrationStatus = await storage.read(key: 'registration_status');
    String? officerId = await storage.read(key: 'officer_id');

    if (isBound == 'true') {
      // Device is bound - go directly to Officer Home (no PIN required)
      return const OfficerHome();
    } else if (registrationStatus == 'Pending') {
      // Registration submitted, waiting for approval
      return const PendingStatusScreen();
    } else if (officerId != null) {
      // Logged out but registered - show device binding
      return const DeviceBindingScreen();
    } else {
      // Check if this device is registered in backend (for reinstalls)
      try {
        final deviceId = await _getDeviceId();

        var response = await http
            .post(
              Uri.parse(ApiConfig.checkDevice),
              headers: {'Content-Type': 'application/json'},
              body: json.encode({'device_id': deviceId}),
            )
            .timeout(
              ApiConfig.connectionTimeout,
              onTimeout: () {
                // If timeout, just proceed to role selection
                print('Device check timed out - proceeding to role selection');
                throw TimeoutException('Device check timed out');
              },
            );

        if (response.statusCode == 200) {
          var data = json.decode(response.body);
          if (data['registered'] == true) {
            // Device is registered! Go directly to Device Binding (OTP + PIN setup)
            return const DeviceBindingScreen();
          }
        }
      } catch (e) {
        // If check fails, proceed to role selection
        print('Device check error: $e');
      }

      // First time launch - show role selection
      return const RoleSelectionScreen();
    }
  }

  Future<String> _getDeviceId() async {
    var deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      var androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id;
    } else if (Platform.isIOS) {
      var iosInfo = await deviceInfo.iosInfo;
      return iosInfo.identifierForVendor ?? 'unknown_ios';
    }
    return 'unknown_device';
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trinetra',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: Colors.black,
        scaffoldBackgroundColor: Colors.white,
        textTheme: GoogleFonts.outfitTextTheme(),
      ),
      themeMode: ThemeMode.light,
      routes: {
        '/role_selection': (context) => const RoleSelectionScreen(),
        '/registration': (context) => const RegistrationFlow(),
        '/pending_status': (context) => const PendingStatusScreen(),
        '/device_binding': (context) => const DeviceBindingScreen(),
        '/dashboard': (context) => const OfficerHome(),
      },
      home: FutureBuilder<Widget>(
        future: _getInitialScreen(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(color: Colors.black),
              ),
            );
          }
          return snapshot.data ?? const RoleSelectionScreen();
        },
      ),
    );
  }
}
