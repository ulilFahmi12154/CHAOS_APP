import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import 'map_picker_osm_screen.dart';

class LocationManagerScreen extends StatefulWidget {
  const LocationManagerScreen({super.key});

  @override
  State<LocationManagerScreen> createState() => _LocationManagerScreenState();
}

class _LocationManagerScreenState extends State<LocationManagerScreen> {
  final user = FirebaseAuth.instance.currentUser;
  List<Map<String, dynamic>> locations = [];
  String? activeLocationId;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  Future<void> _loadLocations() async {
    if (user == null) return;

    try {
      final docSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();

      if (!docSnap.exists) {
        setState(() {
          loading = false;
        });
        return;
      }

      final data = docSnap.data();
      if (data == null) {
        setState(() {
          loading = false;
        });
        return;
      }

      final locList = List<Map<String, dynamic>>.from(data['locations'] ?? []);
      activeLocationId = data['active_location'] as String?;

      // Load address dari RTDB untuk setiap lokasi
      List<Map<String, dynamic>> locsWithAddress = [];
      for (var loc in locList) {
        final locId = loc['id'] as String;
        final rtdbSnapshot = await FirebaseDatabase.instance
            .ref('smartfarm/locations/$locId')
            .get();

        if (rtdbSnapshot.exists) {
          final rtdbData = rtdbSnapshot.value as Map<dynamic, dynamic>;
          locsWithAddress.add({
            'id': locId,
            'name': rtdbData['name'] ?? loc['name'] ?? locId,
            'address': rtdbData['address'] ?? 'Unknown Location',
          });
        } else {
          locsWithAddress.add({
            'id': locId,
            'name': loc['name'] ?? locId,
            'address': loc['address'] ?? 'Unknown Location',
          });
        }
      }

      locations = locsWithAddress;
      setState(() {
        loading = false;
      });
    } catch (e) {
      print('Error loading locations: $e');
      setState(() {
        loading = false;
      });
    }
  }

  // PATCH untuk location_manager_screen.dart
  // Ganti function _setActiveLocation() dengan yang ini:

  Future<void> _setActiveLocation(dynamic locationIdOrMap) async {
    if (user == null) return;

    String locationId;
    if (locationIdOrMap is String) {
      locationId = locationIdOrMap;
    } else if (locationIdOrMap is Map) {
      locationId = locationIdOrMap['id'];
    } else {
      return;
    }

    try {
      // 1. Save ke Firestore (untuk Flutter)
      await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
        'active_location': locationId,
      }, SetOptions(merge: true));

      // 🆕 2. SYNC KE RTDB GLOBAL (untuk ESP32 baca!)
      await FirebaseDatabase.instance
          .ref('smartfarm/active_device_location')
          .set(locationId);

