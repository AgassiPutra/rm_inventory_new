import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:csv/csv.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/incoming_data.dart';
import '../widgets/custom_drawer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/auth.dart';

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
  List<IncomingData> allData = [];
  bool isLoading = true;
  bool isExporting = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    startDate = DateTime(now.year, now.month, 1);
    endDate = DateTime(now.year, now.month, now.day);
    fetchDataFromAPI();
    Auth.check(context);
  }

  Future<void> fetchDataFromAPI() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Token tidak ditemukan, silakan login ulang'),
        ),
      );
      return;
    }
    final DateFormat formatter = DateFormat('yyyy-MM-dd');
    final String tanggalAwal = formatter.format(startDate!);
    final String tanggalAkhir = formatter.format(endDate!);

    final url =
        'https://api-gts-rm.scm-ppa.com/gtsrm/api/incoming-rm?tanggalAwal=$tanggalAwal&tanggalAkhir=$tanggalAkhir';

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final List<dynamic> dataList = decoded['data'];

        setState(() {
          allData = dataList
              .map((json) => IncomingData.fromJson(json))
              .toList();
          isLoading = false;
        });
      } else if (response.statusCode == 401) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unauthorized: Token tidak valid atau expired'),
          ),
        );
      } else {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengambil data: ${response.statusCode}'),
          ),
        );
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saat fetch data: $e')));
    }
  }

  Future<void> exportToCSV(Map<String, double> totals) async {
    try {
      List<List<dynamic>> rows = [
        ["Kategori", "Total (kg)"],
      ];

      totals.forEach((category, total) {
        rows.add([category, total.toStringAsFixed(2)]);
      });

      String csvData = const ListToCsvConverter().convert(rows);

      final directory = await getApplicationDocumentsDirectory();
      final path =
          "${directory.path}/dashboard_incoming_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv";

      final file = File(path);
      await file.writeAsString(csvData);

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
        isLoading = true;
      });
      await fetchDataFromAPI();
    }
  }

  List<IncomingData> getFilteredData() {
    return allData.where((data) {
      final tanggal = DateTime(
        data.tanggalIncoming.year,
        data.tanggalIncoming.month,
        data.tanggalIncoming.day,
      );
      final start = DateTime(startDate!.year, startDate!.month, startDate!.day);
      final end = DateTime(endDate!.year, endDate!.month, endDate!.day);
      return (tanggal.isAtSameMomentAs(start) || tanggal.isAfter(start)) &&
          (tanggal.isAtSameMomentAs(end) || tanggal.isBefore(end));
    }).toList();
  }

  Map<String, double> calculateTotalByCategory(List<IncomingData> dataList) {
    Map<String, double> totals = {};
    for (var data in dataList) {
      totals[data.jenisRm] = (totals[data.jenisRm] ?? 0) + data.qtyIn;
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
            icon: isExporting
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.download),
            tooltip: "Export ke CSV",
            onPressed: isLoading || isExporting
                ? null
                : () async {
                    setState(() => isExporting = true);
                    await exportToCSV(totals);
                    setState(() => isExporting = false);
                  },
          ),
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: isLoading ? null : () => selectDateRange(context),
          ),
        ],
      ),
      drawer: CustomDrawer(),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    'Tanggal: ${DateFormat('dd MMM yyyy').format(startDate!)} - ${DateFormat('dd MMM yyyy').format(endDate!)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: MediaQuery.of(context).size.width > 600 ? 300 : 250,
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
                                toY: totals[category]!,
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
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: MediaQuery.of(context).size.width > 600
                          ? 6
                          : 2,
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

  Widget buildCategoryCard(String category, double total) {
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
            Text(
              '${total.toStringAsFixed(2)} kg',
              style: const TextStyle(fontSize: 16),
            ),
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
