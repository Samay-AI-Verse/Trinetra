import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'package:screen_protector/screen_protector.dart';
import '../officer/officer_home.dart';
import '../core/config/api_config.dart';

// ----------------- SCREEN 1: PENDING STATUS -----------------
class PendingStatusScreen extends StatefulWidget {
  const PendingStatusScreen({super.key});

  @override
  State<PendingStatusScreen> createState() => _PendingStatusScreenState();
}

class _PendingStatusScreenState extends State<PendingStatusScreen> {
  @override
  void initState() {
    super.initState();
    // Prevent screenshots on sensitive screens
    _secureScreen();
  }

  Future<void> _secureScreen() async {
    if (Platform.isAndroid) {
      await ScreenProtector.preventScreenshotOn();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        padding: const EdgeInsets.all(32),
        width: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.verified_user_outlined,
              size: 80,
              color: Colors.black,
            ),
            const SizedBox(height: 24),
            Text(
              'Registration Submitted',
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Your details are under verification by HQ.\n\nYou will receive an official notification once approved. After that, you can proceed to bind this device.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(color: Colors.grey[700]),
            ),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DeviceBindingScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'I have been Approved',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------- SCREEN 2: DEVICE BINDING -----------------
class DeviceBindingScreen extends StatefulWidget {
  const DeviceBindingScreen({super.key});

  @override
  State<DeviceBindingScreen> createState() => _DeviceBindingScreenState();
}

class _DeviceBindingScreenState extends State<DeviceBindingScreen> {
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _resetMobileController = TextEditingController();
  final TextEditingController _resetOtpController = TextEditingController();
  final TextEditingController _badgeController = TextEditingController();
  final _storage = const FlutterSecureStorage();

  bool _isSendingOtp = false;
  bool _isVerifying = false;
  bool _isResetting = false;
  bool _otpSent = false;
  bool _otpVerified = false;
  String? _officerId; // Keep this for display after verification

  @override
  void initState() {
    super.initState();
    _secureScreen();
  }

  Future<void> _secureScreen() async {
    if (Platform.isAndroid) {
      await ScreenProtector.preventScreenshotOn();
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
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

  Future<void> _sendOtp() async {
    if (_mobileController.text.isEmpty) {
      _showError('Please enter mobile number');
      return;
    }
    setState(() => _isSendingOtp = true);
    try {
      var response = await http
          .post(
            Uri.parse(
              '${ApiConfig.sendOtp}?mobile_number=${_mobileController.text.trim()}',
            ),
          )
          .timeout(
            ApiConfig.connectionTimeout,
            onTimeout: () => throw TimeoutException('Request timed out'),
          );
      if (response.statusCode == 200) {
        setState(() => _otpSent = true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.send, color: Colors.white),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      '📨 Secure code sent to your registered number',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.blue[700],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      } else {
        var error = json.decode(response.body);
        throw Exception(error['detail'] ?? 'Failed to send OTP');
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      setState(() => _isSendingOtp = false);
    }
  }

  Future<void> _verifyOtp() async {
    if (_otpController.text.isEmpty) {
      _showError('Please enter OTP');
      return;
    }
    setState(() => _isVerifying = true);
    try {
      // Verify OTP to get officer_id
      var verifyResponse = await http
          .post(
            Uri.parse(ApiConfig.verifyOtp),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'mobile_number': _mobileController.text.trim(),
              'otp': _otpController.text.trim(),
            }),
          )
          .timeout(
            ApiConfig.connectionTimeout,
            onTimeout: () => throw TimeoutException('Request timed out'),
          );

      if (verifyResponse.statusCode == 200) {
        var verifyData = json.decode(verifyResponse.body);
        if (verifyData['registered'] == true) {
          String? officerId = verifyData['officer_id'];
          setState(() {
            _otpVerified = true;
            _officerId = officerId;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.verified, color: Colors.white),
                    const SizedBox(width: 12),
                    const Text('✅ OTP Verified! Now set your PIN'),
                  ],
                ),
                backgroundColor: Colors.green[700],
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } else {
          throw Exception(
            'Approval pending or not registered with this number',
          );
        }
      } else {
        var error = json.decode(verifyResponse.body);
        throw Exception(error['detail'] ?? 'Invalid OTP');
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      setState(() => _isVerifying = false);
    }
  }

  Future<void> _bindDevice() async {
    if (_pinController.text.length < 4) {
      _showError('PIN must be at least 4 digits');
      return;
    }

    setState(() => _isVerifying = true);
    try {
      // Bind device with the verified officer_id
      String deviceId = await _getDeviceId();
      var bindResponse = await http
          .post(
            Uri.parse(ApiConfig.bindDevice),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'officer_id': _officerId,
              'otp': _otpController.text.trim(),
              'device_id': deviceId,
            }),
          )
          .timeout(
            ApiConfig.connectionTimeout,
            onTimeout: () => throw TimeoutException('Request timed out'),
          );

      if (bindResponse.statusCode == 200) {
        var bindData = json.decode(bindResponse.body);

        // Save local security data
        await _storage.write(key: 'is_bound', value: 'true');
        await _storage.write(
          key: 'officer_id',
          value: bindData['officer']['officer_id'],
        );
        await _storage.write(
          key: 'officer_name',
          value: bindData['officer']['full_name'],
        );
        await _storage.write(
          key: 'local_pin',
          value: _pinController.text.trim(),
        );
        await _storage.write(key: 'device_id', value: deviceId);

        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const OfficerHome()),
            (route) => false,
          );
        }
      } else {
        var error = json.decode(bindResponse.body);
        String detail = error['detail'] ?? 'Binding failed';
        _showError(detail);

        if (bindResponse.statusCode == 403 &&
            detail.contains("already bound")) {
          _showDeviceResetDialog();
        }
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      setState(() => _isVerifying = false);
    }
  }

  void _showDeviceResetDialog() {
    _resetMobileController.text = _mobileController.text; // Pre-fill mobile
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recover / Reset Device',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.redAccent,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Lost your previous device? Verify details to unlink it and bind this new device.',
              style: GoogleFonts.outfit(color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _badgeController,
              decoration: InputDecoration(
                labelText: 'Enter Badge Number',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _resetOtpController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Enter OTP (sent to ${_resetMobileController.text})',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isResetting
                    ? null
                    : () async {
                        Navigator.pop(context); // Close sheet
                        await _resetDevice();
                      },
                icon: _isResetting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.warning_amber_rounded),
                label: Text(
                  _isResetting
                      ? 'Resetting...'
                      : 'Confirm Reset & Unlink Old Device',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _resetDevice() async {
    if (_resetOtpController.text.isEmpty || _badgeController.text.isEmpty) {
      _showError('Please fill all fields for reset.');
      return;
    }
    setState(() => _isResetting = true);
    try {
      var response = await http
          .post(
            Uri.parse(ApiConfig.resetDevice),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'mobile_number': _resetMobileController.text.trim(),
              'otp': _resetOtpController.text.trim(),
              'badge_number': _badgeController.text.trim(),
            }),
          )
          .timeout(
            ApiConfig.connectionTimeout,
            onTimeout: () => throw TimeoutException('Request timed out'),
          );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Device Unlinked Successfully. Please Click "Activate" again to bind THIS device.',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        var error = json.decode(response.body);
        throw Exception(error['detail'] ?? 'Reset failed');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reset Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isResetting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Device Activation',
          style: GoogleFonts.outfit(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const Icon(Icons.phonelink_lock, size: 64, color: Colors.black),
            const SizedBox(height: 24),
            Text(
              'Secure Device Binding',
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Verify your mobile and set a local access PIN to secure this application on this device.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(color: Colors.grey[600]),
            ),
            const SizedBox(height: 40),

            // Step 1: Mobile Input
            if (!_otpVerified) ...[
              TextField(
                controller: _mobileController,
                enabled: !_otpSent,
                keyboardType: TextInputType.phone,
                style: GoogleFonts.outfit(),
                decoration: InputDecoration(
                  labelText: 'Registered Mobile Number',
                  prefixIcon: const Icon(Icons.phone),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (!_otpSent)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSendingOtp ? null : _sendOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSendingOtp
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            'Send OTP',
                            style: GoogleFonts.outfit(color: Colors.white),
                          ),
                  ),
                ),
            ],

            // Step 2: OTP Entry
            if (_otpSent && !_otpVerified) ...[
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                style: GoogleFonts.outfit(),
                decoration: InputDecoration(
                  labelText: 'Enter 6-Digit OTP',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isVerifying ? null : _verifyOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isVerifying
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          'Verify OTP',
                          style: GoogleFonts.outfit(color: Colors.white),
                        ),
                ),
              ),
            ],

            // Step 3: Local PIN Setup
            if (_otpVerified) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 12),
                    Text(
                      'Verified: $_officerId',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                style: GoogleFonts.outfit(),
                decoration: InputDecoration(
                  labelText: 'Set Local Access PIN',
                  hintText: '4-6 digits',
                  prefixIcon: const Icon(Icons.security),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isVerifying ? null : _bindDevice,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isVerifying
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          'Activate & Bind Device',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              // Manual "Device Lost" Trigger
              TextButton(
                onPressed: _showDeviceResetDialog,
                child: Text(
                  'Lost previous device? Unlink it here.',
                  style: GoogleFonts.outfit(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ----------------- SCREEN 3: LOCAL AUTH (PIN / BIOMETRIC) -----------------
class LocalAuthScreen extends StatefulWidget {
  const LocalAuthScreen({super.key});

  @override
  State<LocalAuthScreen> createState() => _LocalAuthScreenState();
}

class _LocalAuthScreenState extends State<LocalAuthScreen> {
  final TextEditingController _pinController = TextEditingController();
  final _storage = const FlutterSecureStorage();
  bool _isLoading = false;
  String? _officerName;

  @override
  void initState() {
    super.initState();
    _loadOfficerData();
    _secureScreen();
  }

  Future<void> _secureScreen() async {
    if (Platform.isAndroid) {
      await ScreenProtector.preventScreenshotOn();
    }
  }

  Future<void> _loadOfficerData() async {
    String? name = await _storage.read(key: 'officer_name');
    setState(() => _officerName = name);
  }

  Future<void> _verifyLocalPin() async {
    String? storedPin = await _storage.read(key: 'local_pin');
    if (_pinController.text == storedPin) {
      // PIN Correct. Now verify device binding with backend for extra security
      _verifyDeviceBinding();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Incorrect PIN')));
      }
    }
  }

  Future<void> _verifyDeviceBinding() async {
    setState(() => _isLoading = true);
    try {
      String? officerId = await _storage.read(key: 'officer_id');
      String? deviceId = await _storage.read(key: 'device_id');

      var response = await http
          .post(
            Uri.parse(ApiConfig.validateDevice),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'officer_id': officerId, 'device_id': deviceId}),
          )
          .timeout(
            ApiConfig.connectionTimeout,
            onTimeout: () => throw TimeoutException('Request timed out'),
          );

      if (response.statusCode == 200) {
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const OfficerHome()),
            (route) => false,
          );
        }
      } else {
        throw Exception('Unauthorized device or session expired');
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Access Denied'),
            content: Text(
              'Device binding invalid: $e\n\nPlease contact HQ for re-binding.',
            ),
            actions: [
              TextButton(
                onPressed: () => exit(0),
                child: const Text('Exit App'),
              ),
            ],
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_person, size: 80, color: Colors.black),
              const SizedBox(height: 32),
              Text(
                'Welcome Back',
                style: GoogleFonts.outfit(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -1,
                ),
              ),
              if (_officerName != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _officerName!,
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              const SizedBox(height: 64),
              TextField(
                controller: _pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                autofocus: true,
                style: GoogleFonts.outfit(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 12,
                ),
                decoration: InputDecoration(
                  hintText: '● ● ● ● ● ●',
                  hintStyle: GoogleFonts.outfit(
                    fontSize: 32,
                    letterSpacing: 12,
                    color: Colors.grey[300],
                  ),
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Colors.black, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding: const EdgeInsets.symmetric(vertical: 24),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verifyLocalPin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Unlock',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
