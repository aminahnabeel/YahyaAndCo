class UserModel {

  int? userId;

  String firebaseUid;

  String name;

  String email;

  String? password;

  int isVerified;

  String createdAt;

  UserModel({

    this.userId,

    required this.firebaseUid,

    required this.name,

    required this.email,

    this.password,

    required this.isVerified,

    required this.createdAt,
  });

  Map<String, dynamic> toMap() {

    return {

      'user_id': userId,

      'firebase_uid': firebaseUid,

      'name': name,

      'email': email,

      'password': password,

      'is_verified': isVerified,

      'created_at': createdAt,
    };
  }

  factory UserModel.fromMap(
    Map<String, dynamic> map,
  ) {

    return UserModel(

      userId:
          map['user_id'],

      firebaseUid:
          map['firebase_uid'],

      name:
          map['name'],

      email:
          map['email'],

      password: map['password'],

      isVerified:
          map['is_verified'],

      createdAt:
          map['created_at'],
    );
  }
}