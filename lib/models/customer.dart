class Customer {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String address;
  final double dueBalance;
  final String followUpNotes;
  final DateTime? nextFollowUpDate;
  final DateTime? lastContactDate;

  Customer({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    this.dueBalance = 0.0,
    this.followUpNotes = '',
    this.nextFollowUpDate,
    this.lastContactDate,
  });

  Customer copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? address,
    double? dueBalance,
    String? followUpNotes,
    DateTime? nextFollowUpDate,
    DateTime? lastContactDate,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      dueBalance: dueBalance ?? this.dueBalance,
      followUpNotes: followUpNotes ?? this.followUpNotes,
      nextFollowUpDate: nextFollowUpDate ?? this.nextFollowUpDate,
      lastContactDate: lastContactDate ?? this.lastContactDate,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'address': address,
        'dueBalance': dueBalance,
        'followUpNotes': followUpNotes,
        'nextFollowUpDate': nextFollowUpDate?.toIso8601String(),
        'lastContactDate': lastContactDate?.toIso8601String(),
      };

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
        id: json['id'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
        phone: json['phone'] as String,
        address: json['address'] as String,
        dueBalance: (json['dueBalance'] as num?)?.toDouble() ?? 0.0,
        followUpNotes: (json['followUpNotes'] as String?) ?? '',
        nextFollowUpDate: json['nextFollowUpDate'] != null ? DateTime.parse(json['nextFollowUpDate'] as String) : null,
        lastContactDate: json['lastContactDate'] != null ? DateTime.parse(json['lastContactDate'] as String) : null,
      );
}
