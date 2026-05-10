class AccountModel {

  int? accountId;
  int businessId;
  String name;
  String type;
  String createdAt;

  AccountModel({
    this.accountId,
    required this.businessId,
    required this.name,
    required this.type,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {

    return {
      'account_id': accountId,
      'business_id': businessId,
      'name': name,
      'type': type,
      'created_at': createdAt,
    };
  }

  factory AccountModel.fromMap(Map<String, dynamic> map) {

    return AccountModel(
      accountId: map['account_id'],
      businessId: map['business_id'],
      name: map['name'],
      type: map['type'],
      createdAt: map['created_at'],
    );
  }
}