class UserModel {
  final String uid; // user_id จาก Firebase Auth
  final String? licensePlateNumber; // license_plate_number (OPTIONAL ให้ยืดหยุ่นมากขึ้น)
  final String email; // email (UNIQUE, REQUIRED)
  final String? phoneNumber; // phone_number (OPTIONAL เพราะอาจยังไม่ได้กรอก)
  final String? name; // name (OPTIONAL)
  final String? facebook; // facebook (OPTIONAL)
  final String? additionalInfo; // additional_info (OPTIONAL)
  final DateTime createAt; // create_at
  final DateTime? updateAt; // update_at

  UserModel({
    required this.uid,
    this.licensePlateNumber,
    required this.email,
    this.phoneNumber,
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
      licensePlateNumber: _getNullableString(map['license_plate_number']),
      email: map['email'] ?? '',
      phoneNumber: _getNullableString(map['phone_number']),
      name: _getNullableString(map['name']),
      facebook: _getNullableString(map['facebook']),
      additionalInfo: _getNullableString(map['additional_info']),
      createAt: map['create_at']?.toDate() ?? DateTime.now(),
      updateAt: map['update_at']?.toDate(),
    );
  }

  // Helper method เพื่อจัดการ null/empty strings
  static String? _getNullableString(dynamic value) {
    if (value == null) return null;
    final stringValue = value.toString().trim();
    return stringValue.isEmpty ? null : stringValue;
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
      updateAt: DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'UserModel(uid: $uid, licensePlateNumber: $licensePlateNumber, email: $email, phoneNumber: $phoneNumber, name: $name)';
  }
  
  // ฟังก์ชันตรวจสอบข้อมูลหลัก
  bool get isComplete {
    return uid.isNotEmpty && email.isNotEmpty;
  }

  // ตรวจสอบว่ามีป้ายทะเบียนหรือไม่
  bool get hasLicensePlate {
    return licensePlateNumber != null && licensePlateNumber!.isNotEmpty;
  }

  // ตรวจสอบว่ามีชื่อหรือไม่
  bool get hasName {
    return name != null && name!.isNotEmpty;
  }

  // ตรวจสอบว่ามีเบอร์โทรหรือไม่
  bool get hasPhoneNumber {
    return phoneNumber != null && phoneNumber!.isNotEmpty;
  }

  // ตรวจสอบว่ามี Facebook หรือไม่
  bool get hasFacebook {
    return facebook != null && facebook!.isNotEmpty;
  }

  // ตรวจสอบว่าเป็นข้อมูลใหม่หรือไม่
  bool get isNew {
    return updateAt == null;
  }

  // ฟังก์ชันสำหรับแสดงชื่อที่เหมาะสม
  String get displayName {
    if (hasName) return name!;
    if (hasLicensePlate) return licensePlateNumber!;
    return email;
  }
}