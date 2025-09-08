import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:typed_data';

class IncomingDetailPage extends StatelessWidget {
  final Map<String, dynamic> data;

  IncomingDetailPage({required this.data});

  final TextEditingController quantityLossController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    quantityLossController.text = data['loss']?.toString() ?? '0';

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
                _buildInfoRow('Type', data['jenis_rm']),
                _buildInfoRow('Supplier', data['supplier']),
                _buildInfoRow('Unit', data['unit']),
                _buildInfoRow(
                  'Quantity PO',
                  (data['qty_po'] != null) ? '${data['qty_po']} KG' : '0 KG',
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
                  imagePath: data['invoice_supplier'],
                ),
                _buildDocumentRow(
                  context,
                  'Delivery Note (Surat Jalan)',
                  imagePath: data['surat_jalan'],
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
                        '0 KG',
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
                Center(
                  child: Column(
                    children: [
                      Icon(Icons.hourglass_empty, size: 36, color: Colors.grey),
                      Text('No scale data available'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Faktur: ${data['faktur']}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        SizedBox(height: 4),
        Row(
          children: [
            Icon(Icons.calendar_today_outlined, size: 16),
            SizedBox(width: 4),
            Text(data['tanggal_incoming'] ?? ''),
          ],
        ),
        SizedBox(height: 4),
        Text('Created by: Admin CK2', style: TextStyle(color: Colors.grey)),
      ],
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
            final fullUrl = "https://trial-api-gts-rm.scm-ppa.com/$imagePath";
            print("Image URL: $fullUrl");
            showDialog(
              context: context,
              builder: (context) => Dialog(
                child: InteractiveViewer(
                  child: Image.network(
                    fullUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        const Text("Gagal memuat gambar"),
                  ),
                ),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Tidak ada gambar untuk $title')),
            );
          }
        },
      ),
    );
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
