// Platform detection removed as we're using a fixed IP

class NetworkConfig {
  // IMPORTANT: Update these IP addresses based on your network configuration

  // For physical iOS devices, use your computer's actual IP address on your local network
  // You can find your IP address by:
  // - On macOS: System Settings > Network > Wi-Fi > Details
  // - On Windows: Run 'ipconfig' in Command Prompt

  // Try these common local network IP patterns if you're not sure:
  static const List<String> possibleDevIps = [
    '172.16.13.142', // Current device IP address
    '127.0.0.1', // localhost (for simulators)
    '10.0.2.2', // Android emulator special IP
    '10.10.68.72', // Mac's actual IP address
    '192.168.1.5', // Common home network pattern
    '192.168.0.5', // Common home network pattern
    '10.0.0.5', // Common home network pattern
    '172.20.10.5', // Common hotspot pattern
  ];

  // Current development machine IP - CHANGE THIS to your actual IP address
  static const String devMachineIp =
      '192.168.1.90'; // Current device IP address

  // Get the base URL based on the platform
  static String getBaseUrl() {
    // Use the same IP for all platforms with port 8002
    return 'http://192.168.1.90:8002';
  }

  // Get the API URL
  static String getApiUrl() {
    // Force use of the specified IP for API calls with port 8002
    return 'http://192.168.1.90:8002/api';
  }
}
