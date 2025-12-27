import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:screen_protector/screen_protector.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'officer_auth_status.dart'; // Import the pending/auth status screen
import '../core/config/api_config.dart';

class RegistrationFlow extends StatefulWidget {
  const RegistrationFlow({super.key});

  @override
  State<RegistrationFlow> createState() => _RegistrationFlowState();
}

class _RegistrationFlowState extends State<RegistrationFlow> {
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

  final PageController _pageController = PageController();
  int _currentStep = 0;
  final _storage = const FlutterSecureStorage();

  // Step 1: Identity & Verification
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();

  // Step 2: Police Details
  final TextEditingController _badgeController = TextEditingController();
  final TextEditingController _rankController = TextEditingController();
  final TextEditingController _stationController = TextEditingController();
  final TextEditingController _districtController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _serviceIdController = TextEditingController();

  // Step 3: Photo & Docs
  File? _officerPhoto;
  File? _idCardPhoto;
  final ImagePicker _picker = ImagePicker();

  // Step 4: Review & Submit
  bool _termsAccepted = false;
  bool _otpVerified = false;
  bool _isSubmitting = false;
  bool _isSendingOtp = false;

  Future<void> _pickImage(ImageSource source, int type) async {
    try {
      final pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          if (type == 0) _officerPhoto = File(pickedFile.path);
          if (type == 1) _idCardPhoto = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open camera/gallery: $e')),
        );
      }
    }
  }

  void _showImageSourceDialog(int type) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Select Image Source',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera, type);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery, type);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendOtp() async {
    if (_mobileController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter mobile number')),
      );
      return;
    }
    setState(() => _isSendingOtp = true);
    try {
      var response = await http
          .post(
            Uri.parse(
              '${ApiConfig.sendOtp}?mobile_number=${_mobileController.text}',
            ),
          )
          .timeout(
            ApiConfig.connectionTimeout,
            onTimeout: () => throw TimeoutException('Request timed out'),
          );
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      '🔐 Verification code dispatched to your device',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green[700],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('⚠️ Unable to send code: $e')),
              ],
            ),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      setState(() => _isSendingOtp = false);
    }
  }

  Future<void> _verifyOtp() async {
    if (_otpController.text.isEmpty) return;
    try {
      var response = await http
          .post(
            Uri.parse(ApiConfig.verifyOtp),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'mobile_number': _mobileController.text,
              'otp': _otpController.text,
            }),
          )
          .timeout(
            ApiConfig.connectionTimeout,
            onTimeout: () => throw TimeoutException('Request timed out'),
          );
      if (response.statusCode == 200) {
        setState(() => _otpVerified = true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.verified, color: Colors.white),
                  const SizedBox(width: 12),
                  const Text('✅ Identity confirmed successfully'),
                ],
              ),
              backgroundColor: Colors.green[700],
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        throw Exception('Invalid OTP');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Verification Failed: $e')));
      }
    }
  }

  Future<void> _submitRegistration() async {
    if (!_otpVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please verify your mobile number first')),
      );
      return;
    }
    if (!_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please accept terms and conditions')),
      );
      return;
    }

    if (_officerPhoto == null || _idCardPhoto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload both Officer Photo and ID Card'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiConfig.register),
      );

      request.fields.addAll({
        'full_name': _fullNameController.text,
        'mobile_number': _mobileController.text,
        'official_email': _emailController.text,
        'dob': _dobController.text,
        'badge_number': _badgeController.text,
        'rank': _rankController.text,
        'station_name': _stationController.text,
        'district': _districtController.text,
        'state': _stateController.text,
        'service_id': _serviceIdController.text,
      });

      if (_officerPhoto != null) {
        request.files.add(
          await http.MultipartFile.fromPath('photo', _officerPhoto!.path),
        );
      }
      if (_idCardPhoto != null) {
        request.files.add(
          await http.MultipartFile.fromPath('id_card', _idCardPhoto!.path),
        );
      }

      var response = await request.send().timeout(
        ApiConfig.receiveTimeout,
        onTimeout: () => throw TimeoutException('Upload timed out'),
      );

      if (response.statusCode == 200) {
        var responseData = await response.stream.bytesToString();
        var jsonResponse = json.decode(responseData);

        await _storage.write(key: 'registration_status', value: 'Pending');
        await _storage.write(
          key: 'request_id',
          value: jsonResponse['request_id'],
        );

        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => const PendingStatusScreen(),
            ),
            (route) => false,
          );
        }
      } else {
        var errorData = await response.stream.bytesToString();
        throw Exception('Server Error: $errorData');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submission Failed: ${e.toString()}')),
        );
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Officer Registration',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildProgressBar(),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStep1(),
                _buildStep2(),
                _buildStep3(),
                _buildStep4(),
              ],
            ),
          ),
          _buildNavigationButtons(),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: List.generate(4, (index) {
          return Expanded(
            child: Container(
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: index <= _currentStep ? Colors.black : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStep1() {
    return _buildStepContainer(
      title: 'Identity & Verification',
      subtitle: 'Enter your official details and verify your mobile number.',
      children: [
        _buildTextField(_fullNameController, 'Full Name', Icons.person),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                _mobileController,
                'Mobile Number',
                Icons.phone,
                keyboardType: TextInputType.phone,
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: ElevatedButton(
                onPressed: _otpVerified ? null : _sendOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSendingOtp
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(_otpVerified ? 'Verified' : 'Send OTP'),
              ),
            ),
          ],
        ),
        if (!_otpVerified)
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  _otpController,
                  'Enter 6-digit OTP',
                  Icons.lock_clock,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: ElevatedButton(
                  onPressed: _verifyOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Verify'),
                ),
              ),
            ],
          ),
        _buildTextField(
          _emailController,
          'Official Email ID',
          Icons.email,
          keyboardType: TextInputType.emailAddress,
        ),
        _buildTextField(
          _dobController,
          'Date of Birth (DD/MM/YYYY)',
          Icons.calendar_today,
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return _buildStepContainer(
      title: 'Police Verification',
      subtitle: 'Details of your current posting and service.',
      children: [
        _buildTextField(_badgeController, 'Badge Number', Icons.badge),
        _buildTextField(
          _rankController,
          'Rank (e.g. SI, Inspector)',
          Icons.workspace_premium,
        ),
        _buildTextField(
          _stationController,
          'Police Station Name',
          Icons.account_balance,
        ),
        _buildTextField(_districtController, 'District', Icons.location_city),
        _buildTextField(_stateController, 'State', Icons.map),
        _buildTextField(
          _serviceIdController,
          'Employee / Service ID',
          Icons.sd_card,
        ),
      ],
    );
  }

  Widget _buildStep3() {
    return _buildStepContainer(
      title: 'Photo & Documents',
      subtitle: 'Upload required documents for verification.',
      children: [
        _buildFilePicker(
          'Live Officer Photo',
          _officerPhoto,
          () => _showImageSourceDialog(0),
        ),
        _buildFilePicker(
          'Police ID Card Photo',
          _idCardPhoto,
          () => _showImageSourceDialog(1),
        ),
      ],
    );
  }

  Widget _buildStep4() {
    return _buildStepContainer(
      title: 'Review & Submit',
      subtitle: 'Verify all details before final submission.',
      children: [
        _buildReviewItem('Full Name', _fullNameController.text),
        _buildReviewItem('Mobile', _mobileController.text),
        _buildReviewItem('Badge Number', _badgeController.text),
        _buildReviewItem('Rank', _rankController.text),
        _buildReviewItem('Station', _stationController.text),
        const SizedBox(height: 24),
        CheckboxListTile(
          title: Text(
            'I accept the official usage policies and terms.',
            style: GoogleFonts.outfit(fontSize: 14),
          ),
          value: _termsAccepted,
          onChanged: (val) => setState(() => _termsAccepted = val!),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.withOpacity(0.5)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.amber),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Once submitted, HQ will verify your credentials. You will receive an OTP for device binding after approval.',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepContainer({
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 32),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool obscure = false,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        style: GoogleFonts.outfit(color: Colors.black),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.outfit(color: Colors.grey[600]),
          prefixIcon: Icon(icon, color: Colors.black, size: 20),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.black12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.black, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildFilePicker(String label, File? file, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(12),
            color: Colors.grey[50],
          ),
          child: Row(
            children: [
              Icon(
                file == null ? Icons.cloud_upload : Icons.check_circle,
                color: file == null ? Colors.black : Colors.green,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  file == null ? label : 'File Uploaded',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w500),
                ),
              ),
              if (file != null)
                const Icon(Icons.edit, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReviewItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.outfit(color: Colors.grey[600])),
          Text(value, style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentStep > 0)
            TextButton(
              onPressed: () {
                _pageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
                setState(() => _currentStep--);
              },
              child: Text(
                'Back',
                style: GoogleFonts.outfit(color: Colors.grey),
              ),
            )
          else
            const SizedBox.shrink(),
          ElevatedButton(
            onPressed: _isSubmitting
                ? null
                : () {
                    if (_currentStep < 3) {
                      if (_currentStep == 0 && !_otpVerified) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please verify OTP first'),
                          ),
                        );
                        return;
                      }
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                      setState(() => _currentStep++);
                    } else {
                      _submitRegistration();
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    _currentStep == 3 ? 'Submit Request' : 'Next',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
    );
  }
}
