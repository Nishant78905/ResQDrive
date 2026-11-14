class AccidentRecord {
  const AccidentRecord({required this.id, required this.date, required this.location, required this.status, this.latitude, this.longitude});

  factory AccidentRecord.fromJson(Map<String, dynamic> json) => AccidentRecord(
        id: '${json['id']}',
        date: json['detected_at'] as String? ?? 'Not available',
        location: json['latitude'] != null && json['longitude'] != null ? '${json['latitude']}, ${json['longitude']}' : 'Location unavailable',
        status: json['status'] as String? ?? 'Not available',
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
      );

  final String id;
  final String date;
  final String location;
  final String status;
  final double? latitude;
  final double? longitude;

  String get displayDate {
    final parsed = DateTime.tryParse(date)?.toLocal();
    if (parsed == null) return date;
    final value = parsed.toString();
    return value.length >= 16 ? value.substring(0, 16).replaceFirst('T', ' ') : value;
  }
}
