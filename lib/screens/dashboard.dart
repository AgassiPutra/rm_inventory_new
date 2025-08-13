import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import '../models/incoming_data.dart';
import '../widgets/custom_drawer.dart';

class DashboardPage extends StatefulWidget {
  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final Map<String, Color> categoryColors = {
    'Wet Chicken Dada': Colors.red,
    'Wet Chicken Paha': Colors.orange,
    'Sayuran': Colors.green,
    'Udang': Colors.pink,
    'Dry': Colors.brown,
    'Ice': Colors.blue,
  };

  DateTime? startDate;
  DateTime? endDate;
  late List<IncomingData> allData;

  @override
  void initState() {
    super.initState();
    allData = generateDummyData();
    startDate = DateTime.now();
    endDate = DateTime.now();
  }

  List<IncomingData> generateDummyData() {
    final now = DateTime.now();
    return [
      IncomingData(category: 'Wet Chicken Dada', quantity: 20, date: now),
      IncomingData(category: 'Wet Chicken Paha', quantity: 35, date: now),
      IncomingData(category: 'Sayuran', quantity: 50, date: now),
      IncomingData(category: 'Udang', quantity: 40, date: now),
      IncomingData(category: 'Dry', quantity: 15, date: now),
      IncomingData(category: 'Ice', quantity: 60, date: now),
      IncomingData(
        category: 'Sayuran',
        quantity: 25,
        date: now.subtract(Duration(days: 1)),
      ),
      IncomingData(
        category: 'Udang',
        quantity: 10,
        date: now.subtract(Duration(days: 2)),
      ),
      IncomingData(
        category: 'Ice',
        quantity: 100,
        date: now.subtract(Duration(days: 3)),
      ),
    ];
  }

  Future<void> exportToCSV(Map<String, int> totals) async {
    try {
      // Header CSV
      List<List<dynamic>> rows = [
        ["Kategori", "Total (kg)"],
      ];

      // Tambahkan data
      totals.forEach((category, total) {
        rows.add([category, total]);
      });

      // Konversi ke string CSV
      String csvData = const ListToCsvConverter().convert(rows);

      // Tentukan lokasi file
      final directory = await getApplicationDocumentsDirectory();
      final path =
          "${directory.path}/dashboard_incoming_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv";

      // Simpan file
      final file = File(path);
      await file.writeAsString(csvData);

      // Tampilkan notifikasi / snackbar
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('CSV berhasil diexport: $path')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal export CSV: $e')));
      }
    }
  }

  Future<void> selectDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: startDate!, end: endDate!),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        startDate = picked.start;
        endDate = picked.end;
      });
    }
  }

  List<IncomingData> getFilteredData() {
    return allData.where((data) {
      return data.date.isAfter(startDate!.subtract(Duration(days: 1))) &&
          data.date.isBefore(endDate!.add(Duration(days: 1)));
    }).toList();
  }

  Map<String, int> calculateTotalByCategory(List<IncomingData> dataList) {
    Map<String, int> totals = {};
    for (var data in dataList) {
      totals[data.category] = (totals[data.category] ?? 0) + data.quantity;
    }
    return totals;
  }

  @override
  Widget build(BuildContext context) {
    final filteredData = getFilteredData();
    final totals = calculateTotalByCategory(filteredData);
    final categories = totals.keys.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Incoming'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: "Export ke CSV",
            onPressed: () => exportToCSV(totals),
          ),
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: () => selectDateRange(context),
          ),
        ],
      ),
      drawer: CustomDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Tanggal: ${DateFormat('dd MMM yyyy').format(startDate!)} - ${DateFormat('dd MMM yyyy').format(endDate!)}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // ======== CHART ========
            SizedBox(
              height: MediaQuery.of(context).size.width > 600
                  ? 300
                  : 250, // Mengatur tinggi chart responsif
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  barGroups: List.generate(categories.length, (index) {
                    final category = categories[index];
                    final color = categoryColors[category] ?? Colors.grey;
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: totals[category]!.toDouble(),
                          color: color,
                          width: 20,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    );
                  }),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= 0 &&
                              value.toInt() < categories.length) {
                            return Text(
                              categories[value.toInt()],
                              style: const TextStyle(fontSize: 10),
                              textAlign: TextAlign.center,
                            );
                          }
                          return const SizedBox();
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(show: true),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ======== GRID VIEW DATA ========
            Expanded(
              child: GridView.count(
                crossAxisCount: MediaQuery.of(context).size.width > 600 ? 6 : 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: totals.entries.map((entry) {
                  return buildCategoryCard(entry.key, entry.value);
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildCategoryCard(String category, int total) {
    final icon = getIconForCategory(category);
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40),
            const SizedBox(height: 10),
            Text(
              category,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text('$total kg', style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }

  IconData getIconForCategory(String category) {
    switch (category) {
      case 'Wet Chicken Dada':
        return Icons.set_meal;
      case 'Wet Chicken Paha':
        return Icons.restaurant;
      case 'Sayuran':
        return Icons.eco;
      case 'Udang':
        return Icons.rice_bowl;
      case 'Dry':
        return Icons.inventory_2;
      case 'Ice':
        return Icons.ac_unit;
      default:
        return Icons.category;
    }
  }
}
