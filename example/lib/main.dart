import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:monitor/monitor.dart';
import 'package:monitor_http/monitor_http.dart';

void main() {
  Monitor.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static final navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Network Monitor',
      navigatorKey: Monitor.navigatorKey = navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
        ),
      ),
      home: const MyHomePage(title: 'Network Monitor'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({required this.title, super.key});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final http.Client _client = createMonitorClient();
  final Uri _baseUrl = Uri.parse('https://dummyjson.com');
  Timer? _periodicTimer;
  bool _isPeriodicRunning = false;

  // Auth token storage for authenticated requests
  String? _authToken;

  @override
  void dispose() {
    _periodicTimer?.cancel();
    _client.close();
    super.dispose();
  }

  // Helper to wrap requests for UI feedback
  Future<void> _handleRequest(Future<void> Function() request) async {
    try {
      await request();
    } on Exception catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> _makeGetRequest() async {
    final uri = _baseUrl.replace(
      path: '/products',
      queryParameters: {'limit': '10'},
    );
    await _client.get(uri);
  }

  Future<void> _makeGetSingleProduct() async {
    final uri = _baseUrl.replace(path: '/products/1');
    await _client.get(uri);
  }

  Future<void> _makeSearchRequest() async {
    final uri = _baseUrl.replace(
      path: '/products/search',
      queryParameters: {'q': 'phone'},
    );
    await _client.get(uri);
  }

  Future<void> _makePostRequest() async {
    final uri = _baseUrl.replace(path: '/products/add');
    final body = jsonEncode({
      'title': 'Flutter Test Product',
      'price': 99.99,
      'category': 'electronics',
      'description': 'Added from Flutter Network Monitor',
    });
    await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );
  }

  Future<void> _makePutRequest() async {
    final uri = _baseUrl.replace(path: '/products/1');
    final body = jsonEncode({
      'title': 'Updated Product Title',
      'price': 149.99,
    });
    await _client.put(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );
  }

  Future<void> _makePatchRequest() async {
    final uri = _baseUrl.replace(path: '/products/1');
    final body = jsonEncode({'price': 79.99});
    await _client.patch(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );
  }

  Future<void> _makeDeleteRequest() async {
    final uri = _baseUrl.replace(path: '/products/1');
    await _client.delete(uri);
  }

  Future<void> _makeMultipartUpload() async {
    final uri = _baseUrl.replace(path: '/products/add');

    // Create a real multipart request
    final request = http.MultipartRequest('POST', uri);

    // Add text form fields
    request.fields['title'] = 'Flutter Multipart Product';
    request.fields['price'] = '149.99';
    request.fields['category'] = 'electronics';
    request.fields['description'] = 'Real multipart upload demo';

    // Simulate file uploads (in production, use FilePicker/ImagePicker)
    // Image file (1KB dummy data)
    final imageBytes = Uint8List.fromList(List.generate(1024, (i) => i % 256));
    request.files.add(
      http.MultipartFile.fromBytes(
        'productImage',
        imageBytes,
        filename: 'product_photo.jpg',
        contentType: MediaType('image', 'jpeg'),
      ),
    );

    // Document file (2KB dummy data)
    final pdfBytes = Uint8List.fromList(List.generate(2048, (i) => i % 128));
    request.files.add(
      http.MultipartFile.fromBytes(
        'specSheet',
        pdfBytes,
        filename: 'specifications.pdf',
        contentType: MediaType('application', 'pdf'),
      ),
    );

    final streamedResponse = await _client.send(request);
    await http.Response.fromStream(streamedResponse);
  }

  // ==================== AUTHENTICATION ====================

  Future<void> _makeLoginRequest() async {
    final uri = _baseUrl.replace(path: '/auth/login');
    final body = jsonEncode({
      'username': 'emilys', // DummyJSON test user
      'password': 'emilyspass',
      'expiresInMins': 30,
    });
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    // Store token for authenticated requests
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      _authToken = data['token'] as String?;
    }
  }

  Future<void> _makeGetCurrentUser() async {
    if (_authToken == null) {
      debugPrint('No auth token. Login first.');
      return;
    }

    final uri = _baseUrl.replace(path: '/auth/me');
    await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $_authToken'},
    );
  }

  Future<void> _makeGetUsers() async {
    final uri = _baseUrl.replace(
      path: '/users',
      queryParameters: {'limit': '5'},
    );
    await _client.get(uri);
  }

  Future<void> _makeGetPosts() async {
    final uri = _baseUrl.replace(
      path: '/posts',
      queryParameters: {'limit': '5'},
    );
    await _client.get(uri);
  }

  Future<void> _makeGetTodos() async {
    final uri = _baseUrl.replace(
      path: '/todos',
      queryParameters: {'limit': '5'},
    );
    await _client.get(uri);
  }

  Future<void> _makeGetQuotes() async {
    final uri = _baseUrl.replace(
      path: '/quotes',
      queryParameters: {'limit': '3'},
    );
    await _client.get(uri);
  }

  Future<void> _makeFailedRequest() async {
    // 404 - Product not found
    final uri = _baseUrl.replace(path: '/products/999999999');
    await _client.get(uri);
  }

  Future<void> _makeBadRequest() async {
    // 400 - Bad request (missing required fields)
    final uri = _baseUrl.replace(path: '/products/add');
    final body = jsonEncode({
      // Missing required 'title' field
      'price': 99.99,
    });
    await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );
  }

  Future<void> _makeNetworkErrorRequest() async {
    final uri = Uri.parse('https://invalid-domain-that-does-not-exist.com/api');
    try {
      await _client.get(uri);
    } on Exception catch (e) {
      debugPrint(e.toString());
    }
  }

  void _togglePeriodicRequests() {
    if (_isPeriodicRunning) {
      _periodicTimer?.cancel();
      setState(() => _isPeriodicRunning = false);
    } else {
      setState(() => _isPeriodicRunning = true);
      _periodicTimer = Timer.periodic(
        const Duration(seconds: 2), // Slower for variety
        (timer) {
          // Cycle through different endpoints
          final endpoints = ['/products', '/users', '/posts', '/quotes'];
          final endpoint = endpoints[timer.tick % endpoints.length];
          _makePeriodicRequest(endpoint);
        },
      );
    }
  }

  Future<void> _makePeriodicRequest(String endpoint) async {
    final uri = _baseUrl.replace(
      path: endpoint,
      queryParameters: {'limit': '1'},
    );
    await _client.get(uri);
  }

  // ==================== UI BUILD ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        centerTitle: true,
        actions: const [
          IconButton.filledTonal(
            icon: Icon(Icons.analytics_outlined),
            onPressed: showMonitor,
            tooltip: 'Open Monitor',
          ),
          SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildCard(
            title: 'Products (CRUD)',
            icon: Icons.shopping_bag_outlined,
            children: [
              _ActionTile(
                label: 'List Products',
                icon: Icons.list,
                onTap: () => _handleRequest(_makeGetRequest),
              ),
              _ActionTile(
                label: 'Get Product',
                icon: Icons.visibility,
                onTap: () => _handleRequest(_makeGetSingleProduct),
              ),
              _ActionTile(
                label: 'Search',
                icon: Icons.search,
                onTap: () => _handleRequest(_makeSearchRequest),
              ),
              _ActionTile(
                label: 'Create',
                icon: Icons.add,
                color: Colors.green.shade600,
                onTap: () => _handleRequest(_makePostRequest),
              ),
              _ActionTile(
                label: 'Update (PUT)',
                icon: Icons.edit,
                color: Colors.blue.shade600,
                onTap: () => _handleRequest(_makePutRequest),
              ),
              _ActionTile(
                label: 'Patch',
                icon: Icons.edit_attributes,
                color: Colors.purple.shade600,
                onTap: () => _handleRequest(_makePatchRequest),
              ),
              _ActionTile(
                label: 'Delete',
                icon: Icons.delete,
                color: Colors.red.shade400,
                onTap: () => _handleRequest(_makeDeleteRequest),
              ),
              _ActionTile(
                label: 'Multipart Upload',
                icon: Icons.upload_file,
                color: Colors.teal,
                onTap: () => _handleRequest(_makeMultipartUpload),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildCard(
            title: 'Authentication',
            icon: Icons.lock_outline,
            children: [
              _ActionTile(
                label: 'Login',
                icon: Icons.login,
                color: Colors.indigo,
                onTap: () => _handleRequest(_makeLoginRequest),
              ),
              _ActionTile(
                label: 'Current User',
                icon: Icons.person,
                onTap: () => _handleRequest(_makeGetCurrentUser),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildCard(
            title: 'Other Resources',
            icon: Icons.folder_outlined,
            children: [
              _ActionTile(
                label: 'Users',
                icon: Icons.people,
                onTap: () => _handleRequest(_makeGetUsers),
              ),
              _ActionTile(
                label: 'Posts',
                icon: Icons.article,
                onTap: () => _handleRequest(_makeGetPosts),
              ),
              _ActionTile(
                label: 'Todos',
                icon: Icons.check_circle,
                onTap: () => _handleRequest(_makeGetTodos),
              ),
              _ActionTile(
                label: 'Quotes',
                icon: Icons.format_quote,
                onTap: () => _handleRequest(_makeGetQuotes),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildCard(
            title: 'Error Testing',
            icon: Icons.report_problem_outlined,
            children: [
              _ActionTile(
                label: '404 Not Found',
                icon: Icons.find_replace,
                onTap: _makeFailedRequest,
              ),
              _ActionTile(
                label: '400 Bad Request',
                icon: Icons.error_outline,
                onTap: _makeBadRequest,
              ),
              _ActionTile(
                label: 'DNS Failure',
                icon: Icons.wifi_off,
                onTap: _makeNetworkErrorRequest,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildAutomationSection(),
        ],
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: Colors.indigo),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.5,
              children: children,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAutomationSection() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_mode, size: 18, color: Colors.indigo),
                const SizedBox(width: 8),
                const Text(
                  'Automation',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                if (_isPeriodicRunning) _PulseIndicator(),
              ],
            ),
            const Divider(height: 24),
            Container(
              decoration: BoxDecoration(
                color: _isPeriodicRunning
                    ? Colors.indigo.withValues(alpha: 0.05)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isPeriodicRunning
                      ? Colors.indigo.withValues(alpha: 0.1)
                      : Colors.transparent,
                ),
              ),
              child: SwitchListTile(
                secondary: Icon(
                  _isPeriodicRunning ? Icons.timer : Icons.timer_off_outlined,
                  color: _isPeriodicRunning ? Colors.indigo : Colors.grey,
                ),
                title: const Text('Periodic Requests'),
                subtitle: const Text('Cycles through endpoints every 2s'),
                value: _isPeriodicRunning,
                onChanged: (_) => _togglePeriodicRequests(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatefulWidget {
  const _ActionTile({
    required this.label,
    required this.icon,
    required this.onTap,
    this.color,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  @override
  State<_ActionTile> createState() => _ActionTileState();
}

class _ActionTileState extends State<_ActionTile> {
  bool _isLoading = false;

  Future<void> _onPressed() async {
    setState(() => _isLoading = true);
    widget.onTap();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = widget.color ?? theme.colorScheme.primary;

    return OutlinedButton(
      onPressed: _isLoading ? null : _onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: primaryColor.withValues(alpha: 0.2)),
      ),
      child: _isLoading
          ? const SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, size: 18, color: primaryColor),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    widget.label,
                    style: TextStyle(color: primaryColor, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
    );
  }
}

// Add this helper widget at the bottom of your file for a friendly "running" effect
class _PulseIndicator extends StatefulWidget {
  @override
  State<_PulseIndicator> createState() => _PulseIndicatorState();
}

class _PulseIndicatorState extends State<_PulseIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.4, end: 1).animate(_controller),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'ACTIVE',
          style: TextStyle(
            color: Colors.green.shade700,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
