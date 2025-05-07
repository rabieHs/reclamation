import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/network_config.dart';

class LaboratoryService {
  // Base URL for API - dynamically set based on platform
  late final String baseUrl;

  LaboratoryService() {
    baseUrl = NetworkConfig.getBaseUrl();
    print('LaboratoryService initialized with baseUrl: $baseUrl');
  }

  // Get token from shared preferences
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    print('DEBUG - Laboratory Service - Access Token: $token');

    // Also print refresh token for debugging
    final refreshToken = prefs.getString('refresh_token');
    print('DEBUG - Laboratory Service - Refresh Token: $refreshToken');

    return token;
  }

  // Get all laboratories
  Future<List<dynamic>> getAllLaboratories() async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    print(
      'DEBUG - Laboratory Service - Making request to: $baseUrl/api/laboratoires/',
    );
    print('DEBUG - Laboratory Service - Using token: $token');

    final response = await http.get(
      Uri.parse('$baseUrl/api/laboratoires/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    print(
      'DEBUG - Laboratory Service - Response status code: ${response.statusCode}',
    );
    print('DEBUG - Laboratory Service - Response body: ${response.body}');

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load laboratories: ${response.body}');
    }
  }

  // Get laboratory details
  Future<Map<String, dynamic>> getLaboratoryDetails(int laboratoryId) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/api/laboratoires/$laboratoryId/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load laboratory details: ${response.body}');
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

  // Get PC by ID
  Future<Map<String, dynamic>> getPCById(int pcId) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/api/pc/$pcId/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load PC details: ${response.body}');
    }
  }
}
