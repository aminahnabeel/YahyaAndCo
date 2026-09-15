class BusinessModel {
  int? businessId;
  String? firestoreId; // ✅ Firestore document ID
  String? ownerUid;
  String name;
  String type;
  String? pin;
  String createdAt;

  BusinessModel({
    this.businessId,
    this.firestoreId,
    this.ownerUid,
    required this.name,
    required this.type,
    this.pin,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'business_id': businessId,
      'firestore_id': firestoreId, // ✅ Store Firestore ID
      'owner_uid': ownerUid,
      'name': name,
      'type': type,
      'pin': pin,
      'created_at': createdAt,
    };
  }

  factory BusinessModel.fromMap(Map<String, dynamic> map) {
    return BusinessModel(
      businessId: map['business_id'],
      firestoreId: map['firestore_id'],
      ownerUid: map['owner_uid']?.toString(),
      name: map['name'],
      type: map['type'],
      pin: map['pin'],
      createdAt: map['created_at'],
    );
  }
}
