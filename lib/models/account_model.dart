class AccountModel {

  int? accountId;

  int businessId;

  String name;

  String type;

  String? phone;

  String? address;

  double openingBalance;

  String createdAt;

  AccountModel({

    this.accountId,

    required this.businessId,

    required this.name,

    required this.type,

    this.phone,

    this.address,

    required this.openingBalance,

    required this.createdAt,
  });

  Map<String, dynamic> toMap() {

    return {

      'account_id': accountId,

      'business_id': businessId,

      'name': name,

      'type': type,

      'phone': phone,

      'address': address,

      'opening_balance':
          openingBalance,

      'created_at': createdAt,
    };
  }

  factory AccountModel.fromMap(
    Map<String, dynamic> map,
  ) {

    return AccountModel(

      accountId:
          map['account_id'],

      businessId:
          map['business_id'],

      name:
          map['name'],

      type:
          map['type'],

      phone:
          map['phone'],

      address:
          map['address'],

      openingBalance:
          map['opening_balance'],

      createdAt:
          map['created_at'],
    );
  }
}