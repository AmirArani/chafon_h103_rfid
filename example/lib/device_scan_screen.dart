import 'dart:async';

import 'package:chafon_h103_rfid/chafon_h103_rfid.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'BluetoothDeviceModel.dart';
import 'constants.dart';
import 'functions.dart';
import 'l10n/app_localizations.dart';

enum ConnectionStatus { searching, found, connecting, connected, timeout, error }

class DeviceScanScreen extends StatefulWidget {
  const DeviceScanScreen({super.key});

  @override
  State<DeviceScanScreen> createState() => _DeviceScanScreenState();
}

class _DeviceScanScreenState extends State<DeviceScanScreen> {
  // Auto-connect mode state
  BluetoothDeviceModel? targetDevice;
  ConnectionStatus status = ConnectionStatus.searching;
  Timer? scanTimer;
  String? errorMessage;

  // Developer mode state
  bool developerMode = false;
  int tapCount = 0;
  Timer? tapResetTimer;
  final List<BluetoothDeviceModel> devices = [];
  String? connectedAddress;

  bool isLoading = false;

  Future<void> checkPermissions() async {
    await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();
    await Permission.location.request();
  }

  @override
  void initState() {
    super.initState();
    checkPermissions();

    ChafonH103RfidService.isConnected().then((connected) {
      if (connected == true && mounted) {
        // DON'T auto-navigate, just update status
        setState(() {
          status = ConnectionStatus.connected;
        });
      }
    });

    ChafonH103RfidService.initCallbacks(
      onDeviceFound: (device) {
        final newDevice = BluetoothDeviceModel(
          name: device['name'] ?? 'Unknown',
          address: device['address']!,
          rssi: device['rssi'] ?? 0,
        );

        // Check if this is the target device
        bool isTargetDevice =
            newDevice.name == AppConstants.targetDeviceName ||
            newDevice.address.toUpperCase() == AppConstants.targetDeviceMac.toUpperCase();

        if (developerMode) {
          // In developer mode, add all devices
          if (!devices.any((d) => d.address == newDevice.address)) {
            setState(() {
              devices.add(newDevice);
            });
          }
        } else if (isTargetDevice) {
          // Auto-connect mode: only process target device
          setState(() {
            targetDevice = newDevice;
            status = ConnectionStatus.found;
          });
          scanTimer?.cancel();
          // Auto-connect to target device
          _connectToDevice(newDevice);
        }
      },
      onDisconnected: () {
        setState(() {
          connectedAddress = null;
          status = ConnectionStatus.error;
          errorMessage = AppLocalizations.of(context)!.deviceDisconnected;
        });
      },
    );

    // Start auto-scan with timeout
    if (status != ConnectionStatus.connected) {
      _startScanWithTimeout();
    }
  }

  void _startScanWithTimeout() {
    setState(() {
      status = ConnectionStatus.searching;
      errorMessage = null;
    });
    _startScan();

    scanTimer?.cancel();
    scanTimer = Timer(Duration(seconds: AppConstants.scanTimeoutSeconds), () {
      if (status == ConnectionStatus.searching || status == ConnectionStatus.found) {
        setState(() {
          status = ConnectionStatus.timeout;
          errorMessage = AppLocalizations.of(context)!.persicaRfidNotFound;
        });
        _stopScan();
      }
    });
  }

  Future<void> _startScan() async {
    await ChafonH103RfidService.startScan();
  }

  Future<void> _stopScan() async {
    await ChafonH103RfidService.stopScan();
  }

  Future<void> _connectToDevice(BluetoothDeviceModel device) async {
    setState(() {
      isLoading = true;
      status = ConnectionStatus.connecting;
    });
    await _stopScan();

    final success = await ChafonH103RfidService.connect(device.address);
    setState(() {
      isLoading = false;
      if (success == true) {
        status = ConnectionStatus.connected;
        connectedAddress = device.address;
      } else {
        status = ConnectionStatus.error;
        errorMessage = AppLocalizations.of(context)!.failedToConnect;
      }
    });
  }

  Future<void> _retryConnection() async {
    setState(() {
      status = ConnectionStatus.searching;
      errorMessage = null;
      targetDevice = null;
      devices.clear();
    });
    await Future.delayed(Duration(seconds: AppConstants.connectionRetryDelay));
    _startScanWithTimeout();
  }

  void _handleStatusTap() {
    // Developer mode feature check
    if (!AppConstants.enableDeveloperMode) return;

    tapCount++;
    tapResetTimer?.cancel();

    if (tapCount >= AppConstants.developerModeTapCount) {
      setState(() {
        developerMode = true;
        tapCount = 0;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.developerModeEnabled)));
      // Restart scan to populate device list
      if (status == ConnectionStatus.timeout || status == ConnectionStatus.error) {
        _startScanWithTimeout();
      }
    }

