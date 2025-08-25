import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/custom_drawer.dart';
import 'package:image_picker/image_picker.dart';

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
                _buildDocumentRow('Invoice Supplier', hasDocument: false),
                _buildDocumentRow(
                  'Delivery Note (Surat Jalan)',
                  hasDocument: false,
                ),
              ],
            ),

            SizedBox(height: 12),
            _buildSection(
              title: 'Update Documents',
              subtitle: 'Use this form to upload revised versions.',
              children: [
                _buildUploadRow('Invoice Supplier Revision'),
                _buildUploadRow('Delivery Note (Surat Jalan) Revision'),
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

  Widget _buildDocumentRow(String label, {bool hasDocument = false}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(
        hasDocument ? 'Document available' : 'No document available',
      ),
    );
  }

  Widget _buildUploadRow(String label) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: ElevatedButton.icon(
        onPressed: () {
          // TODO: Pilih file
        },
        icon: Icon(Icons.upload_file),
        label: Text('Choose File'),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
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
