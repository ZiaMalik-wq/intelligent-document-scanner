import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:doc_scanner/core/constants.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ScannerService {
  final _storage = const FlutterSecureStorage();

  Future<String?> _getToken() async {
    return await _storage.read(key: 'token');
  }

  Future<Map<String, dynamic>> enhanceImage(
    int documentId,
    String mode, {
    String documentType = "typed",
  }) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse(
        '${AppConstants.baseUrl}/scanner/enhance/$documentId?mode=$mode&document_type=$documentType',
      ),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to enhance image: ${response.body}');
    }
  }

  }

  Future<Map<String, dynamic>> extractText(
    int documentId, {
    String lang = "eng",
    String engine = "auto",
  }) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse(
        '${AppConstants.baseUrl}/ocr/extract/$documentId?lang=$lang&engine=$engine',
      ),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to extract text: ${response.body}');
    }
  }
}