      setState(() {
        activeLocationId = locationId;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Lokasi $locationId diaktifkan & di-sync ke ESP32'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error setting active location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Gagal mengaktifkan lokasi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Auto-generate location ID: lokasi_1, lokasi_2, lokasi_3, dst
  Future<String> _generateLocationId() async {
    try {
      // 1. Ambil semua lokasi yang ada di RTDB
      final locationsSnapshot = await FirebaseDatabase.instance
          .ref('smartfarm/locations')
          .get();

      if (!locationsSnapshot.exists) {
        return 'lokasi_1'; // Lokasi pertama
      }

      // 2. Cari nomor tertinggi dari lokasi yang ada
      final locations = locationsSnapshot.children;
      int maxNumber = 0;

      for (var location in locations) {
        final key = location.key ?? '';
        // Extract number dari "lokasi_3" -> 3
        if (key.startsWith('lokasi_')) {
          final numStr = key.replaceFirst('lokasi_', '');
          final num = int.tryParse(numStr) ?? 0;
          if (num > maxNumber) {
            maxNumber = num;
          }
        }
      }

      // 3. Return lokasi_N+1
      final newId = 'lokasi_${maxNumber + 1}';
      print('🏗️ Generated new location ID: $newId');
      return newId;
    } catch (e) {
      print('Error generating location ID: $e');
      // Fallback: gunakan timestamp dengan prefix lokasi_
      return 'lokasi_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  void _addLocation() {
    final nameController = TextEditingController();
    double? latitude;
    double? longitude;
    String? address;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Tambah Lokasi Baru'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nama Lokasi',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final result =
                            await Navigator.push<Map<String, dynamic>>(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MapPickerOsmScreen(
                                  initialPosition:
                                      latitude != null && longitude != null
                                      ? LatLng(latitude!, longitude!)
                                      : null,
                                ),
                              ),
                            );

                        if (result != null) {
                          setDialogState(() {
                            latitude = result['latitude'];
                            longitude = result['longitude'];
                            address = result['address'];
                          });
                        }
                      },
                      icon: const Icon(Icons.map),
                      label: const Text('Pilih Lokasi di Peta'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                    if (latitude != null && longitude != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    color: Colors.green.shade700,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Lokasi terpilih:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text('Lat: ${latitude!.toStringAsFixed(6)}'),
                              Text('Lng: ${longitude!.toStringAsFixed(6)}'),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Nama lokasi harus diisi'),
                        ),
                      );
                      return;
                    }

                    if (latitude == null || longitude == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Pilih lokasi di peta terlebih dahulu'),
                        ),
                      );
                      return;
                    }

                    // 🆕 AUTO-GENERATE: lokasi_1, lokasi_2, dst
                    final locationId = await _generateLocationId();
                    print('✅ Creating new location: $locationId');
                    final rtdbRef = FirebaseDatabase.instance.ref(
                      'smartfarm/locations/$locationId',
                    );

                    await rtdbRef.set({
                      'name': nameController.text,
                      'address': address ?? 'Unknown Location',
                      'latitude': latitude,
                      'longitude': longitude,
                      'active_varietas':
                          '', // ✅ Kosong, tunggu user pilih varietas
                      'mode_otomatis': true, // ✅ Default ON
                    });

                    final updatedLocs = [
                      ...locations,
                      {
                        'id': locationId,
                        'name': nameController.text,
                        'address': address ?? 'Unknown Location',
                      },
                    ];

                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(user!.uid)
                        .set({
                          'locations': updatedLocs,
                        }, SetOptions(merge: true));

                    if (locations.isEmpty) {
                      await _setActiveLocation(locationId);
                    }

                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Lokasi berhasil ditambahkan'),
                        ),
                      );
                    }

                    _loadLocations();
                  },
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _editLocation(Map<String, dynamic> location) async {
    final nameController = TextEditingController(text: location['name']);
    double? latitude;
    double? longitude;
    String? address;

    try {
      final snapshot = await FirebaseDatabase.instance
          .ref('smartfarm/locations/${location['id']}')
          .get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        latitude = (data['latitude'] as num?)?.toDouble();
        longitude = (data['longitude'] as num?)?.toDouble();
        address = data['address'] as String?;
      }
    } catch (e) {
      print('Error loading location data: $e');
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Lokasi'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nama Lokasi',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final result =
                            await Navigator.push<Map<String, dynamic>>(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MapPickerOsmScreen(
                                  initialPosition:
                                      latitude != null && longitude != null
                                      ? LatLng(latitude!, longitude!)
                                      : null,
                                ),
                              ),
                            );

                        if (result != null) {
                          setDialogState(() {
                            latitude = result['latitude'];
                            longitude = result['longitude'];
                            address = result['address'];
                          });
                        }
                      },
                      icon: const Icon(Icons.map),
                      label: const Text('Pilih Lokasi di Peta'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                    if (latitude != null && longitude != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    color: Colors.green.shade700,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Lokasi terpilih:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text('Lat: ${latitude!.toStringAsFixed(6)}'),
                              Text('Lng: ${longitude!.toStringAsFixed(6)}'),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Nama lokasi harus diisi'),
                        ),
                      );
                      return;
                    }

                    final updates = <String, dynamic>{
                      'name': nameController.text,
                    };
                    if (latitude != null && longitude != null) {
                      updates['latitude'] = latitude;
                      updates['longitude'] = longitude;
                      updates['address'] = address ?? 'Unknown Location';
                    }

                    // Update RTDB
                    await FirebaseDatabase.instance
                        .ref('smartfarm/locations/${location['id']}')
                        .update(updates);

                    // Update Firestore array juga
                    final updatedLocs = locations.map((loc) {
                      if (loc['id'] == location['id']) {
                        return {
                          'id': loc['id'],
                          'name': nameController.text,
                          'address':
                              address ?? loc['address'] ?? 'Unknown Location',
                        };
                      }
                      return loc;
                    }).toList();

                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(user!.uid)
                        .set({
                          'locations': updatedLocs,
                        }, SetOptions(merge: true));

                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Lokasi berhasil diupdate'),
                        ),
                      );
                    }

                    _loadLocations();
                  },
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteLocation(String locationId) async {
    if (locations.length == 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak bisa menghapus lokasi terakhir')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Lokasi'),
        content: const Text(
          'Apakah Anda yakin ingin menghapus lokasi ini? Semua data sensor dan varietas di lokasi ini akan terhapus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      print('🗑️ Deleting location: $locationId');

      // 1. Hapus data lokasi di Realtime Database (termasuk sensors, varietas, dll)
      await FirebaseDatabase.instance
          .ref('smartfarm/locations/$locationId')
          .remove();
      print('  ✓ RTDB data deleted');

      // 2. Update Firestore - hapus locationId dari array locations
      final updatedLocs = locations
          .where((loc) => loc['id'] != locationId)
          .toList();

      await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
        'locations': updatedLocs,
      }, SetOptions(merge: true));
      print('  ✓ Firestore updated');

      // 3. Jika lokasi yang dihapus adalah lokasi aktif, set lokasi pertama sebagai aktif
      if (activeLocationId == locationId && updatedLocs.isNotEmpty) {
        await _setActiveLocation(updatedLocs.first);
        print('  ✓ Active location switched to ${updatedLocs.first['id']}');
      }

      print('✅ Location deleted successfully');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Lokasi dan semua datanya berhasil dihapus'),
            backgroundColor: Colors.green,
          ),
        );
      }

      _loadLocations();
    } catch (e) {
      print('❌ Error deleting location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Gagal menghapus lokasi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Lokasi'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : locations.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.location_off,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Belum ada lokasi',
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: locations.length,
              itemBuilder: (context, index) {
                final location = locations[index];
                final isActive = location['id'] == activeLocationId;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: isActive ? 4 : 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: isActive
                          ? Colors.green.shade700
                          : Colors.grey.shade300,
                      width: isActive ? 2 : 1,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isActive
                            ? Colors.green.shade700
                            : Colors.grey.shade300,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.location_on,
                        color: isActive ? Colors.white : Colors.grey.shade700,
                      ),
                    ),
                    title: Text(
                      location['name'] ?? 'Unnamed',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isActive ? Colors.green.shade700 : null,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isActive)
                          Text(
                            '✓ Lokasi Aktif',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        if (location['address'] != null &&
                            location['address'] != 'Unknown Location' &&
                            location['address'].toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.place,
                                  size: 14,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    location['address'],
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _editLocation(location),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          color: Colors.red,
                          onPressed: () => _deleteLocation(location['id']),
                        ),
                      ],
                    ),
                    onTap: !isActive
                        ? () => _setActiveLocation(location['id'])
                        : null,
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addLocation,
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Tambah Lokasi'),
      ),
    );
  }
}
