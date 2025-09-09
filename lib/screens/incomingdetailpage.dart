import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:typed_data';

class IncomingDetailPage extends StatefulWidget {
  final Map<String, dynamic> data;

  const IncomingDetailPage({required this.data, Key? key}) : super(key: key);

  @override
  _IncomingDetailPageState createState() => _IncomingDetailPageState();
}

class _IncomingDetailPageState extends State<IncomingDetailPage> {
  final TextEditingController quantityLossController = TextEditingController();
  List<Map<String, dynamic>> scaleData = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    quantityLossController.text = widget.data['loss']?.toString() ?? '0';
    fetchTimbangan(widget.data['faktur']);
  }

  Future<void> fetchTimbangan(String faktur) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';

    final url = Uri.parse(
      "https://trial-api-gts-rm.scm-ppa.com/gtsrm/api/timbangan?Faktur=$faktur",
    );

    try {
      final response = await http.get(
        url,
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      print("Status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        print("FULL DECODED: $decoded");

        if (decoded is Map && decoded.containsKey('data')) {
          final data = decoded['data'];

          if (data is List && data.isNotEmpty) {
            final firstItem = data[0];
            if (firstItem is Map && firstItem.isNotEmpty) {
              final firstKey = firstItem.keys.first;
              print("First Key: $firstKey");

              final listData = firstItem[firstKey];
              print("List Data: $listData");

              setState(() {
                scaleData = List<Map<String, dynamic>>.from(listData);
                isLoading = false;
              });
              return;
            }
          }
        }

        setState(() {
          scaleData = [];
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      print("Error fetch timbangan: $e");
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalWeight = scaleData.fold<double>(
      0,
      (sum, item) => sum + (item['weight'] is num ? item['weight'] : 0),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('Incoming Detail'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),

            SizedBox(height: 12),
            _buildSection(
              title: 'Raw Material Information',
              children: [
                _buildInfoRow('Type', widget.data['jenis_rm']),
                _buildInfoRow('Supplier', widget.data['supplier']),
                _buildInfoRow('Unit', widget.data['unit']),
                _buildInfoRow(
                  'Quantity PO',
                  (widget.data['qty_po'] != null)
                      ? '${widget.data['qty_po']} KG'
                      : '0 KG',
                ),
              ],
            ),

            SizedBox(height: 12),
            _buildSection(
              title: 'Documents',
              children: [
                _buildDocumentRow(
                  context,
                  'Invoice Supplier',
                  imagePath: widget.data['invoce_supplier'],
                ),
                _buildDocumentRow(
                  context,
                  'Delivery Note (Surat Jalan)',
                  imagePath: widget.data['surat_jalan'],
                ),
              ],
            ),

            SizedBox(height: 12),
            _buildSection(
              title: 'Update Documents',
              subtitle: 'Use this form to upload revised versions.',
              children: [
                UploadRow(label: 'Invoice Supplier Revision'),
                UploadRow(label: 'Delivery Note (Surat Jalan) Revision'),
              ],
            ),

            SizedBox(height: 12),
            _buildSection(
              title: 'Quantity Loss',
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red),
                      SizedBox(width: 8),
                      Text(
                        'Current Quantity Loss: ',
                        style: TextStyle(color: Colors.red),
                      ),
                      Text(
                        '${widget.data['loss'] ?? '0'} KG',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 10),
                TextField(
                  controller: quantityLossController,
                  decoration: InputDecoration(
                    labelText: 'Update Quantity Loss',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                SizedBox(height: 10),
                ElevatedButton.icon(
                  icon: Icon(Icons.save),
                  label: Text('Save Quantity Loss'),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Quantity loss updated successfully'),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                ),
              ],
            ),

            SizedBox(height: 12),
            _buildSection(
              title: 'Scale Data',
              children: [
                if (isLoading)
                  Center(child: CircularProgressIndicator())
                else if (scaleData.isEmpty)
                  Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.hourglass_empty,
                          size: 36,
                          color: Colors.grey,
                        ),
                        Text('No scale data available'),
                      ],
                    ),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(12),
                        margin: EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "Total Berat: ${totalWeight.toStringAsFixed(2)} Kg",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                      const Divider(),
                      ...scaleData.map<Widget>((item) {
                        final typeRm = item['type_rm'] ?? 'Unknown RM';
                        final weight = item['weight'] ?? 0;
                        final status = item['status'] ?? 'Unknown';
                        final dateTime = item['date_time'] ?? '';

                        return ListTile(
                          leading: Icon(
                            status.toString().toLowerCase() == 'retur'
                                ? Icons.close
                                : Icons.check_circle,
                            color: status.toString().toLowerCase() == 'retur'
                                ? Colors.red
                                : Colors.green,
                          ),
                          title: Text("$typeRm - ${weight.toString()} Kg"),
                          subtitle: Text("Status: $status\n$dateTime"),
                        );
                      }).toList(),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Faktur: ${widget.data['faktur']}',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.calendar_today_outlined, size: 16),
                SizedBox(width: 4),
                Text(widget.data['tanggal_incoming'] ?? ''),
              ],
            ),
            SizedBox(height: 4),
            Text('Created by: Admin CK2', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(value),
    );
  }

  Widget _buildDocumentRow(
    BuildContext context,
    String title, {
    required String? imagePath,
  }) {
    return ListTile(
      title: Text(title),
      trailing: IconButton(
        icon: const Icon(Icons.remove_red_eye),
        onPressed: () {
          if (imagePath != null && imagePath.isNotEmpty) {
            showImageDialog(context, imagePath, title);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Tidak ada gambar untuk $title')),
            );
          }
        },
      ),
    );
  }

  void showImageDialog(BuildContext context, String imagePath, String title) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: EdgeInsets.all(10),
        child: FutureBuilder<Uint8List?>(
          future: _fetchImageBytes(imagePath),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppBar(
                    title: Text(title),
                    automaticallyImplyLeading: false,
                    actions: [
                      IconButton(
                        icon: Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text("Gagal memuat gambar"),
                  ),
                ],
              );
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppBar(
                  title: Text(title),
                  automaticallyImplyLeading: false,
                  actions: [
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                Expanded(
                  child: InteractiveViewer(child: Image.memory(snapshot.data!)),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<Uint8List?> _fetchImageBytes(String imagePath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      final url = Uri.parse("https://trial-api-gts-rm.scm-ppa.com/$imagePath");

      print("Fetching image: $url");

      final response = await http.get(
        url,
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        print("Gagal load gambar: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("Error load gambar: $e");
      return null;
    }
  }

  Widget _buildSection({
    required String title,
    String? subtitle,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            if (subtitle != null) ...[
              SizedBox(height: 4),
              Text(subtitle, style: TextStyle(color: Colors.grey)),
            ],
            SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

class UploadRow extends StatefulWidget {
  final String label;

  const UploadRow({required this.label});

  @override
  _UploadRowState createState() => _UploadRowState();
}

class _UploadRowState extends State<UploadRow> {
  XFile? _pickedFile;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickFile() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);

    if (image != null) {
      setState(() {
        _pickedFile = image;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Selected file: ${image.name}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(widget.label),
      subtitle: _pickedFile != null
          ? Text('Selected: ${_pickedFile!.name}')
          : Text('No file selected'),
      trailing: ElevatedButton.icon(
        onPressed: _pickFile,
        icon: Icon(Icons.upload_file),
        label: Text('Choose File'),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
      ),
    );
  }
}
