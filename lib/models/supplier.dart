class Supplier {
  final String id;
  final String name;
  final String companyName;
  final String phone;
  final String email;
  final String address;
  final double balanceDue;

  Supplier({
    required this.id,
    required this.name,
    required this.companyName,
    required this.phone,
    required this.email,
    required this.address,
    this.balanceDue = 0.0,
  });

  Supplier copyWith({
    String? id,
    String? name,
    String? companyName,
    String? phone,
    String? email,
    String? address,
    double? balanceDue,
  }) {
    return Supplier(
      id: id ?? this.id,
      name: name ?? this.name,
      companyName: companyName ?? this.companyName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      balanceDue: balanceDue ?? this.balanceDue,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'companyName': companyName,
        'phone': phone,
        'email': email,
        'address': address,
        'balanceDue': balanceDue,
      };

  factory Supplier.fromJson(Map<String, dynamic> json) => Supplier(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        companyName: json['companyName'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        email: json['email'] as String? ?? '',
        address: json['address'] as String? ?? '',
        balanceDue: (json['balanceDue'] as num?)?.toDouble() ?? 0.0,
      );
}
