import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:csv/csv.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/incoming_data.dart'; // Pastikan path ini benar
import '../widgets/custom_drawer.dart'; // Pastikan path ini benar
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/auth.dart'; // Pastikan path ini benar

class DashboardPage extends StatefulWidget {
  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  // Controller untuk field tanggal
  final tanggalAwalController = TextEditingController();
  final tanggalAkhirController = TextEditingController();

  final Map<String, Color> categoryColors = {
    'Wet Chicken Dada': Colors.red,
    'Wet Chicken Paha': Colors.orange,
    'Sayuran': Colors.green,
    'Udang': Colors.pink,
    'Dry': Colors.brown,
    'Ice': Colors.blue,
  };

  List<IncomingData> allData = [];
  bool isLoading = true;
  bool isExporting = false;

  @override
  void initState() {
    super.initState();

    // Set tanggal default (1 bulan lalu s/d 1 bulan ini)
    final now = DateTime.now();
    final firstDayOfCurrentMonth = DateTime(now.year, now.month, 1);
    final firstDayOfPreviousMonth = DateTime(now.year, now.month - 1, 1);
    final DateFormat formatter = DateFormat('yyyy-MM-dd');

    tanggalAwalController.text = formatter.format(firstDayOfPreviousMonth);
    tanggalAkhirController.text = formatter.format(firstDayOfCurrentMonth);

    // Panggil API dengan tanggal default
    fetchDataFromAPI();
    Auth.check(context);
  }

  @override
  void dispose() {
    tanggalAwalController.dispose();
    tanggalAkhirController.dispose();
    super.dispose();
  }

  Future<String?> getLokasiUnit() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jenis_unit');
  }

  Future<void> fetchDataFromAPI() async {
    if (!isLoading) {
      setState(() {
        isLoading = true;
      });
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Token tidak ditemukan, silakan login ulang'),
        ),
      );
      return;
    }

    final String? lokasiUnit = await getLokasiUnit();
    if (lokasiUnit == null || lokasiUnit.isEmpty) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lokasi unit tidak terdeteksi. Silakan login ulang.'),
        ),
      );
      return;
    }

    const String baseUrl =
        'https://trial-api-gts-rm.scm-ppa.com/gtsrm/api/incoming-rm';

    final Map<String, String> queryParams = {'lokasi_unit': lokasiUnit};

    final String tanggalAwal = tanggalAwalController.text.trim();
    final String tanggalAkhir = tanggalAkhirController.text.trim();

    if (tanggalAwal.isNotEmpty) {
      queryParams['tanggalAwal'] = tanggalAwal;
    }
    if (tanggalAkhir.isNotEmpty) {
      queryParams['tanggalAkhir'] = tanggalAkhir;
    }

    final Uri uri = Uri.parse(baseUrl).replace(queryParameters: queryParams);
    final String url = uri.toString();
    print('Fetching URL: $url');

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

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

  Future<void> _selectDate(
    BuildContext context,
    TextEditingController controller,
  ) async {
    DateTime initialDate = DateTime.now();
    if (controller.text.isNotEmpty) {
      initialDate = DateTime.tryParse(controller.text) ?? DateTime.now();
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        controller.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
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
    final totals = calculateTotalByCategory(allData);
    final categories = totals.keys.toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 2.0,
        iconTheme: IconThemeData(color: Colors.black87),
        title: const Text(
          'Dashboard Incoming',
          style: TextStyle(color: Colors.black87),
        ),
        actions: [
          IconButton(
            icon: isExporting
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Theme.of(context).primaryColor,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.download),
            color: Colors.black87,
            tooltip: "Export ke CSV",
            onPressed: isLoading || isExporting
                ? null
                : () async {
                    setState(() => isExporting = true);
                    await exportToCSV(totals);
                    setState(() => isExporting = false);
                  },
          ),
        ],
        bottom: _buildAppBarFilter(),
      ),
      drawer: CustomDrawer(),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: isLoading
              ? const Center(
                  heightFactor: 10,
                  child: CircularProgressIndicator(),
                )
              : Column(
                  children: [
                    Text(
                      'Tanggal: ${tanggalAwalController.text} - ${tanggalAkhirController.text}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: MediaQuery.of(context).size.width > 600
                          ? 300
                          : 250,
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          barGroups: List.generate(categories.length, (index) {
                            final category = categories[index];
                            final color =
                                categoryColors[category] ?? Colors.grey;
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
                    GridView.count(
                      crossAxisCount: MediaQuery.of(context).size.width > 600
                          ? 6
                          : 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: totals.entries.map((entry) {
                        return buildCategoryCard(entry.key, entry.value);
                      }).toList(),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBarFilter() {
    final screenWidth = MediaQuery.of(context).size.width;
    bool isNarrow = screenWidth < 450;
    double preferredHeight = isNarrow ? 120.0 : 70.0;

    return PreferredSize(
      preferredSize: Size.fromHeight(preferredHeight),
      child: Container(
        color: Colors.grey[200],
        padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 12.0),
        child: isNarrow ? _buildNarrowFilter() : _buildWideFilter(),
      ),
    );
  }

  Widget _buildWideFilter() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: _buildTanggalAwalField()),
        const SizedBox(width: 12),
        Expanded(child: _buildTanggalAkhirField()),
        const SizedBox(width: 8),
        _buildAmbilDataButton(),
      ],
    );
  }

  Widget _buildNarrowFilter() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(child: _buildTanggalAwalField()),
            const SizedBox(width: 12),
            Expanded(child: _buildTanggalAkhirField()),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(width: double.infinity, child: _buildAmbilDataButton()),
      ],
    );
  }

  Widget _buildTanggalAwalField() {
    return TextField(
      controller: tanggalAwalController,
      readOnly: true,
      style: TextStyle(color: Colors.black87, fontSize: 14),
      decoration: InputDecoration(
        labelText: 'Tanggal Awal',
        labelStyle: TextStyle(color: Colors.grey[700], fontSize: 12),
        suffixIcon: Icon(
          Icons.calendar_today,
          color: Colors.grey[700],
          size: 20,
        ),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide(
            color: Theme.of(context).primaryColor,
            width: 2.0,
          ),
        ),
      ),
      onTap: () => _selectDate(context, tanggalAwalController),
    );
  }

  Widget _buildTanggalAkhirField() {
    return TextField(
      controller: tanggalAkhirController,
      readOnly: true,
      style: TextStyle(color: Colors.black87, fontSize: 14),
      decoration: InputDecoration(
        labelText: 'Tanggal Akhir',
        labelStyle: TextStyle(color: Colors.grey[700], fontSize: 12),
        suffixIcon: Icon(
          Icons.calendar_today,
          color: Colors.grey[700],
          size: 20,
        ),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide(
            color: Theme.of(context).primaryColor,
            width: 2.0,
          ),
        ),
      ),
      onTap: () => _selectDate(context, tanggalAkhirController),
    );
  }

  Widget _buildAmbilDataButton() {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        textStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      ),
      onPressed: isLoading ? null : fetchDataFromAPI,
      child: Text('Ambil Data'),
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
