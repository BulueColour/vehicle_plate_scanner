class UserModel {
  final String uid; // user_id จาก Firebase Auth
  final String licensePlateNumber; // license_plate_number (UNIQUE, REQUIRED)
  final String email; // email (UNIQUE, REQUIRED)
  final String phoneNumber; // phone_number (REQUIRED)
  final String? name; // name (OPTIONAL)
  final String? facebook; // facebook (OPTIONAL)
  final String? additionalInfo; // additional_info (OPTIONAL)
  final DateTime createAt; // create_at
  final DateTime? updateAt; // update_at

  UserModel({
    required this.uid,
    required this.licensePlateNumber,
    required this.email,
    required this.phoneNumber,
    this.name,
    this.facebook,
    this.additionalInfo,
    required this.createAt,
    this.updateAt,
  });

  // Convert from Firestore document to UserModel
  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    return UserModel(
      uid: uid,
      licensePlateNumber: map['licensePlateNumber'] ?? '',
      email: map['email'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      name: map['name'],
      facebook: map['facebook'],
      additionalInfo: map['additionalInfo'],
      createAt: map['createAt']?.toDate() ?? DateTime.now(),
      updateAt: map['updateAt']?.toDate(),
    );
  }

  // Convert UserModel to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'licensePlateNumber': licensePlateNumber,
      'email': email,
      'phoneNumber': phoneNumber,
      'name': name,
      'facebook': facebook,
      'additionalInfo': additionalInfo,
      'createAt': createAt,
      'updateAt': updateAt,
    };
  }

  // Create copy with updated fields (auto-update updateAt)
  UserModel copyWith({
    String? licensePlateNumber,
    String? email,
    String? phoneNumber,
    String? name,
    String? facebook,
    String? additionalInfo,
    DateTime? createAt,
  }) {
    return UserModel(
      uid: uid,
      licensePlateNumber: licensePlateNumber ?? this.licensePlateNumber,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      name: name ?? this.name,
      facebook: facebook ?? this.facebook,
      additionalInfo: additionalInfo ?? this.additionalInfo,
      createAt: createAt ?? this.createAt,
      updateAt: DateTime.now(), // Auto-update timestamp
    );
  }

  @override
  String toString() {
    return 'UserModel(uid: $uid, licensePlateNumber: $licensePlateNumber, email: $email, phoneNumber: $phoneNumber, name: $name)';
  }
}