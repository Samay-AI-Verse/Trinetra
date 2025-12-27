class ApiConfig {
  // TODO: Replace this with your ngrok URL after running: ngrok http 8000
  // Example: 'https://abc123.ngrok-free.app'
  static const String baseUrl =
      'https://overprosperous-aviana-nontextually.ngrok-free.dev';

  // API Endpoints
  static const String sendOtp = '$baseUrl/api/send-otp';
  static const String verifyOtp = '$baseUrl/api/verify-otp';
  static const String register = '$baseUrl/api/register';
  static const String checkDevice = '$baseUrl/api/check-device';
  static const String bindDevice = '$baseUrl/api/officer/bind-device';
  static const String validateDevice = '$baseUrl/api/officer/validate-device';
  static const String resetDevice = '$baseUrl/api/officer/reset-device';

  // Officer Location Tracking
  static String officerLocation(String officerId) =>
      '$baseUrl/api/officers/$officerId/location';
  static String officerStatus(String officerId) =>
      '$baseUrl/api/officers/$officerId/status';

  // Drone endpoints
  static const String drones = '$baseUrl/api/drones';

  // WebSocket Endpoints
  static String get wsLocations =>
      baseUrl
          .replaceFirst('https://', 'wss://')
          .replaceFirst('http://', 'ws://') +
      '/ws/locations';
  static String get wsVideoFeed =>
      baseUrl
          .replaceFirst('https://', 'wss://')
          .replaceFirst('http://', 'ws://') +
      '/ws/video/feed';
  static String get wsVideoUpload =>
      baseUrl
          .replaceFirst('https://', 'wss://')
          .replaceFirst('http://', 'ws://') +
      '/ws/video/upload';

  // Timeout configurations
  static const Duration connectionTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 30);
}
