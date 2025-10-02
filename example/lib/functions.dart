import 'package:chafon_h103_rfid/chafon_h103_rfid.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'l10n/app_localizations.dart';
import 'models/tag.dart';
import 'repositories/instances.dart';

class Functions extends StatefulWidget {
  const Functions({super.key});

  @override
  State<Functions> createState() => _FunctionsState();
}

class _FunctionsState extends State<Functions> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool isLoading = false;
  Map<String, Map<String, dynamic>> tagMap = {};
  String lastTagInfo = 'تگ خوانده نشده!';
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
        title: Text(AppLocalizations.of(context)!.saveTag),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${AppLocalizations.of(context)!.epc}: $epc'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.name,
                border: const OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(context, name);
              }
            },
            child: Text(AppLocalizations.of(context)!.saveTag),
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
        // plugin ETSI 5..33 dBm
        outputPower = (config['power'] ?? 20).clamp(5, 33);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${AppLocalizations.of(context)!.failedToGetDeviceConfig}: $e")),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> sendConfigToDevice() async {
    final power = _normalizePower(outputPower);
    try {
      // Write only power and save to FLASH (don't resume inventory since we're in settings tab)
      final result = await ChafonH103RfidService.setOnlyOutputPower(
        power: power,
        saveToFlash: true,
        resumeInventory: false,
        region: 2,
      );

      if (!mounted) return;
      if (result == "flash_saved" || result == "ok" || result == "params_saved_to_flash") {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.parametersSaved),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("${AppLocalizations.of(context)!.parametersNotWritten}: $result"),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("${AppLocalizations.of(context)!.error}: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    loadDeviceConfig();
    _loadSaved();

    // First callback init – don't init again
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
              '${AppLocalizations.of(context)!.singleTagRead}\n${AppLocalizations.of(context)!.epc}: ${actualEpc.isEmpty ? AppLocalizations.of(context)!.empty : actualEpc}\n${AppLocalizations.of(context)!.data}: $data\n${AppLocalizations.of(context)!.status}: $status';
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

    // Optionally request battery level on startup
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
        title: Text(AppLocalizations.of(context)!.functions),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(icon: const Icon(Icons.wifi), text: AppLocalizations.of(context)!.continuousRead),
            Tab(
              icon: const Icon(Icons.radio_button_checked),
              text: AppLocalizations.of(context)!.singleRead,
            ),
            Tab(icon: const Icon(Icons.radar), text: AppLocalizations.of(context)!.radarSearch),
            Tab(icon: const Icon(Icons.settings), text: AppLocalizations.of(context)!.settings),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Text(
                batteryLevel != null
                    ? "🔋 $batteryLevel${AppLocalizations.of(context)!.percent}"
                    : "🔋 ...",
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

                return Directionality(
                  textDirection: TextDirection.ltr,
                  child: Card(
                    child: ListTile(
                      leading: const Icon(Icons.nfc),
                      title: Text(
                        savedName != null
                            ? "${AppLocalizations.of(context)!.name}: $savedName"
                            : "${AppLocalizations.of(context)!.epc}: $epc",
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (savedName != null) Text("${AppLocalizations.of(context)!.epc}: $epc"),
                          Text(
                            "${AppLocalizations.of(context)!.rssi}: ${data['rssi']} ${AppLocalizations.of(context)!.dBm}",
                          ),
                          Text("${AppLocalizations.of(context)!.readCount}: ${data['count']}"),
                          Text("${AppLocalizations.of(context)!.lastSeen}: ${data['lastSeen']}"),
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
                                    SnackBar(
                                      content: Text(
                                        AppLocalizations.of(context)!.tagSavedSuccessfully,
                                      ),
                                    ),
                                  );
                                }
                              },
                            )
                          : const Icon(Icons.verified, color: Colors.green),
                    ),
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
                label: Text(AppLocalizations.of(context)!.start),
                onPressed: () async {
                  final result = await ChafonH103RfidService.startInventory();
                  setState(() {
                    log = '📡 ${AppLocalizations.of(context)!.started}: $result';
                  });
                },
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.cleaning_services_rounded),
                label: Text(AppLocalizations.of(context)!.clear),
                onPressed: () => setState(() => tagMap.clear()),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.stop),
                label: Text(AppLocalizations.of(context)!.stop),
                onPressed: () async {
                  final result = await ChafonH103RfidService.stopInventory();
                  setState(() {
                    log = '🛑 ${AppLocalizations.of(context)!.stopped}: $result';
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
          Text(
            AppLocalizations.of(context)!.readResult,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(lastTagInfo, style: const TextStyle(fontSize: 14)),
            ),
          ),
          if (lastSingleEpc.isNotEmpty) ...[
            const SizedBox(height: 16),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        savedName != null
                            ? "${AppLocalizations.of(context)!.name}: $savedName"
                            : "${AppLocalizations.of(context)!.epc}: $lastSingleEpc",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      if (savedName != null)
                        Text("${AppLocalizations.of(context)!.epc}: $lastSingleEpc"),
                      const SizedBox(height: 8),
                      savedName == null
                          ? ElevatedButton.icon(
                              icon: const Icon(Icons.save),
                              label: Text(AppLocalizations.of(context)!.saveTag),
                              onPressed: () async {
                                final name = await _promptForName(context, lastSingleEpc);
                                if (name == null || name.trim().isEmpty) return;

                                try {
                                  await tagRepository.save(lastSingleEpc, name.trim());
                                  await _loadSaved();
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          AppLocalizations.of(context)!.tagSavedSuccessfully,
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          "${AppLocalizations.of(context)!.failedToSaveTag}: $e",
                                        ),
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
                                Text(
                                  AppLocalizations.of(context)!.tagSaved,
                                  style: const TextStyle(color: Colors.green),
                                ),
                              ],
                            ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          DropdownButton<String>(
            value: selectedMemoryBank,
            items: memoryBankOptions
                .map(
                  (bank) => DropdownMenuItem<String>(
                    value: bank,
                    child: Text("${AppLocalizations.of(context)!.memoryBank}: $bank"),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => selectedMemoryBank = value);
              }
            },
          ),
          Spacer(),
          Center(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.radio_button_checked),
              label: Text(AppLocalizations.of(context)!.readSingleTag),
              onPressed: () async {
                // Read from selected bank
                final bank = _memBankCode(selectedMemoryBank);
                await ChafonH103RfidService.readSingleTagFromBank(bank);
              },
            ),
          ),
          const SizedBox(height: 20),
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
      // ATTENTION: We don't call initCallbacks here – it's already provided in initState.
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
          Text(
            AppLocalizations.of(context)!.selectSavedTagOrEnterEpc,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<Tag>>(
            future: tagRepository.getAll(),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                return DropdownButtonFormField<Tag>(
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.selectSavedTag,
                    border: const OutlineInputBorder(),
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
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.epcToSearch,
              border: const OutlineInputBorder(),
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
          Text("${AppLocalizations.of(context)!.detectedEpc}: $lastRadarEpc"),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: isRadarActive ? null : startRadar,
                icon: const Icon(Icons.location_searching),
                label: Text(AppLocalizations.of(context)!.startRadar),
              ),
              ElevatedButton.icon(
                onPressed: isRadarActive ? stopRadar : null,
                icon: const Icon(Icons.stop_circle_outlined),
                label: Text(AppLocalizations.of(context)!.stopRadar),
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
            "📶 ${AppLocalizations.of(context)!.outputPower} ($powLabel ${AppLocalizations.of(context)!.dBm})",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Slider(
            value: (outputPower ?? 20).toDouble(),
            min: 5,
            max: 33,
            divisions: 28, // 5..33
            label: '${outputPower?.toInt() ?? 20} ${AppLocalizations.of(context)!.dBm}',
            onChanged: (value) => setState(() => outputPower = value.toInt()),
          ),
          // const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: Text(AppLocalizations.of(context)!.saveParameters),
                onPressed: () async => await sendConfigToDevice(),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  await ChafonH103RfidService.getBatteryLevel();
                },
                child: Text("🔋 ${AppLocalizations.of(context)!.checkBattery}"),
              ),
            ],
          ),

          const SizedBox(height: 16),
          Text(log),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          Text(
            "💾 ${AppLocalizations.of(context)!.savedTags}",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<Tag>>(
              future: tagRepository.getAll(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Text(
                      AppLocalizations.of(context)!.noSavedTagsYet,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
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
                        subtitle: Text("${AppLocalizations.of(context)!.epc}: ${tag.epc}"),
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
                                      SnackBar(
                                        content: Text(
                                          AppLocalizations.of(context)!.tagRenamedSuccessfully,
                                        ),
                                      ),
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
                                    title: Text(AppLocalizations.of(context)!.deleteTag),
                                    content: Text(
                                      AppLocalizations.of(context)!.areYouSureDelete(tag.name),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        child: Text(AppLocalizations.of(context)!.cancel),
                                      ),
                                      ElevatedButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                        ),
                                        child: Text(AppLocalizations.of(context)!.delete),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed == true) {
                                  await tagRepository.remove(tag.epc);
                                  await _loadSaved();
                                  if (mounted) {
                                    scaffoldMessenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          AppLocalizations.of(context)!.tagDeletedSuccessfully,
                                        ),
                                      ),
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
          // const SizedBox(height: 16),
          // ElevatedButton.icon(
          //   icon: const Icon(Icons.link_off),
          //   label: Text(AppLocalizations.of(context)!.disconnect),
          //   style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          //   onPressed: () async {
          //     await ChafonH103RfidService.disconnect();
          //     if (mounted) {
          //       Navigator.pushAndRemoveUntil(
          //         context,
          //         MaterialPageRoute(builder: (_) => const DeviceScanScreen()),
          //         (route) => false,
          //       );
          //     }
          //   },
          // ),
        ],
      ),
    );
  }
}
