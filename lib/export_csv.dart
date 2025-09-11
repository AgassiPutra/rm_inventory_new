import 'dart:convert';
import 'dart:html' as html show AnchorElement, Blob, Url;
import 'dart:io' as io show File;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';

Future<void> exportCsv(BuildContext context) async {
  final List<List<dynamic>> rows = [
    ['Tanggal', 'Kategori', 'Jumlah'],
    ['2025-08-12', 'Wet Chicken Dada', 10],
    ['2025-08-12', 'Wet Chicken Paha', 8],
    ['2025-08-12', 'Sayuran', 5],
    ['2025-08-12', 'Udang', 12],
    ['2025-08-12', 'Dry', 7],
    ['2025-08-12', 'Ice', 15],
  ];

  String csvData = const ListToCsvConverter().convert(rows);
  String fileName =
      "incoming_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv";

  if (kIsWeb) {
    final bytes = utf8.encode(csvData);
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute("download", fileName)
      ..click();
    html.Url.revokeObjectUrl(url);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("CSV berhasil diunduh (Web)")));
  } else {
    try {
      final directory = await getExternalStorageDirectory();
      final path = "${directory!.path}/$fileName";
      final file = io.File(path);
      await file.writeAsString(csvData);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("CSV disimpan di: $path")));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Gagal menyimpan CSV: $e")));
    }
  }
}
