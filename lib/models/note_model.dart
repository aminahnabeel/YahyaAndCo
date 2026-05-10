class NoteModel {

  int? noteId;

  int businessId;

  String title;

  String description;

  String createdAt;

  NoteModel({

    this.noteId,

    required this.businessId,

    required this.title,

    required this.description,

    required this.createdAt,
  });

  Map<String, dynamic> toMap() {

    return {

      'note_id': noteId,

      'business_id': businessId,

      'title': title,

      'description': description,

      'created_at': createdAt,
    };
  }

  factory NoteModel.fromMap(
    Map<String, dynamic> map,
  ) {

    return NoteModel(

      noteId:
          map['note_id'],

      businessId:
          map['business_id'],

      title:
          map['title'],

      description:
          map['description'],

      createdAt:
          map['created_at'],
    );
  }
}