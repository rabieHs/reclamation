import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../utils/network_config.dart';

class AuthService {
  // Base URL for the API - dynamically set based on platform
  late final String baseUrl;
  late final String baseUrlWithoutApi;

  // Initialize with platform-specific URLs
  AuthService() {
    baseUrlWithoutApi = NetworkConfig.getBaseUrl();
    baseUrl = NetworkConfig.getApiUrl();
    print('AuthService initialized with baseUrl: $baseUrl');
  }

  // Store tokens in shared preferences
  Future<void> storeTokens(String accessToken, String refreshToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', accessToken);
    await prefs.setString('refresh_token', refreshToken);
  }

  // Get access token from shared preferences
  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  // Get refresh token from shared preferences
  Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('refresh_token');
  }

  // Clear tokens from shared preferences (logout)
  Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
  }

  // Register a new user
  Future<Map<String, dynamic>> register(
    String firstName,
    String lastName,
    String email,
    String password,
    String role,
  ) async {
    try {
      print('Sending registration request to: $baseUrl/users/register/');
      print(
        'Request body: ${jsonEncode({'first_name': firstName, 'last_name': lastName, 'email': email, 'password': password, 'role': role})}',
      );

      final response = await http.post(
        Uri.parse('$baseUrl/users/register/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'first_name': firstName,
          'last_name': lastName,
          'email': email,
          'password': password,
          'role': role,
        }),
      );

      print('Registration response status code: ${response.statusCode}');
      print('Registration response body: ${response.body}');

      // Check if the response is valid JSON
      try {
        final data = jsonDecode(response.body);

        // Check for validation errors
        if (response.statusCode == 400 && data.containsKey('email')) {
          // Email validation error
          return {'error': 'Email error: ${data['email'][0]}'};
        }

        return data;
      } catch (e) {
        print('Error parsing JSON: ${e.toString()}');
        // If the response is not valid JSON, return the error
        return {
          'error':
              'Server returned invalid response: ${response.body.substring(0, min(100, response.body.length))}...',
          'status_code': response.statusCode,
        };
      }
    } catch (e) {
      print('Network error: ${e.toString()}');
      return {'error': 'Network error: ${e.toString()}'};
    }
  }

  // Login user
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users/login/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      // Check if the response is valid JSON
      try {
        final data = jsonDecode(response.body);
        print('Login response data: $data');

        if (response.statusCode == 200 && data.containsKey('access')) {
          // Store tokens
          await storeTokens(data['access'], data['refresh']);
          return {'success': true, 'data': data};
        } else {
          return {'success': false, 'error': data['error'] ?? 'Login failed'};
        }
      } catch (e) {
        print(e);
        // If the response is not valid JSON, return the error
        return {
          'success': false,
          'error':
              'Server returned invalid response: ${response.body.substring(0, 100)}...',
          'status_code': response.statusCode,
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }

  // Forgot password
  Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      // The correct URL is without the 'api/' prefix
      final forgotPasswordUrl =
          '$baseUrlWithoutApi/reset-password/forgot-password/';
      print('Sending forgot password request to: $forgotPasswordUrl');
      print('Request body: ${jsonEncode({'email': email})}');

      final response = await http.post(
        Uri.parse(forgotPasswordUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      print('Forgot password response status code: ${response.statusCode}');
      print('Forgot password response body: ${response.body}');

      // Check if the response is valid JSON
      try {
        final data = jsonDecode(response.body);

        // Check for validation errors
        if (response.statusCode == 400 && data.containsKey('email')) {
          // Email validation error
          return {'error': 'Email error: ${data['email'][0]}'};
        } else if (response.statusCode == 404 && data.containsKey('error')) {
          return {'error': data['error']};
        }

        return data;
      } catch (e) {
        print('Error parsing JSON: ${e.toString()}');
        // If the response is not valid JSON, return the error
        return {
          'error':
              'Server returned invalid response: ${response.body.substring(0, min(100, response.body.length))}...',
          'status_code': response.statusCode,
        };
      }
    } catch (e) {
      print('Network error: ${e.toString()}');
      return {'error': 'Network error: ${e.toString()}'};
    }
  }

  // Reset password
  Future<Map<String, dynamic>> resetPassword(
    String token,
    String password,
  ) async {
    try {
      // The correct URL is without the 'api/' prefix
      final resetPasswordUrl = '$baseUrlWithoutApi/reset-password/$token/';
      print('Sending reset password request to: $resetPasswordUrl');
      print('Request body: ${jsonEncode({'password': password})}');

      final response = await http.post(
        Uri.parse(resetPasswordUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'password': password}),
      );

      print('Reset password response status code: ${response.statusCode}');
      print('Reset password response body: ${response.body}');

      // Check if the response is valid JSON
      try {
        final data = jsonDecode(response.body);

        // Check for validation errors
        if (response.statusCode == 400 && data.containsKey('error')) {
          // Error message
          return {'error': data['error']};
        }

        return data;
      } catch (e) {
        print('Error parsing JSON: ${e.toString()}');
        // If the response is not valid JSON, return the error
        return {
          'error':
              'Server returned invalid response: ${response.body.substring(0, min(100, response.body.length))}...',
          'status_code': response.statusCode,
        };
      }
    } catch (e) {
      print('Network error: ${e.toString()}');
      return {'error': 'Network error: ${e.toString()}'};
    }
  }

  // Get current user
  Future<User?> getCurrentUser() async {
    try {
      final token = await getAccessToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/users/me/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      // Check if the response is valid JSON
      try {
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return User.fromJson(data);
        }
        return null;
      } catch (e) {
        print('Error parsing user data: ${e.toString()}');
        print(
          'Response body: ${response.body.substring(0, min(100, response.body.length))}...',
        );
        return null;
      }
    } catch (e) {
      print('Network error getting user: ${e.toString()}');
      return null;
    }
  }

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  // Logout user
  Future<void> logout() async {
    await clearTokens();
  }
}
