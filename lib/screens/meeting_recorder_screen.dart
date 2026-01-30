import 'dart:async';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/transcription_service.dart';
import '../services/outline_service.dart';

class MeetingRecorderScreen extends StatefulWidget {
  const MeetingRecorderScreen({super.key});

  @override
  State<MeetingRecorderScreen> createState() => _MeetingRecorderScreenState();
}

class _MeetingRecorderScreenState extends State<MeetingRecorderScreen> {
  final _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  bool _isProcessing = false;
  String? _recordingPath;
  Duration _recordingDuration = Duration.zero;
  Timer? _timer;
  String _status = 'Ready to record';
  final _titleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _titleController.text = 'Meeting ${DateTime.now().toString().substring(0, 16)}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioRecorder.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (!await _audioRecorder.hasPermission()) {
      setState(() => _status = 'Microphone permission denied');
      return;
    }

    final dir = await getApplicationDocumentsDirectory();
    final filePath = path.join(dir.path, 'meeting_${DateTime.now().millisecondsSinceEpoch}.m4a');

    await _audioRecorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: filePath,
    );

    setState(() {
      _isRecording = true;
      _recordingPath = filePath;
      _recordingDuration = Duration.zero;
      _status = 'Recording...';
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _recordingDuration += const Duration(seconds: 1));
    });
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    final path = await _audioRecorder.stop();
    setState(() {
      _isRecording = false;
      _recordingPath = path;
      _status = 'Recording saved. Ready to transcribe.';
    });
  }

  Future<void> _transcribeAndUpload() async {
    if (_recordingPath == null) return;

    final prefs = await SharedPreferences.getInstance();
    final openaiKey = prefs.getString('openai_api_key');
    final outlineUrl = prefs.getString('outline_url') ?? 'https://wiki.xdeca.com';
    final outlineToken = prefs.getString('outline_api_token');

    if (openaiKey == null || openaiKey.isEmpty) {
      _showSettingsDialog('OpenAI API key required');
      return;
    }

    if (outlineToken == null || outlineToken.isEmpty) {
      _showSettingsDialog('Outline API token required');
      return;
    }

    setState(() {
      _isProcessing = true;
      _status = 'Transcribing audio...';
    });

    try {
      final transcriptionService = TranscriptionService(apiKey: openaiKey);
      final transcript = await transcriptionService.transcribe(_recordingPath!);

      setState(() => _status = 'Uploading to wiki...');

      final outlineService = OutlineService(
        baseUrl: outlineUrl,
        apiToken: outlineToken,
      );

      final title = _titleController.text.isNotEmpty
          ? _titleController.text
          : 'Meeting ${DateTime.now().toString().substring(0, 16)}';

      final document = await outlineService.createDocument(
        title: title,
        text: '# $title\n\n**Recorded:** ${DateTime.now().toString().substring(0, 16)}\n\n**Duration:** ${_formatDuration(_recordingDuration)}\n\n---\n\n## Transcript\n\n$transcript',
      );

      setState(() {
        _status = 'Uploaded successfully!';
        _recordingPath = null;
        _recordingDuration = Duration.zero;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Meeting notes uploaded: ${document['title']}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _status = 'Error: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _showSettingsDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Settings Required'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showApiSettingsDialog();
            },
            child: const Text('Configure'),
          ),
        ],
      ),
    );
  }

  void _showApiSettingsDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final openaiController = TextEditingController(text: prefs.getString('openai_api_key') ?? '');
    final outlineUrlController = TextEditingController(text: prefs.getString('outline_url') ?? 'https://wiki.xdeca.com');
    final outlineTokenController = TextEditingController(text: prefs.getString('outline_api_token') ?? '');

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('API Settings'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: openaiController,
                decoration: const InputDecoration(
                  labelText: 'OpenAI API Key',
                  hintText: 'sk-...',
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: outlineUrlController,
                decoration: const InputDecoration(
                  labelText: 'Outline Wiki URL',
                  hintText: 'https://wiki.xdeca.com',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: outlineTokenController,
                decoration: const InputDecoration(
                  labelText: 'Outline API Token',
                ),
                obscureText: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await prefs.setString('openai_api_key', openaiController.text);
              await prefs.setString('outline_url', outlineUrlController.text);
              await prefs.setString('outline_api_token', outlineTokenController.text);
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${twoDigits(d.inHours)}:${twoDigits(d.inMinutes.remainder(60))}:${twoDigits(d.inSeconds.remainder(60))}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meeting Recorder'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showApiSettingsDialog,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Meeting Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              _formatDuration(_recordingDuration),
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _status,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!_isRecording && !_isProcessing)
                  FloatingActionButton.large(
                    onPressed: _startRecording,
                    backgroundColor: Colors.red,
                    child: const Icon(Icons.mic, size: 36),
                  ),
                if (_isRecording)
                  FloatingActionButton.large(
                    onPressed: _stopRecording,
                    backgroundColor: Colors.grey,
                    child: const Icon(Icons.stop, size: 36),
                  ),
                if (_isProcessing)
                  const CircularProgressIndicator(),
              ],
            ),
            const SizedBox(height: 32),
            if (_recordingPath != null && !_isRecording && !_isProcessing)
              ElevatedButton.icon(
                onPressed: _transcribeAndUpload,
                icon: const Icon(Icons.upload),
                label: const Text('Transcribe & Upload to Wiki'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
