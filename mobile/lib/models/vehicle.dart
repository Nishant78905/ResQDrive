class Vehicle {
  const Vehicle({
    required this.id,
    required this.plateNumber,
    required this.model,
    required this.color,
    this.selected = false,
  });

  final String id;
  final String plateNumber;
  final String model;
  final String color;
  final bool selected;

  Vehicle copyWith({String? id, String? plateNumber, String? model, String? color, bool? selected}) => Vehicle(
        id: id ?? this.id,
        plateNumber: plateNumber ?? this.plateNumber,
        model: model ?? this.model,
        color: color ?? this.color,
        selected: selected ?? this.selected,
      );

  factory Vehicle.fromJson(Map<String, dynamic> json) => Vehicle(
        id: '${json['id']}',
        plateNumber: json['plate_number'] as String? ?? json['plateNumber'] as String? ?? '',
        model: json['model'] as String? ?? '',
        color: json['color'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {'plateNumber': plateNumber, 'model': model, 'color': color};
}