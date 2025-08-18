class IncomingData {
  final String faktur;
  final DateTime tanggalIncoming;
  final String jenisRm;
  final double qtyIn;

  IncomingData({
    required this.faktur,
    required this.tanggalIncoming,
    required this.jenisRm,
    required this.qtyIn,
  });

  factory IncomingData.fromJson(Map<String, dynamic> json) {
    return IncomingData(
      faktur: json['faktur'],
      tanggalIncoming: DateTime.parse(json['tanggal_incoming']),
      jenisRm: json['jenis_rm'],
      qtyIn: (json['qty_in'] ?? 0).toDouble(), // parsing qty_in
    );
  }
}
