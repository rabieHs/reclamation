import 'package:flutter/material.dart';
import '../utils/network_config.dart';
import '../utils/ip_tester.dart';

class NetworkDiagnosticScreen extends StatefulWidget {
  const NetworkDiagnosticScreen({Key? key}) : super(key: key);

  @override
  _NetworkDiagnosticScreenState createState() =>
      _NetworkDiagnosticScreenState();
}

class _NetworkDiagnosticScreenState extends State<NetworkDiagnosticScreen> {
  bool _isTesting = false;
  String _results = '';
  String? _workingIp;
  String _localIp = 'Unknown';
  final TextEditingController _ipController = TextEditingController(
    text: '192.168.1.63',
  );

  @override
  void initState() {
    super.initState();
    _getLocalIp();
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  Future<void> _testSpecificIp() async {
    if (_isTesting) return;

    final ip = _ipController.text.trim();
    if (ip.isEmpty) {
      _addResult('Please enter a valid IP address');
      return;
    }

    setState(() {
      _isTesting = true;
      _results = 'Testing specific IP: $ip\n';
    });

    // First test if the IP is reachable
    _addResult('Testing basic connectivity to $ip:8000...');
    final result = await IpTester.isIpReachableWithDetails(ip);
    final isReachable = result['isReachable'] as bool;

    if (isReachable) {
      _addResult('$ip: ✅ REACHABLE (Status: ${result['statusCode']})');
      _addResult('Response: ${result['responseBody']}');

      // Now test if the Django server is running
      _addResult('\nTesting Django server on $ip:8000...');
      final djangoResult = await IpTester.testDjangoServer(ip);
      final isDjangoRunning = djangoResult['isRunning'] as bool;

      if (isDjangoRunning) {
        _addResult('Django server: ✅ RUNNING');
        _addResult('Endpoint: ${djangoResult['url']}');
        _addResult('Status: ${djangoResult['statusCode']}');
        _addResult('Response: ${djangoResult['responseBody']}');
        setState(() {
          _workingIp = ip;
        });
      } else {
        _addResult('Django server: ❌ NOT RUNNING');
        _addResult('Error: ${djangoResult['error']}');
        _addResult('\nPossible issues:');
        _addResult('1. Django server is not running');
        _addResult('2. Django server is running but not on port 8000');
        _addResult(
          '3. Django server is not configured to accept connections from other devices',
        );
      }
    } else {
      _addResult('$ip: ❌ UNREACHABLE');
      _addResult('Error: ${result['error'] ?? "Unknown error"}');

      _addResult('\nTroubleshooting tips:');
      _addResult(
        '1. Make sure your iOS device and Mac are on the same WiFi network',
      );
      _addResult('2. Check if your Mac\'s firewall is blocking port 8000');
      _addResult(
        '3. Verify Django server is running with: python manage.py runserver 0.0.0.0:8000',
      );
    }

    setState(() {
      _isTesting = false;
    });
  }

  Future<void> _getLocalIp() async {
    final localIp = await IpTester.getLocalIpAddress();
    if (mounted) {
      setState(() {
        _localIp = localIp ?? 'Unknown';
      });
    }
  }

  Future<void> _testConnections() async {
    if (_isTesting) return;

    setState(() {
      _isTesting = true;
      _results = 'Testing connections...\n';
    });

    // Test the current configured IP
    final configuredIp = NetworkConfig.devMachineIp;
    _addResult('Testing configured IP: $configuredIp');

    final configuredIpResult = await IpTester.isIpReachableWithDetails(
      configuredIp,
    );
    final isConfiguredIpReachable = configuredIpResult['isReachable'] as bool;
    _addResult('Configured IP reachable: $isConfiguredIpReachable');

    if (!isConfiguredIpReachable) {
      _addResult('Error: ${configuredIpResult['error'] ?? "Unknown error"}');
    } else {
      _addResult('Status code: ${configuredIpResult['statusCode']}');
    }

    // Test all possible IPs
    _addResult('\nTesting all possible IPs:');
    for (final ip in NetworkConfig.possibleDevIps) {
      final result = await IpTester.isIpReachableWithDetails(ip);
      final isReachable = result['isReachable'] as bool;

      if (isReachable) {
        _addResult('$ip: ✅ REACHABLE (Status: ${result['statusCode']})');
      } else {
        _addResult(
          '$ip: ❌ UNREACHABLE (${result['error'] ?? "Unknown error"})',
        );
      }
    }

    // Find a working IP
    _addResult('\nSearching for a working IP...');
    final workingIp = await IpTester.findWorkingIp(
      NetworkConfig.possibleDevIps,
    );

    if (workingIp != null) {
      _addResult('Found working IP: $workingIp');
      setState(() {
        _workingIp = workingIp;
      });
    } else {
      _addResult(
        'No working IP found. Please check your network configuration.',
      );
      _addResult('\nTroubleshooting tips:');
      _addResult(
        '1. Make sure your iOS device and Mac are on the same WiFi network',
      );
      _addResult('2. Check if your Mac\'s firewall is blocking port 8000');
      _addResult(
        '3. Verify Django server is running with: python manage.py runserver 0.0.0.0:8000',
      );
      _addResult(
        '4. Try restarting both the Django server and the Flutter app',
      );
    }

    setState(() {
      _isTesting = false;
    });
  }

  void _addResult(String result) {
    if (mounted) {
      setState(() {
        _results += '$result\n';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Network Diagnostics')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Network Configuration',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text('Configured Server IP: ${NetworkConfig.devMachineIp}'),
            Text('Device Local IP: $_localIp'),
            Text('API URL: ${NetworkConfig.getApiUrl()}'),
            const SizedBox(height: 16),

            // Test specific IP section
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ipController,
                    decoration: const InputDecoration(
                      labelText: 'Test specific IP',
                      hintText: 'Enter IP address',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isTesting ? null : _testSpecificIp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Test'),
                ),
              ],
            ),

            const SizedBox(height: 16),

            ElevatedButton(
              onPressed: _isTesting ? null : _testConnections,
              child:
                  _isTesting
                      ? const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text('Testing...'),
                        ],
                      )
                      : const Text('Test All Connections'),
            ),

            const SizedBox(height: 16),

            if (_workingIp != null) ...[
              Text(
                'Working IP Found: $_workingIp',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const Text(
                'Update the devMachineIp in network_config.dart with this value.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 16),
            ],

            Expanded(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _results,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
