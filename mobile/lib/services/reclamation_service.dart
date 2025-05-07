import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/network_config.dart';

class ReclamationService {
  // Base URL for API - dynamically set based on platform
  late final String baseUrl;

  ReclamationService() {
    baseUrl = NetworkConfig.getBaseUrl();
    print('ReclamationService initialized with baseUrl: $baseUrl');

    // Check token on initialization
    _checkToken();
  }

  // Check token validity and print details
  Future<void> _checkToken() async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      print('DEBUG - Token is null or empty');
      return;
    }

    try {
      // Split the token into parts
      final parts = token.split('.');
      if (parts.length != 3) {
        print('DEBUG - Invalid token format');
        return;
      }

      // Decode the payload (middle part)
      String normalizedPayload = base64Url.normalize(parts[1]);
      final payloadJson = utf8.decode(base64Url.decode(normalizedPayload));
      final payload = jsonDecode(payloadJson);

      // Extract and print expiration time
      if (payload.containsKey('exp')) {
        final expTimestamp = payload['exp'];
        final expDate = DateTime.fromMillisecondsSinceEpoch(
          expTimestamp * 1000,
        );
        final now = DateTime.now();

        print('DEBUG - Token expiration: $expDate');
        print('DEBUG - Current time: $now');
        print('DEBUG - Token is ${expDate.isAfter(now) ? 'valid' : 'expired'}');

        // Calculate time until expiration
        final difference = expDate.difference(now);
        print('DEBUG - Time until expiration: ${difference.inMinutes} minutes');
      } else {
        print('DEBUG - Token does not contain expiration time');
      }
    } catch (e) {
      print('DEBUG - Error decoding token: $e');
    }
  }

  // Get token from shared preferences
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    print('DEBUG - Access Token: $token');

    // Also print refresh token for debugging
    final refreshToken = prefs.getString('refresh_token');
    print('DEBUG - Refresh Token: $refreshToken');

    return token;
  }

  // Check token validity
  Future<bool> checkToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null || token.isEmpty) {
        print('DEBUG - No token available');
        return false;
      }

      print('DEBUG - Current token: $token');

      // Decode the token to check expiration
      try {
        // Split the token into parts
        final parts = token.split('.');
        if (parts.length != 3) {
          print('DEBUG - Invalid token format');
          return false;
        }

        // Decode the payload (middle part)
        String normalizedPayload = base64Url.normalize(parts[1]);
        final payloadJson = utf8.decode(base64Url.decode(normalizedPayload));
        final payload = jsonDecode(payloadJson);

        // Extract expiration time
        if (payload.containsKey('exp')) {
          final expTimestamp = payload['exp'];
          final expDate = DateTime.fromMillisecondsSinceEpoch(
            expTimestamp * 1000,
          );
          final now = DateTime.now();

          // Check if token is expired
          final isValid = expDate.isAfter(now);
          print('DEBUG - Token is ${isValid ? 'valid' : 'expired'}');

          // Also print user ID from token for debugging
          if (payload.containsKey('user_id')) {
            print('DEBUG - Token user_id: ${payload['user_id']}');
          }

          return isValid;
        } else {
          print('DEBUG - Token does not contain expiration time');
          return false;
        }
      } catch (e) {
        print('DEBUG - Error decoding token: $e');
        return false;
      }
    } catch (e) {
      print('DEBUG - Error checking token: $e');
      return false;
    }
  }

  // Get all reclamations
  Future<List<dynamic>> getAllReclamations() async {
    try {
      final token = await _getToken();
      if (token == null) {
        print('DEBUG - getAllReclamations: Not authenticated');
        throw Exception('Not authenticated');
      }

      print(
        'DEBUG - getAllReclamations: Making request to $baseUrl/api/reclamations/',
      );
      print('DEBUG - getAllReclamations: Using token: $token');

      final response = await http.get(
        Uri.parse('$baseUrl/api/reclamations/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print(
        'DEBUG - getAllReclamations: Response status: ${response.statusCode}',
      );
      print('DEBUG - getAllReclamations: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('DEBUG - getAllReclamations: Parsed ${data.length} reclamations');

        // Print details of each reclamation
        for (var i = 0; i < data.length && i < 3; i++) {
          print(
            'DEBUG - getAllReclamations: Reclamation $i: ${jsonEncode(data[i])}',
          );
        }

        return data;
      } else if (response.statusCode == 401) {
        print('DEBUG - getAllReclamations: Authentication failed');
        throw Exception('Authentication required. Please log in again.');
      } else {
        print(
          'DEBUG - getAllReclamations: Failed with status ${response.statusCode}',
        );
        throw Exception('Failed to load reclamations: ${response.body}');
      }
    } catch (e) {
      print('DEBUG - getAllReclamations: Error: $e');
      rethrow;
    }
  }

  // Get user reclamations
  Future<List<dynamic>> getUserReclamations(int userId) async {
    try {
      // First try with current token
      final token = await _getToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      print('DEBUG - Fetching reclamations for user ID: $userId');
      // Try the main endpoint first, which should return the user's reclamations
      // when authenticated
      final url = '$baseUrl/api/reclamations/';
      print('DEBUG - Request URL: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print(
        'DEBUG - User reclamations response status: ${response.statusCode}',
      );
      print('DEBUG - User reclamations response body: ${response.body}');

      // If token is expired, handle the error
      if (response.statusCode == 401) {
        print('DEBUG - Token expired, authentication required');
        throw Exception('Authentication required. Please log in again.');
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('DEBUG - Parsed ${data.length} reclamations for user');
        return data;
      } else if (response.statusCode == 404 || response.statusCode == 403) {
        // If user-specific endpoint fails, try the main endpoint and filter client-side
        print('DEBUG - User-specific endpoint failed, trying main endpoint');

        final mainResponse = await http.get(
          Uri.parse('$baseUrl/api/reclamations/'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );

        print(
          'DEBUG - Main endpoint response status: ${mainResponse.statusCode}',
        );

        if (mainResponse.statusCode == 200) {
          final allData = jsonDecode(mainResponse.body);
          print('DEBUG - Received ${allData.length} total reclamations');

          // Filter for this user's reclamations
          final userReclamations =
              allData
                  .where((r) => r['user'] == userId || r['user_id'] == userId)
                  .toList();

          print(
            'DEBUG - Filtered to ${userReclamations.length} user reclamations',
          );
          return userReclamations;
        } else {
          throw Exception(
            'Failed to load reclamations from main endpoint: ${mainResponse.body}',
          );
        }
      } else {
        throw Exception('Failed to load user reclamations: ${response.body}');
      }
    } catch (e) {
      print('DEBUG - Error in getUserReclamations: $e');
      rethrow;
    }
  }

  // Get reclamations by status
  Future<List<dynamic>> getReclamationsByStatus(String status) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/api/reclamations/status/$status/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(
        'Failed to load reclamations by status: ${response.body}',
      );
    }
  }

  // Get all laboratories
  Future<List<dynamic>> getAllLaboratories() async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    print('DEBUG - Making request to: $baseUrl/api/laboratoires/');
    print('DEBUG - Using token: $token');

    final response = await http.get(
      Uri.parse('$baseUrl/api/laboratoires/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    print('DEBUG - Response status code: ${response.statusCode}');
    print('DEBUG - Response body: ${response.body}');

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load laboratories: ${response.body}');
    }
  }

  // Get PCs by laboratory
  Future<List<dynamic>> getPCsByLaboratory(int laboratoryId) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/api/laboratoires/$laboratoryId/pcs/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load PCs by laboratory: ${response.body}');
    }
  }

  // Create a new reclamation
  Future<Map<String, dynamic>> createReclamation(
    Map<String, dynamic> data,
  ) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      // Make sure all IDs are integers
      if (data.containsKey('laboratoire') && data['laboratoire'] is String) {
        data['laboratoire'] = int.parse(data['laboratoire']);
      }

      if (data.containsKey('user') && data['user'] is String) {
        data['user'] = int.parse(data['user']);
      }

      // Make sure pc_details.pc_id is an integer
      if (data.containsKey('pc_details') &&
          data['pc_details'] is Map<String, dynamic> &&
          data['pc_details'].containsKey('pc_id') &&
          data['pc_details']['pc_id'] is String) {
        data['pc_details']['pc_id'] = int.parse(data['pc_details']['pc_id']);
      }

      // Debug logging for reclamation creation
      print('DEBUG - Creating reclamation with data: ${jsonEncode(data)}');
      print('DEBUG - Request URL: $baseUrl/api/reclamations/create/');
      print('DEBUG - Authorization token: $token');

      // Make sure we're using the correct endpoint
      final createUrl = '$baseUrl/api/reclamations/create/';
      print('DEBUG - Using create URL: $createUrl');

      // Make sure both status and statut fields are set
      if (data.containsKey('status') && !data.containsKey('statut')) {
        data['statut'] = data['status'];
      } else if (data.containsKey('statut') && !data.containsKey('status')) {
        data['status'] = data['statut'];
      }

      final response = await http.post(
        Uri.parse(createUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(data),
      );

      print(
        'DEBUG - Create reclamation response status: ${response.statusCode}',
      );
      print('DEBUG - Create reclamation response headers: ${response.headers}');
      print('DEBUG - Create reclamation response body: ${response.body}');

      // Log detailed information about the response
      if (response.statusCode == 201 || response.statusCode == 200) {
        print('DEBUG - SUCCESS: Reclamation created successfully');
        final responseData = jsonDecode(response.body);
        print('DEBUG - Response data: $responseData');
        print(
          'DEBUG - Successfully created reclamation with ID: ${responseData['id']}',
        );

        // Also try to immediately fetch the reclamation to verify it exists
        try {
          final verifyResponse = await http.get(
            Uri.parse('$baseUrl/api/reclamations/${responseData['id']}/'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          );
          print(
            'DEBUG - Verification response status: ${verifyResponse.statusCode}',
          );
          print('DEBUG - Verification response body: ${verifyResponse.body}');
        } catch (e) {
          print('DEBUG - Error verifying reclamation: $e');
        }

        return responseData;
      } else {
        print('DEBUG - ERROR: Failed to create reclamation');
        print('DEBUG - Error status code: ${response.statusCode}');
        print('DEBUG - Error response: ${response.body}');

        // Try to parse the error response
        try {
          final errorData = jsonDecode(response.body);
          print('DEBUG - Error data: $errorData');
        } catch (e) {
          print('DEBUG - Could not parse error response: $e');
        }

        throw Exception('Failed to create reclamation: ${response.body}');
      }
    } catch (e) {
      // Handle connection errors gracefully
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Connection refused')) {
        throw Exception(
          'Cannot connect to server. Please check your internet connection or try again later.',
        );
      } else {
        // Re-throw the original exception
        rethrow;
      }
    }
  }
}
