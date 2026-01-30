import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

class TranscriptionService {
  final String apiKey;

  TranscriptionService({required this.apiKey});

  Future<String> transcribe(String audioFilePath) async {
    final file = File(audioFilePath);
    if (!await file.exists()) {
      throw Exception('Audio file not found: $audioFilePath');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('https://api.openai.com/v1/audio/transcriptions'),
    );

    request.headers['Authorization'] = 'Bearer $apiKey';
    request.fields['model'] = 'whisper-1';
    request.files.add(await http.MultipartFile.fromPath('file', audioFilePath));

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode != 200) {
      throw Exception('Transcription failed: $responseBody');
    }

    final json = jsonDecode(responseBody);
    return json['text'] as String;
  }
}
