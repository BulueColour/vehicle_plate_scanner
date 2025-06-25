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
      licensePlateNumber: map['license_plate_number'] ?? '',
      email: map['email'] ?? '',
      phoneNumber: map['phone_number'] ?? '',
      name: map['name'],
      facebook: map['facebook'],
      additionalInfo: map['additional_info'],
      createAt: map['create_at']?.toDate() ?? DateTime.now(),
      updateAt: map['update_at']?.toDate(),
    );
  }

  // Convert UserModel to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'license_plate_number': licensePlateNumber,
      'email': email,
      'phone_number': phoneNumber,
      'name': name,
      'facebook': facebook,
      'additional_info': additionalInfo,
      'create_at': createAt,
      'update_at': updateAt,
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
  
  // เพิ่มฟังก์ชันช่วยตรวจสอบข้อมูล
  bool get isComplete {
    return uid.isNotEmpty && licensePlateNumber.isNotEmpty && email.isNotEmpty && phoneNumber.isNotEmpty;
  }

  // เพิ่มฟังก์ชันตรวจสอบว่ามีชื่อหรือไม่
  bool get hasName {
    return name != null && name!.isNotEmpty;
  }

  // เพิ่มฟังก์ชันตรวจสอบว่ามี facebook หรือไม่
  bool get hasFacebook {
    return facebook != null && facebook!.isNotEmpty;
  }

  // เพิ่มฟังก์ชันเช็คว่าเป็นข้อมูลใหม่หรือไม่
  bool get isNew {
    return updateAt == null;
  }
}