import 'package:flutter/material.dart';
import '../widgets/custom_drawer.dart';

class Menu2Page extends StatelessWidget {
  final List<Map<String, String>> data = [
    {
      'faktur': '6NP4U',
      'unit': 'CK 2',
      'type': 'Wet Chicken',
      'supplier': 'CV. Wahana Sejahtera',
      'date': '04 Aug 2025, 12:41',
    },
    {
      'faktur': 'CJJPL',
      'unit': 'CK 2',
      'type': 'Wet Chicken',
      'supplier': 'CV. Wahana Sejahtera',
      'date': '04 Aug 2025, 12:13',
    },
    {
      'faktur': '6JZZ7',
      'unit': 'CK 2',
      'type': 'Wet Chicken',
      'supplier': 'CV. Wahana Sejahtera',
      'date': '04 Aug 2025, 11:59',
    },
    {
      'faktur': 'DSE4J',
      'unit': 'CK 2',
      'type': 'Wet Chicken',
      'supplier': 'Restu jaya',
      'date': '31 Jul 2025, 19:27',
    },
    {
      'faktur': '3YEF8',
      'unit': 'CK 2',
      'type': 'Wet Chicken',
      'supplier': 'Restu jaya',
      'date': '31 Jul 2025, 19:19',
    },
    {
      'faktur': 'E2T0Z',
      'unit': 'CK 2',
      'type': 'Wet Chicken',
      'supplier': 'Restu jaya',
      'date': '31 Jul 2025, 19:15',
    },
    {
      'faktur': 'JM8RN',
      'unit': 'CK 2',
      'type': 'Wet Chicken',
      'supplier': 'Restu jaya',
      'date': '31 Jul 2025, 19:13',
    },
    {
      'faktur': 'JVDMR',
      'unit': 'CK 2',
      'type': 'Wet Chicken',
      'supplier': 'PT. Janu Putra',
      'date': '26 Jul 2025, 14:49',
    },
    {
      'faktur': 'G36TY',
      'unit': 'CK 2',
      'type': 'Wet Chicken',
      'supplier': 'CV. Wahana Sejahtera',
      'date': '23 Jul 2025, 22:34',
    },
    {
      'faktur': 'VD452',
      'unit': 'CK 2',
      'type': 'Wet Chicken',
      'supplier': 'PT. Janu Putra',
      'date': '23 Jul 2025, 17:20',
    },
    {
      'faktur': 'LS2QS',
      'unit': 'CK 2',
      'type': 'Wet Chicken',
      'supplier': 'Restu jaya',
      'date': '23 Jul 2025, 14:40',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Incoming Raw Materials'),
        actions: [
          IconButton(
            icon: Icon(Icons.filter_alt_outlined),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(Icons.person),
            onPressed: () {},
          ),
        ],
      ),
      drawer: CustomDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTable(
                    headingRowColor: MaterialStateProperty.all(Colors.blue[50]),
                    columnSpacing: 24,
                    columns: [
                      DataColumn(
                        label: Row(
                          children: [
                            Text('Faktur'),
                            Icon(Icons.swap_vert, size: 16, color: Colors.grey),
                          ],
                        ),
                      ),
                      DataColumn(
                        label: Text('Unit'),
                      ),
                      DataColumn(
                        label: Row(
                          children: [
                            Text('Type'),
                            Icon(Icons.swap_vert, size: 16, color: Colors.grey),
                          ],
                        ),
                      ),
                      DataColumn(
                        label: Row(
                          children: [
                            Text('Supplier'),
                            Icon(Icons.swap_vert, size: 16, color: Colors.grey),
                          ],
                        ),
                      ),
                      DataColumn(
                        label: Row(
                          children: [
                            Text('Date'),
                            Icon(Icons.swap_vert, size: 16, color: Colors.grey),
                          ],
                        ),
                      ),
                    ],
                    rows: data.map((row) {
                      return DataRow(
                        cells: [
                          DataCell(Text(row['faktur'] ?? '')),
                          DataCell(
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                row['unit'] ?? '',
                                style: TextStyle(
                                  color: Colors.blue[900],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                          DataCell(Text(row['type'] ?? '')),
                          DataCell(Text(row['supplier'] ?? '')),
                          DataCell(Text(row['date'] ?? '')),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
