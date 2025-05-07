import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/network_config.dart';

class UserService {
  late final String baseUrl;

  UserService() {
    baseUrl = NetworkConfig.getApiUrl();
    print('UserService initialized with baseUrl: $baseUrl');
  }

  // Get token from shared preferences
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  // Get user ID from token
  Future<int?> getUserIdFromToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null) {
        print('DEBUG - No token available');
        return null;
      }

      // Decode the token to get user ID
      try {
        final parts = token.split('.');
        if (parts.length == 3) {
          final payload = parts[1];
          final normalized = base64Url.normalize(payload);
          final decoded = utf8.decode(base64Url.decode(normalized));
          final data = jsonDecode(decoded);

          if (data.containsKey('user_id')) {
            print('DEBUG - User ID from token: ${data['user_id']}');
            return data['user_id'];
          }
        }
      } catch (e) {
        print('DEBUG - Error decoding token: $e');
      }

      return null;
    } catch (e) {
      print('DEBUG - Error getting user ID: $e');
      return null;
    }
  }

  // Get user data from API
  Future<Map<String, dynamic>> getUserData() async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final userId = await getUserIdFromToken();
      if (userId == null) {
        throw Exception('Could not get user ID');
      }

      print('DEBUG - Getting user data for ID: $userId');

      final response = await http.get(
        Uri.parse('$baseUrl/users/users/$userId/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      // If the first URL fails, try the alternative URL format
      if (response.statusCode != 200) {
        final alternativeResponse = await http.get(
          Uri.parse('$baseUrl/users/me/'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );

        if (alternativeResponse.statusCode == 200) {
          return jsonDecode(alternativeResponse.body);
        }
      }

      print('DEBUG - User data response status: ${response.statusCode}');
      print('DEBUG - User data response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Save user data to shared preferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user', jsonEncode(data));

        return data;
      } else {
        throw Exception('Failed to load user data: ${response.body}');
      }
    } catch (e) {
      print('DEBUG - Error getting user data: $e');
      rethrow;
    }
  }

  // Update user data
  Future<Map<String, dynamic>> updateUserData(
    String firstName,
    String lastName,
  ) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final userId = await getUserIdFromToken();
      if (userId == null) {
        throw Exception('Could not get user ID');
      }

      print('DEBUG - Updating user data for ID: $userId');
      print('DEBUG - New first name: $firstName, new last name: $lastName');

      // Try the first endpoint format
      final response = await http.patch(
        Uri.parse('$baseUrl/users/user/update/$userId/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'first_name': firstName, 'last_name': lastName}),
      );

      // If the first endpoint fails, try an alternative format
      if (response.statusCode != 200) {
        final alternativeResponse = await http.patch(
          Uri.parse('$baseUrl/users/$userId/'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'first_name': firstName, 'last_name': lastName}),
        );

        if (alternativeResponse.statusCode == 200) {
          final data = jsonDecode(alternativeResponse.body);

          // Update user data in shared preferences
          final prefs = await SharedPreferences.getInstance();
          final userJson = prefs.getString('user');

          if (userJson != null) {
            final userData = jsonDecode(userJson);
            userData['first_name'] = firstName;
            userData['last_name'] = lastName;
            await prefs.setString('user', jsonEncode(userData));
          }

          return data;
        }
      }

      print('DEBUG - Update user data response status: ${response.statusCode}');
      print('DEBUG - Update user data response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Update user data in shared preferences
        final prefs = await SharedPreferences.getInstance();
        final userJson = prefs.getString('user');

        if (userJson != null) {
          final userData = jsonDecode(userJson);
          userData['first_name'] = firstName;
          userData['last_name'] = lastName;
          await prefs.setString('user', jsonEncode(userData));
        }

        return data;
      } else {
        throw Exception('Failed to update user data: ${response.body}');
      }
    } catch (e) {
      print('DEBUG - Error updating user data: $e');
      rethrow;
    }
  }
}
