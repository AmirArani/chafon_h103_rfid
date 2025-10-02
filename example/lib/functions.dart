import 'package:chafon_h103_rfid/chafon_h103_rfid.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'device_scan_screen.dart';
import 'repositories/instances.dart';
import 'models/tag.dart';

class Functions extends StatefulWidget {
  const Functions({super.key});

  @override
  State<Functions> createState() => _FunctionsState();
}

class _FunctionsState extends State<Functions> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool isLoading = false;
  Map<String, Map<String, dynamic>> tagMap = {};
  String lastTagInfo = 'Tag not read';
  String log = '';
  String selectedMemoryBank = 'EPC';
  final memoryBankOptions = ['TID', 'EPC'];
  int? outputPower;
  int? batteryLevel;

  // Saved tags state
  Map<String, String> savedNamesByEpc = {};
  String lastSingleEpc = '';

  final TextEditingController epcController = TextEditingController();

  // Radar state
  double radarProgress = 0.0;
  Color radarColor = Colors.grey;
  String radarEpc = '';
  String lastRadarEpc = '';
  bool isRadarActive = false;

  Future<void> _loadSaved() async {
    try {
      final all = await tagRepository.getAll();
      if (!mounted) return;
      setState(() {
        savedNamesByEpc = {for (final t in all) t.epc: t.name};
      });
    } catch (e) {
      // Handle error silently or show user-friendly message
    }
  }

  Future<String?> _promptForName(BuildContext context, String epc) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Tag'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('EPC: $epc'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Tag Name',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(context, name);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  int _normalizePower(int? p) {
    final v = (p == null || p == 0) ? 6 : p;
    return v.clamp(5, 33);
  }

  int _memBankCode(String bank) {
    switch (bank) {
      case 'TID':
        return 0x02;
      case 'EPC':
      default:
        return 0x01;
    }
  }

  int _normalizeRssi(int rssi, {int min = -90, int max = -40}) {
    if (rssi < min) return 0;
    if (rssi > max) return 100;
    return ((rssi - min) * 100 / (max - min)).toInt();
  }

  void _handleRadar(String epc, int rssi) {
    if (!isRadarActive || radarEpc.isEmpty) return;

    final strength = _normalizeRssi(rssi);
    if (epc.toLowerCase() == radarEpc.toLowerCase()) {
      SystemSound.play(SystemSoundType.click);

      Color color;
      if (strength > 70) {
        color = Colors.green;
      } else if (strength > 40) {
        color = Colors.yellow;
      } else {
        color = Colors.red;
      }

      setState(() {
        radarProgress = strength / 100;
        radarColor = color;
        lastRadarEpc = epc;
      });
    }
  }

  Future<void> loadDeviceConfig() async {
    setState(() => isLoading = true);
    try {
      final config = await ChafonH103RfidService.getAllDeviceConfig();
      setState(() {
        // plugin ETSI-də 5..33 dBm
        outputPower = (config['power'] ?? 20).clamp(5, 33);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to get device configuration: $e")));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> sendConfigToDevice() async {
    final power = _normalizePower(outputPower);
    try {
      // Yalnız gücü yaz və FLASH-a saxla (inventory işləyirdisə özün bərpa etmirik – settings tabındayıq)
      final result = await ChafonH103RfidService.setOnlyOutputPower(
        power: power,
        saveToFlash: true,
        resumeInventory: false,
        region: 2,
      );

      if (!mounted) return;
      if (result == "flash_saved" || result == "ok" || result == "params_saved_to_flash") {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Parameters saved (FLASH)"), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Parameters not written: $result"),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    loadDeviceConfig();
    _loadSaved();

    // İlk callback init – təkrar init etməyək
    ChafonH103RfidService.initCallbacks(
      onTagRead: (tag) {
        final epc = tag['epc'];
        final rssi = tag['rssi'];

        setState(() {
          if (tagMap.containsKey(epc)) {
            tagMap[epc]!['count'] += 1;
            tagMap[epc]!['rssi'] = rssi;
            tagMap[epc]!['lastSeen'] = DateTime.now();
          } else {
            tagMap[epc] = {'count': 1, 'rssi': rssi, 'lastSeen': DateTime.now()};
          }
        });
      },
      onTagReadSingle: (tag) {
        final status = tag['status'] ?? -1;
        final data = tag['data']?.toString() ?? '';

        if (data.trim().isEmpty) return;

        // Use the data field as the actual EPC since that contains the real EPC value
        final actualEpc = data.trim();

        setState(() {
          lastSingleEpc = actualEpc;
          lastTagInfo =
              'Single tag read:\nEPC: ${actualEpc.isEmpty ? "<empty>" : actualEpc}\nData: $data\nStatus: $status';
        });

        // Refresh saved names to check if this EPC is already saved
        _loadSaved();
      },
      onRadarResult: (tag) {
        final epc = tag['epc'] ?? '';
        final rssi = tag['rssi'] ?? -99;
        _handleRadar(epc, rssi);
      },
      onBatteryLevel: (map) {
        final level = map['level'];
        setState(() {
          batteryLevel = level;
        });
      },
      onBatteryTimeout: () {},
      onFlashSaved: () {},
    );

    // İstəyə görə açılışda batareya soruş
    ChafonH103RfidService.getBatteryLevel();
  }

  @override
  void dispose() {
    epcController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final powLabel = outputPower?.toString() ?? '...';
    return Scaffold(
      appBar: AppBar(
        title: const Text("Functions"),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.wifi), text: "Continuous Read "),
            Tab(icon: Icon(Icons.radio_button_checked), text: "Single read"),
            Tab(icon: Icon(Icons.radar), text: "Radar Search"),
            Tab(icon: Icon(Icons.settings), text: "Settings"),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Text(
                batteryLevel != null ? "🔋 $batteryLevel%" : "🔋 ...",
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildContinuousInventoryTab(),
                _buildSingleReadTab(),
                _buildRadarTab(),
                _buildSettingsTab(powLabel),
              ],
            ),
    );
  }

  Widget _buildContinuousInventoryTab() {
    final tagEntries = tagMap.entries.toList();
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: tagEntries.length,
              itemBuilder: (_, index) {
                final epc = tagEntries[index].key;
                final data = tagEntries[index].value;
                final savedName = savedNamesByEpc[epc];

                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.nfc),
                    title: Text(savedName != null ? "Name: $savedName" : "EPC: $epc"),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (savedName != null) Text("EPC: $epc"),
                        Text("RSSI: ${data['rssi']} dBm"),
                        Text("Read Count: ${data['count']}"),
                        Text("Last Seen: ${data['lastSeen']}"),
                      ],
                    ),
                    trailing: savedName == null
                        ? IconButton(
                            icon: const Icon(Icons.save),
                            onPressed: () async {
                              final name = await _promptForName(context, epc);
                              if (name == null) return;
                              await tagRepository.save(epc, name);
                              await _loadSaved();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Tag saved successfully")),
                                );
                              }
                            },
                          )
                        : const Icon(Icons.verified, color: Colors.green),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text("Start"),
                onPressed: () async {
                  final result = await ChafonH103RfidService.startInventory();
                  setState(() {
                    log = '📡 Started: $result';
                  });
                },
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.cleaning_services_rounded),
                label: const Text("Clear"),
                onPressed: () => setState(() => tagMap.clear()),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.stop),
                label: const Text("Stop"),
                onPressed: () async {
                  final result = await ChafonH103RfidService.stopInventory();
                  setState(() {
                    log = '🛑 Stopped: $result';
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(log, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildSingleReadTab() {
    final savedName = lastSingleEpc.isNotEmpty ? savedNamesByEpc[lastSingleEpc] : null;

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ElevatedButton.icon(
            icon: const Icon(Icons.radio_button_checked),
            label: const Text("Read Single Tag"),
            onPressed: () async {
              // Seçilən bankdan oxu
              final bank = _memBankCode(selectedMemoryBank);
              await ChafonH103RfidService.readSingleTagFromBank(bank);
            },
          ),
          const SizedBox(height: 20),
          const Text("Read Result:", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(lastTagInfo, style: const TextStyle(fontSize: 14)),
          ),
          if (lastSingleEpc.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      savedName != null ? "Name: $savedName" : "EPC: $lastSingleEpc",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    if (savedName != null) Text("EPC: $lastSingleEpc"),
                    const SizedBox(height: 8),
                    savedName == null
                        ? ElevatedButton.icon(
                            icon: const Icon(Icons.save),
                            label: const Text("Save Tag"),
                            onPressed: () async {
                              final name = await _promptForName(context, lastSingleEpc);
                              if (name == null || name.trim().isEmpty) return;

                              try {
                                await tagRepository.save(lastSingleEpc, name.trim());
                                await _loadSaved();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("Tag saved successfully"),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text("Failed to save tag: $e"),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                          )
                        : Row(
                            children: [
                              const Icon(Icons.verified, color: Colors.green),
                              const SizedBox(width: 8),
                              const Text("Tag saved", style: TextStyle(color: Colors.green)),
                            ],
                          ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          DropdownButton<String>(
            value: selectedMemoryBank,
            items: memoryBankOptions
                .map(
                  (bank) =>
                      DropdownMenuItem<String>(value: bank, child: Text("Memory Bank: $bank")),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => selectedMemoryBank = value);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRadarTab() {
    Future<void> startRadar() async {
      final epc = epcController.text.trim();
      if (epc.isEmpty) return;

      await ChafonH103RfidService.startRadar(epc);
      setState(() {
        isRadarActive = true;
        radarEpc = epc;
        radarProgress = 0;
        radarColor = Colors.grey;
        lastRadarEpc = '';
      });
      // DİQQƏT: Burada initCallbacks ÇAĞIRMIRIQ – artıq initState-də verilib.
    }

    Future<void> stopRadar() async {
      await ChafonH103RfidService.stopRadar();
      setState(() {
        isRadarActive = false;
        radarEpc = '';
        radarProgress = 0;
        radarColor = Colors.grey;
        lastRadarEpc = '';
      });
    }

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Select Saved Tag or Enter EPC Manually:",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<Tag>>(
            future: tagRepository.getAll(),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                return DropdownButtonFormField<Tag>(
                  decoration: const InputDecoration(
                    labelText: "Select Saved Tag",
                    border: OutlineInputBorder(),
                  ),
                  items: snapshot.data!
                      .map(
                        (tag) => DropdownMenuItem<Tag>(
                          value: tag,
                          child: Text("${tag.name} (${tag.epc})"),
                        ),
                      )
                      .toList(),
                  onChanged: (Tag? selectedTag) {
                    if (selectedTag != null) {
                      epcController.text = selectedTag.epc;
                    }
                  },
                );
              }
              return const SizedBox.shrink();
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: epcController,
            decoration: const InputDecoration(
              labelText: "EPC to Search",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: radarProgress,
            minHeight: 20,
            color: radarColor,
            backgroundColor: Colors.grey[300],
          ),
          const SizedBox(height: 12),
          Text("Detected EPC: $lastRadarEpc"),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: isRadarActive ? null : startRadar,
                icon: const Icon(Icons.location_searching),
                label: const Text("Start Radar"),
              ),
              ElevatedButton.icon(
                onPressed: isRadarActive ? stopRadar : null,
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text("Stop Radar"),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTab(String powLabel) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "📶 Output Power ($powLabel dBm)",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Slider(
            value: (outputPower ?? 20).toDouble(),
            min: 5,
            max: 33,
            divisions: 28, // 5..33
            label: '${outputPower?.toInt() ?? 20} dBm',
            onChanged: (value) => setState(() => outputPower = value.toInt()),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.save),
            label: const Text("Save Parameters"),
            onPressed: () async => await sendConfigToDevice(),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () async {
              await ChafonH103RfidService.getBatteryLevel();
            },
            child: const Text("🔋 Check Battery"),
          ),
          const SizedBox(height: 16),
          Text(log),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),
          const Text("💾 Saved Tags", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<Tag>>(
              future: tagRepository.getAll(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text(
                      "No saved tags yet.\nSave tags from Continuous or Single Read tabs.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final tag = snapshot.data![index];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.nfc),
                        title: Text(tag.name),
                        subtitle: Text("EPC: ${tag.epc}"),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () async {
                                final scaffoldMessenger = ScaffoldMessenger.of(context);
                                final newName = await _promptForName(context, tag.epc);
                                if (newName != null && newName != tag.name) {
                                  await tagRepository.rename(tag.epc, newName);
                                  await _loadSaved();
                                  if (mounted) {
                                    scaffoldMessenger.showSnackBar(
                                      const SnackBar(content: Text("Tag renamed successfully")),
                                    );
                                  }
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                final scaffoldMessenger = ScaffoldMessenger.of(context);
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Delete Tag'),
                                    content: Text('Are you sure you want to delete "${tag.name}"?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        child: const Text('Cancel'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                        ),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed == true) {
                                  await tagRepository.remove(tag.epc);
                                  await _loadSaved();
                                  if (mounted) {
                                    scaffoldMessenger.showSnackBar(
                                      const SnackBar(content: Text("Tag deleted successfully")),
                                    );
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.link_off),
            label: const Text("Disconnect"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await ChafonH103RfidService.disconnect();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const DeviceScanScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
