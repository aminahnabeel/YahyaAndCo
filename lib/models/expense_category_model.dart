class ExpenseCategoryModel {

  int? categoryId;

  int businessId;

  String name;

  ExpenseCategoryModel({

    this.categoryId,

    required this.businessId,

    required this.name,
  });

  Map<String, dynamic> toMap() {

    return {

      'category_id': categoryId,

      'business_id': businessId,

      'name': name,
    };
  }

  factory ExpenseCategoryModel.fromMap(
    Map<String, dynamic> map,
  ) {

    return ExpenseCategoryModel(

      categoryId:
          map['category_id'],

      businessId:
          map['business_id'],

      name:
          map['name'],
    );
  }
}