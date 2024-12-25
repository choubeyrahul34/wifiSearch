import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wifi_scan/wifi_scan.dart';
import 'package:wifi_iot/wifi_iot.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'WiFi Scanner',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<WiFiAccessPoint> wifiList = [];
  bool isScanning = false;

  @override
  void initState() {
    super.initState();
    requestPermissions();
  }

  // Request location permissions for WiFi scanning
  Future<void> requestPermissions() async {
    final status = await Permission.location.request();
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Location permission is required for WiFi scanning")),
      );
    }
  }

  // Start scanning for nearby WiFi networks
  Future<void> startScanning() async {
    setState(() {
      isScanning = true;
      wifiList = []; // Clear the list before scanning
    });

    final canScan = await WiFiScan.instance.canStartScan() == CanStartScan.yes;
    if (canScan) {
      await WiFiScan.instance.startScan();

      WiFiScan.instance.onScannedResultsAvailable.listen((results) {
        setState(() {
          wifiList = results;
          isScanning = false;
        });
      });
    } else {
      setState(() {
        isScanning = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("WiFi scanning is not supported on this device")),
      );
    }
  }

  // Show a dialog to ask for the WiFi password
  void askForPassword(WiFiAccessPoint wifi) {
    TextEditingController passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Connect to ${wifi.ssid}"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "WiFi Password",
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                final password = passwordController.text.trim();
                if (password.isNotEmpty) {
                  connectToWiFi(wifi.ssid, password);
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Password cannot be empty")),
                  );
                }
              },
              child: const Text("Connect"),
            ),
          ],
        );
      },
    );
  }

  // Function to connect to a WiFi network
  Future<void> connectToWiFi(String ssid, String password) async {
    try {
      final result = await WiFiForIoTPlugin.connect(
        ssid,
        password: password,
        security: NetworkSecurity.WPA,
        joinOnce: true,
      );

      if (result) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Connected to $ssid")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to connect to $ssid")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("WiFi Scanner"),
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          Center(
            child: ElevatedButton(
              onPressed: startScanning,
              child: const Text("Start Scanning"),
            ),
          ),
          const SizedBox(height: 20),
          isScanning
              ? const Center(child: CircularProgressIndicator())
              : Expanded(
                  child: wifiList.isEmpty
                      ? const Center(child: Text("No WiFi networks found"))
                      : ListView.builder(
                          itemCount: wifiList.length,
                          itemBuilder: (context, index) {
                            final wifi = wifiList[index];
                            return ListTile(
                              leading: const Icon(Icons.wifi),
                              title: Text(wifi.ssid),
                              subtitle:
                                  Text("Signal Strength: ${wifi.ssid} dBm"),
                              onTap: () => askForPassword(wifi),
                            );
                          },
                        ),
                ),
        ],
      ),
    );
  }
}
