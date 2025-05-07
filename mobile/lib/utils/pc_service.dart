import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/network_config.dart';

class PCService {
  // Base URL for API - dynamically set based on platform
  late final String baseUrl;

  PCService() {
    baseUrl = NetworkConfig.getBaseUrl();
    print('PCService initialized with baseUrl: $baseUrl');
  }

  // Get token from shared preferences
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  // Get PC by ID
  Future<Map<String, dynamic>> getPCById(int pcId) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      // For testing purposes, we can simulate a successful response
      // This will allow us to test the app without a real backend server
      bool useMockResponse = true;

      if (useMockResponse) {
        // Simulate a delay to mimic network latency
        await Future.delayed(Duration(seconds: 1));

        // Return a mock response
        return {
          'id': pcId,
          'poste': 'PC-$pcId',
          'sn_inventaire': 'SN-$pcId',
          'logiciels_installes': 'Windows 10, Office 365, Adobe Creative Cloud',
          'ecran': '24 pouces Full HD',
          'laboratoire': 1,
        };
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
    } catch (e) {
      // Handle connection errors gracefully
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Connection refused')) {
        throw Exception(
          'Impossible de charger les détails du PC: ClientException with SocketException: Connection refused (OS Error: Connection refused, errno = 61), address = 0.0.0.0, port = 56501, uri=http://0.0.0.0:8000/api/pc/$pcId/',
        );
      } else {
        // Re-throw the original exception
        rethrow;
      }
    }
  }

  // Get laboratory by ID
  Future<Map<String, dynamic>> getLaboratoryById(int labId) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      // For testing purposes, we can simulate a successful response
      // This will allow us to test the app without a real backend server
      bool useMockResponse = true;

      if (useMockResponse) {
        // Simulate a delay to mimic network latency
        await Future.delayed(Duration(seconds: 1));

        // Return a mock response
        return {
          'id': labId,
          'nom': 'Laboratoire $labId',
          'modele_postes': 'Dell OptiPlex 7050',
          'processeur': 'Intel Core i7-7700',
          'memoire_ram': '16 GB',
          'stockage': '512 GB SSD',
        };
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/laboratoires/$labId/'),
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
    } catch (e) {
      // Handle connection errors gracefully
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Connection refused')) {
        throw Exception(
          'Impossible de charger les détails du laboratoire: ClientException with SocketException: Connection refused (OS Error: Connection refused, errno = 61), address = 0.0.0.0, port = 56501, uri=http://0.0.0.0:8000/api/laboratoires/$labId/',
        );
      } else {
        // Re-throw the original exception
        rethrow;
      }
    }
  }
}
