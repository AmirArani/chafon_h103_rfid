class AppConstants {
  // Target RFID Reader
  static const String targetDeviceName = 'PersicaRFID';
  static const String targetDeviceMac = 'E0:4E:7A:F3:78:55';

  // Connection settings
  static const int scanTimeoutSeconds = 30;
  static const int connectionRetryDelay = 2; // seconds between retries

  // Developer mode (hidden feature)
  static const bool enableDeveloperMode = false; // Set to false to disable developer mode feature
  static const int developerModeTapCount = 5; // Number of taps to activate developer mode
}
