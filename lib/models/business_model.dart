class BusinessModel {

  int? businessId;
  String name;
  String createdAt;

  BusinessModel({
    this.businessId,
    required this.name,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {

    return {
      'business_id': businessId,
      'name': name,
      'created_at': createdAt,
    };
  }

  factory BusinessModel.fromMap(Map<String, dynamic> map) {

    return BusinessModel(
      businessId: map['business_id'],
      name: map['name'],
      createdAt: map['created_at'],
    );
  }
}