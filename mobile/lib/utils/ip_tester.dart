import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;

class IpTester {
  // Test if a given IP address is reachable
  static Future<Map<String, dynamic>> isIpReachableWithDetails(
    String ip, {
    int port = 8000,
    int timeout = 5,
  }) async {
    try {
      final url = 'http://$ip:$port/';
      print('Testing connection to: $url');

      final response = await http
          .get(Uri.parse(url), headers: {'Connection': 'keep-alive'})
          .timeout(Duration(seconds: timeout));

      // Even if we get a 404, it means the server is reachable
      final isReachable =
          response.statusCode >= 200 && response.statusCode < 500;

      return {
        'isReachable': isReachable,
        'statusCode': response.statusCode,
        'responseBody':
            response.body.length > 100
                ? '${response.body.substring(0, 100)}...'
                : response.body,
        'error': null,
      };
    } on SocketException catch (e) {
      print('SocketException testing IP $ip: $e');
      return {
        'isReachable': false,
        'statusCode': null,
        'responseBody': null,
        'error': 'Network error: ${e.message}',
      };
    } on TimeoutException catch (e) {
      print('TimeoutException testing IP $ip: $e');
      return {
        'isReachable': false,
        'statusCode': null,
        'responseBody': null,
        'error': 'Connection timed out',
      };
    } catch (e) {
      print('Error testing IP $ip: $e');
      return {
        'isReachable': false,
        'statusCode': null,
        'responseBody': null,
        'error': 'Error: $e',
      };
    }
  }

  // Simplified version that just returns a boolean
  static Future<bool> isIpReachable(
    String ip, {
    int port = 8000,
    int timeout = 5,
  }) async {
    final result = await isIpReachableWithDetails(
      ip,
      port: port,
      timeout: timeout,
    );
    return result['isReachable'] as bool;
  }

  // Find a working IP address from a list of candidates
  static Future<String?> findWorkingIp(
    List<String> candidates, {
    int port = 8000,
  }) async {
    for (final ip in candidates) {
      print('Testing IP: $ip');
      final result = await isIpReachableWithDetails(ip, port: port);

      if (result['isReachable']) {
        print('Found working IP: $ip (Status: ${result['statusCode']})');
        return ip;
      } else {
        print('IP $ip not reachable: ${result['error'] ?? "Unknown error"}');
      }
    }
    return null;
  }

  // Get the local IP address of the device
  static Future<String?> getLocalIpAddress() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );

      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          // Skip loopback addresses
          if (!addr.isLoopback) {
            return addr.address;
          }
        }
      }
    } catch (e) {
      print('Error getting local IP: $e');
    }
    return null;
  }

  // Test if the Django server is running and accessible
  static Future<Map<String, dynamic>> testDjangoServer(
    String ip, {
    int port = 8000,
  }) async {
    try {
      // Try to access a known Django endpoint
      final urls = [
        'http://$ip:$port/api/laboratoires/',
        'http://$ip:$port/api/users/login/',
        'http://$ip:$port/admin/',
        'http://$ip:$port/',
      ];

      for (final url in urls) {
        try {
          final response = await http
              .get(Uri.parse(url), headers: {'Connection': 'keep-alive'})
              .timeout(const Duration(seconds: 3));

          // If we get any response, the server is running
          return {
            'isRunning': true,
            'url': url,
            'statusCode': response.statusCode,
            'responseBody':
                response.body.length > 100
                    ? '${response.body.substring(0, 100)}...'
                    : response.body,
            'error': null,
          };
        } catch (e) {
          // Continue to the next URL
          print('Error testing URL $url: $e');
        }
      }

      // If we've tried all URLs and none worked
      return {
        'isRunning': false,
        'url': null,
        'statusCode': null,
        'responseBody': null,
        'error': 'Could not connect to any Django endpoints',
      };
    } catch (e) {
      return {
        'isRunning': false,
        'url': null,
        'statusCode': null,
        'responseBody': null,
        'error': 'Error: $e',
      };
    }
  }
}
