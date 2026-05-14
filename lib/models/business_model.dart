class BusinessModel {
  int? businessId;
  String name;
  String type;
  String createdAt;

  BusinessModel({
    this.businessId,
    required this.name,
    required this.type,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'business_id': businessId,
      'name': name,
      'type': type,
      'created_at': createdAt,
    };
  }

  factory BusinessModel.fromMap(Map<String, dynamic> map) {
    return BusinessModel(
      businessId: map['business_id'],
      name: map['name'],
      type: map['type'],
      createdAt: map['created_at'],
    );
  }
}
