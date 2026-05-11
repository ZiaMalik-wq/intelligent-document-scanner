import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:doc_scanner/core/constants.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DocumentService {
  final _storage = const FlutterSecureStorage();

  Future<String?> _getToken() async {
    return await _storage.read(key: 'token');
  }

  Future<Map<String, dynamic>> uploadDocument(
    File file, {
    int? parentDocumentId,
  }) async {
    final token = await _getToken();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${AppConstants.baseUrl}/documents/upload'),
    );

    request.headers['Authorization'] = 'Bearer $token';

    // Add parent_document_id if provided (for cropped images)
    if (parentDocumentId != null) {
      request.fields['parent_document_id'] = parentDocumentId.toString();
    }

    // Determine content type based on extension (support common image formats)
    final extension = file.path.split('.').last.toLowerCase();
    String mimeType = 'application/octet-stream';
    if (extension == 'png') mimeType = 'image/png';
    if (extension == 'webp') mimeType = 'image/webp';
    if (extension == 'pdf') mimeType = 'application/pdf';
    if (extension == 'jpg' || extension == 'jpeg') mimeType = 'image/jpeg';
    if (extension == 'tif' || extension == 'tiff') mimeType = 'image/tiff';
    if (extension == 'bmp') mimeType = 'image/bmp';
    if (extension == 'gif') mimeType = 'image/gif';
    if (extension == 'heic') mimeType = 'image/heic';
    if (extension == 'svg') mimeType = 'image/svg+xml';

    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        file.path,
        contentType: MediaType.parse(mimeType),
      ),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to upload document: ${response.body}');
    }
  }

  Future<List<dynamic>> getDocuments() async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/documents/'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load documents');
    }
  }

  Future<void> deleteDocument(int id) async {
    final token = await _getToken();
    final response = await http.delete(
      Uri.parse('${AppConstants.baseUrl}/documents/$id'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete document');
    }
  }

  Future<Map<String, dynamic>> generateBatchPdf(List<int> documentIds, {bool deleteSource = true}) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/documents/batch/pdf'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'document_ids': documentIds,
        'delete_source': deleteSource,
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to generate batch PDF');
    }
  }
}
