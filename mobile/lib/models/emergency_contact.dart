class EmergencyContact {
  const EmergencyContact({
    required this.id,
    required this.fullName,
    required this.relationship,
    required this.phone,
    this.email = '',
    this.preferredChannel = 'SMS',
    this.priority = 1,
    this.notificationEnabled = false,
  });

  final String id;
  final String fullName;
  final String relationship;
  final String phone;
  final String email;
  final String preferredChannel;
  final int priority;
  final bool notificationEnabled;

  EmergencyContact copyWith({String? id, String? fullName, String? relationship, String? phone, String? email, String? preferredChannel, int? priority, bool? notificationEnabled}) => EmergencyContact(
        id: id ?? this.id,
        fullName: fullName ?? this.fullName,
        relationship: relationship ?? this.relationship,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        preferredChannel: preferredChannel ?? this.preferredChannel,
        priority: priority ?? this.priority,
        notificationEnabled: notificationEnabled ?? this.notificationEnabled,
      );

  factory EmergencyContact.fromJson(Map<String, dynamic> json) => EmergencyContact(
        id: '${json['id']}',
        fullName: json['full_name'] as String? ?? json['fullName'] as String? ?? '',
        relationship: json['relationship'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        email: json['email'] as String? ?? '',
        preferredChannel: json['preferred_channel'] as String? ?? 'SMS',
        priority: (json['priority'] as num?)?.toInt() ?? 1,
        notificationEnabled: json['notification_enabled'] as bool? ?? json['notificationEnabled'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'fullName': fullName,
        'relationship': relationship,
        'phone': phone,
        'email': email.isEmpty ? null : email,
        'preferredChannel': preferredChannel,
        'priority': priority,
        'notificationEnabled': notificationEnabled,
      };
}
