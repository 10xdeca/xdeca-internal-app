import 'package:http/http.dart' as http;
import 'dart:convert';

class OutlineService {
  final String baseUrl;
  final String apiToken;

  OutlineService({
    required this.baseUrl,
    required this.apiToken,
  });

  Future<Map<String, dynamic>> createDocument({
    required String title,
    required String text,
    String? collectionId,
    bool publish = true,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/documents.create'),
      headers: {
        'Authorization': 'Bearer $apiToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'title': title,
        'text': text,
        if (collectionId != null) 'collectionId': collectionId,
        'publish': publish,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to create document: ${response.body}');
    }

    return jsonDecode(response.body)['data'];
  }

  Future<List<Map<String, dynamic>>> getCollections() async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/collections.list'),
      headers: {
        'Authorization': 'Bearer $apiToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to get collections: ${response.body}');
    }

    final data = jsonDecode(response.body)['data'] as List;
    return data.cast<Map<String, dynamic>>();
  }
}
