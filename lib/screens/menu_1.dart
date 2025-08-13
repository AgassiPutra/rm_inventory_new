import 'package:flutter/material.dart';
import '../widgets/custom_drawer.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class Menu1Page extends StatefulWidget {
  @override
  State<Menu1Page> createState() => _Menu1PageState();
}

class _Menu1PageState extends State<Menu1Page> {
  late String currentTime;
  late TextEditingController currentTimeController;
  late TextEditingController shiftController;

  final ImagePicker _picker = ImagePicker();

  XFile? invoiceFile;
  XFile? suratJalanFile;

  List<BluetoothDevice> foundDevices = [];
  BluetoothDevice? connectedDevice;
  String bluetoothStatus = "No scales found";

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();
    currentTime =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    currentTimeController = TextEditingController(text: currentTime);
    shiftController = TextEditingController(text: 'Shift 2');
  }

  @override
  void dispose() {
    currentTimeController.dispose();
    shiftController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(Function(XFile?) onPicked) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    onPicked(image);
  }

  Future<void> scanForDevices() async {
    await Permission.location.request();
    await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();

    setState(() {
      foundDevices.clear();
      bluetoothStatus = "Scanning...";
    });

    final subscription = FlutterBluePlus.onScanResults.listen((results) {
      for (ScanResult r in results) {
        if (!foundDevices.any((d) => d.id == r.device.id)) {
          setState(() {
            foundDevices.add(r.device);
          });
        }
      }
    });

    await FlutterBluePlus.startScan(timeout: Duration(seconds: 4));
    await Future.delayed(Duration(seconds: 4));
    await FlutterBluePlus.stopScan();
    await subscription.cancel();

    setState(() {
      if (foundDevices.isEmpty) {
        bluetoothStatus = "No scales found";
      } else {
        bluetoothStatus = "Device(s) found";
      }
    });
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    await device.connect();
    setState(() {
      connectedDevice = device;
      bluetoothStatus = "Connected to ${device.name}";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Raw Material Incoming Form'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              final now = DateTime.now();
              setState(() {
                currentTime =
                    "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
                currentTimeController.text = currentTime;
              });
            },
          ),
          IconButton(icon: Icon(Icons.person), onPressed: () {}),
        ],
      ),
      drawer: CustomDrawer(),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              padding: EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Current Time', style: TextStyle(fontSize: 12)),
                        SizedBox(height: 4),
                        TextField(
                          enabled: false,
                          controller: currentTimeController,
                          decoration: InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Current Shift', style: TextStyle(fontSize: 12)),
                        SizedBox(height: 4),
                        TextField(
                          enabled: false,
                          controller: shiftController,
                          decoration: InputDecoration(
                            labelText: 'Current Shift',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            Card(
              color: Colors.purple[50],
              margin: EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Upload Invoice Supplier',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 8),
                          Text(
                            invoiceFile == null
                                ? 'Selected File\nNo file selected'
                                : 'Selected File\n${invoiceFile!.name}',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        _pickImage((file) {
                          setState(() {
                            invoiceFile = file;
                          });
                        });
                      },
                      child: Text('Choose File'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Card(
              color: Colors.purple[50],
              margin: EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Upload Surat Jalan',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 8),
                          Text(
                            suratJalanFile == null
                                ? 'Selected File\nNo file selected'
                                : 'Selected File\n${suratJalanFile!.name}',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        _pickImage((file) {
                          setState(() {
                            suratJalanFile = file;
                          });
                        });
                      },
                      child: Text('Choose File'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Unit',
                border: OutlineInputBorder(),
              ),
              items: [
                'CK1',
                'CK2',
                'CK3',
              ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) {},
            ),
            SizedBox(height: 12),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Jenis RM',
                border: OutlineInputBorder(),
              ),
              items: [
                'Wet Chicken Dada',
                'Wet Chicken Paha',
                'Sayuran',
                'Dry',
                'Ice',
              ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) {},
            ),
            SizedBox(height: 12),
            TextFormField(
              decoration: InputDecoration(
                labelText: 'Qty PO',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 12),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Supplier',
                border: OutlineInputBorder(),
              ),
              items: [],
              onChanged: (v) {},
            ),
            SizedBox(height: 12),
            TextFormField(
              decoration: InputDecoration(
                labelText: 'Produsen',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.grey[200],
              ),
              enabled: false,
            ),
            SizedBox(height: 24),
            Center(
              child: ElevatedButton(
                onPressed: () {},
                child: Text('Submit'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            SizedBox(height: 32),
            Card(
              color: Colors.grey[20],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Scale Connection',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {},
                          icon: Icon(
                            Icons.settings,
                            size: 16,
                            color: Colors.grey,
                          ),
                          label: Text(
                            'Debug',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 24),
                    Center(
                      child: Column(
                        children: [
                          ElevatedButton.icon(
                            onPressed: scanForDevices,
                            icon: Icon(Icons.bluetooth, color: Colors.grey),
                            label: Text('Connect to Scale'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.grey,
                              side: BorderSide(color: Colors.grey),
                              shape: StadiumBorder(),
                              elevation: 0,
                            ),
                          ),
                          SizedBox(height: 32),
                          if (bluetoothStatus == "Scanning...")
                            CircularProgressIndicator()
                          else if (bluetoothStatus == "Device(s) found" &&
                              foundDevices.isNotEmpty)
                            Column(
                              children: foundDevices
                                  .map(
                                    (device) => ListTile(
                                      title: Text(
                                        device.name.isNotEmpty
                                            ? device.name
                                            : device.id.toString(),
                                      ),
                                      subtitle: Text(device.id.toString()),
                                      trailing: ElevatedButton(
                                        onPressed: () =>
                                            connectToDevice(device),
                                        child: Text('Connect'),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            )
                          else
                            Column(
                              children: [
                                Icon(
                                  Icons.bluetooth_disabled,
                                  size: 48,
                                  color: Colors.grey[400],
                                ),
                                SizedBox(height: 8),
                                Text(
                                  bluetoothStatus,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Make sure your ESP32 scale is powered on and within range',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