    tapResetTimer = Timer(const Duration(seconds: 2), () {
      tapCount = 0;
    });
  }

  @override
  void dispose() {
    scanTimer?.cancel();
    tapResetTimer?.cancel();
    ChafonH103RfidService.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: developerMode ? _buildDeviceListView() : _buildAutoConnectView());
  }

  Widget _buildAutoConnectView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/persica.png', height: 150, width: 150, fit: BoxFit.contain),
            Text(
              'Persica Soft',
              style: TextStyle(fontSize: 24, color: Color(0xff1F493D), fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 50),
            GestureDetector(onTap: _handleStatusTap, child: _buildStatusCard()),
            const SizedBox(height: 32),
            if (status == ConnectionStatus.connected)
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const Functions()),
                  );
                },
                icon: const Icon(Icons.play_circle),
                label: Text(AppLocalizations.of(context)!.openFunctions),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
            if (status == ConnectionStatus.timeout || status == ConnectionStatus.error)
              ElevatedButton.icon(
                onPressed: _retryConnection,
                icon: const Icon(Icons.refresh),
                label: Text(AppLocalizations.of(context)!.retryConnection),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    IconData icon;
    Color iconColor;
    String title;
    String subtitle;
    bool showSpinner = false;

    switch (status) {
      case ConnectionStatus.searching:
        icon = Icons.search;
        iconColor = Colors.blue;
        title = AppLocalizations.of(context)!.searching;
        subtitle = AppLocalizations.of(context)!.searchingSubtitle;
        showSpinner = true;
        break;
      case ConnectionStatus.found:
        icon = Icons.check_circle_outline;
        iconColor = Colors.green;
        title = AppLocalizations.of(context)!.readerFound;
        subtitle = AppLocalizations.of(context)!.readerFoundSubtitle;
        break;
      case ConnectionStatus.connecting:
        icon = Icons.bluetooth_searching;
        iconColor = Colors.orange;
        title = AppLocalizations.of(context)!.connecting;
        subtitle = AppLocalizations.of(context)!.connectingSubtitle;
        showSpinner = true;
        break;
      case ConnectionStatus.connected:
        icon = Icons.check_circle;
        iconColor = Colors.green;
        title = AppLocalizations.of(context)!.connected;
        subtitle = AppLocalizations.of(context)!.connectedSubtitle;
        break;
      case ConnectionStatus.timeout:
        icon = Icons.error_outline;
        iconColor = Colors.red;
        title = AppLocalizations.of(context)!.connectionTimeout;
        subtitle = errorMessage ?? AppLocalizations.of(context)!.persicaRfidNotFound;
        break;
      case ConnectionStatus.error:
        icon = Icons.error;
        iconColor = Colors.red;
        title = AppLocalizations.of(context)!.connectionError;
        subtitle = errorMessage ?? AppLocalizations.of(context)!.failedToConnect;
        break;
    }

    return Card(
      elevation: 8,
      child: Container(
        padding: const EdgeInsets.all(24),
        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showSpinner)
              const CircularProgressIndicator()
            else
              Icon(icon, size: 64, color: iconColor),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceListView() {
    return Column(
      children: [
        if (isLoading) const LinearProgressIndicator(),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              const Icon(Icons.developer_mode, color: Colors.orange),
              const SizedBox(width: 8),
              Text(
                AppLocalizations.of(context)!.developerModeActive,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  setState(() {
                    developerMode = false;
                    devices.clear();
                  });
                  if (status != ConnectionStatus.connected) {
                    _startScanWithTimeout();
                  }
                },
                child: Text(AppLocalizations.of(context)!.exit),
              ),
            ],
          ),
        ),
        Expanded(
          child: devices.isEmpty
              ? Center(child: Text(AppLocalizations.of(context)!.noDevicesFound))
              : ListView.builder(
                  itemCount: devices.length,
                  itemBuilder: (context, index) {
                    final device = devices[index];
                    final isConnected = device.address == connectedAddress;
                    final isTargetDevice =
                        device.name == AppConstants.targetDeviceName ||
                        device.address.toUpperCase() == AppConstants.targetDeviceMac.toUpperCase();

                    return ListTile(
                      leading: Icon(
                        isTargetDevice ? Icons.star : Icons.bluetooth,
                        color: isTargetDevice ? Colors.amber : null,
                      ),
                      title: Text(device.name),
                      subtitle: Text(
                        "${AppLocalizations.of(context)!.rssi}: ${device.rssi} ${AppLocalizations.of(context)!.dBm}\n${device.address}",
                      ),
                      trailing: isConnected
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : ElevatedButton(
                              onPressed: () => _connectToDevice(device),
                              child: Text(AppLocalizations.of(context)!.connect),
                            ),
                    );
                  },
                ),
        ),
        if (status == ConnectionStatus.connected)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const Functions()));
              },
              icon: const Icon(Icons.play_circle),
              label: Text(AppLocalizations.of(context)!.openFunctions),
            ),
          ),
      ],
    );
  }
}
