import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/meeting_recorder_screen.dart';

const String kGitHubRawUrl = 'https://raw.githubusercontent.com/10xdeca/internal/main/team.log';
const String kLastContentHashKey = 'last_content_hash';
const String kBackgroundTaskName = 'checkTeamLog';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == kBackgroundTaskName) {
      await checkForUpdates();
    }
    return Future.value(true);
  });
}

Future<void> checkForUpdates() async {
  try {
    final response = await http.get(Uri.parse(kGitHubRawUrl));
    if (response.statusCode == 200) {
      final prefs = await SharedPreferences.getInstance();
      final currentHash = response.body.hashCode.toString();
      final lastHash = prefs.getString(kLastContentHashKey);

      if (lastHash != null && lastHash != currentHash) {
        await flutterLocalNotificationsPlugin.show(
          id: 0,
          title: 'Team Log Updated',
          body: 'New activity in the team log!',
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'team_log_channel',
              'Team Log Updates',
              channelDescription: 'Notifications for team log updates',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
        );
      }
      await prefs.setString(kLastContentHashKey, currentHash);
    }
  } catch (e) {
    debugPrint('Background check failed: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize notifications
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosSettings = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );
  const initSettings = InitializationSettings(
    android: androidSettings,
    iOS: iosSettings,
  );
  await flutterLocalNotificationsPlugin.initialize(settings: initSettings);

  // Request notification permissions on Android 13+
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();

  // Initialize workmanager for background checks
  await Workmanager().initialize(callbackDispatcher);
  await Workmanager().registerPeriodicTask(
    'team-log-checker',
    kBackgroundTaskName,
    frequency: const Duration(minutes: 15),
    constraints: Constraints(
      networkType: NetworkType.connected,
    ),
  );

  runApp(const XdecaApp());
}

class XdecaApp extends StatelessWidget {
  const XdecaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'XDECA Internal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1a1a2e),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const MainNavigation(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final _screens = const [
    HomePage(),
    MeetingRecorderScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.list),
            selectedIcon: Icon(Icons.list_alt),
            label: 'Team Log',
          ),
          NavigationDestination(
            icon: Icon(Icons.mic),
            selectedIcon: Icon(Icons.mic_rounded),
            label: 'Meetings',
          ),
        ],
      ),
    );
  }
}

class _HomePageState extends State<HomePage> {
  List<LogEntry> _logEntries = [];
  bool _isLoading = true;
  String? _error;
  String _repoUrl = kGitHubRawUrl;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _fetchLog();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _repoUrl = prefs.getString('repo_url') ?? kGitHubRawUrl;
    });
  }

  Future<void> _fetchLog() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await http.get(Uri.parse(_repoUrl));
      if (response.statusCode == 200) {
        final entries = _parseLog(response.body);

        // Save hash for background comparison
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(kLastContentHashKey, response.body.hashCode.toString());

        setState(() {
          _logEntries = entries;
          _isLoading = false;
        });
      } else if (response.statusCode == 404) {
        setState(() {
          _error = 'Log file not found. Make sure team.log exists in the repository.';
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load: HTTP ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Connection error: $e';
        _isLoading = false;
      });
    }
  }

  List<LogEntry> _parseLog(String content) {
    final lines = content.split('\n').where((l) => l.trim().isNotEmpty).toList();
    final entries = <LogEntry>[];

    for (final line in lines) {
      // Expected format: [YYYY-MM-DD HH:MM] @user: message
      // Or: [YYYY-MM-DD HH:MM] message
      final match = RegExp(r'^\[(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2})\]\s*(@\w+)?:?\s*(.*)$').firstMatch(line);
      if (match != null) {
        final timestamp = match.group(1) ?? '';
        final user = match.group(2)?.replaceFirst('@', '') ?? 'system';
        final message = match.group(3) ?? line;
        entries.add(LogEntry(
          timestamp: timestamp,
          user: user,
          message: message,
        ));
      } else {
        // Fallback: treat as plain message
        entries.add(LogEntry(
          timestamp: '',
          user: 'system',
          message: line,
        ));
      }
    }

    return entries.reversed.toList(); // Newest first
  }

  void _showSettings() {
    final controller = TextEditingController(text: _repoUrl);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'GitHub Raw URL',
                hintText: 'https://raw.githubusercontent.com/...',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final nav = Navigator.of(context);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('repo_url', controller.text);
              setState(() {
                _repoUrl = controller.text;
              });
              if (mounted) nav.pop();
              _fetchLog();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Activity Log'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettings,
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _fetchLog,
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _fetchLog,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_logEntries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text(
              'No log entries yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Push entries to team.log in the repository',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchLog,
      child: ListView.builder(
        itemCount: _logEntries.length,
        padding: const EdgeInsets.only(bottom: 80),
        itemBuilder: (context, index) {
          final entry = _logEntries[index];
          return LogEntryCard(entry: entry);
        },
      ),
    );
  }
}

class LogEntry {
  final String timestamp;
  final String user;
  final String message;

  LogEntry({
    required this.timestamp,
    required this.user,
    required this.message,
  });
}

class LogEntryCard extends StatelessWidget {
  final LogEntry entry;

  const LogEntryCard({super.key, required this.entry});

  Color _getUserColor(String user) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.cyan,
      Colors.amber,
    ];
    return colors[user.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: _getUserColor(entry.user),
                  child: Text(
                    entry.user.isNotEmpty ? entry.user[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '@${entry.user}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _getUserColor(entry.user),
                        ),
                      ),
                      if (entry.timestamp.isNotEmpty)
                        Text(
                          entry.timestamp,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[500],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              entry.message,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
