import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Collection reference
  CollectionReference get _usersCollection => _db.collection('users');
  CollectionReference get _reportsCollection => _db.collection('reports');

  // Users

  Future<UserModel?> getUser(String uid) async {
    try {
      DocumentSnapshot doc = await _usersCollection.doc(uid).get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>, uid);
      }
      return null;
    } catch (e) {
      throw 'ไม่สามารถดึงข้อมูลผู้ใช้ได้: $e';
    }
  }

  Future<List<Map<String, dynamic>>> getAllAdmins() async {
    final snapshot = await _db.collection('users').where('role', isEqualTo: 'admin').get();
    return snapshot.docs.map((doc) {
      return {
        'uid': doc.id,
        'name': doc.data()['name'],
        'fcmToken': doc.data()['fcmToken'],
      };
    }).toList();
  }

  // Reports
  
  Future<void> addReport({
    required String userId,
    required String location,
    required String description,
  }) async {
    try {
      await _reportsCollection.add({
        'userId': userId,
        'role': 'users',
        'location': location,
        'description': description,
        'createAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw 'ไม่สามารถเพิ่มรายงานได้: $e';
    }
  }

  Stream<QuerySnapshot> streamReports() {
    return _reportsCollection.orderBy('createAt', descending: true).snapshots();
  }

  // Create user document
  Future<void> createUser(UserModel user) async {
    try {
      await _usersCollection.doc(user.uid).set(user.toMap());
    } catch (e) {
      throw 'ไม่สามารถบันทึกข้อมูลผู้ใช้ได้: $e';
    }
  }

  // Update user with automatic updateAt timestamp
  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    try {
      // Add updateAt timestamp
      data['update_at'] = FieldValue.serverTimestamp();
      await _usersCollection.doc(uid).update(data);
    } catch (e) {
      throw 'ไม่สามารถอัปเดตข้อมูลผู้ใช้ได้: $e';
    }
  }

  // Delete user document
  Future<void> deleteUser(String uid) async {
    try {
      await _usersCollection.doc(uid).delete();
    } catch (e) {
      throw 'ไม่สามารถลบข้อมูลผู้ใช้ได้: $e';
    }
  }

  // Check if license plate number already exists
  Future<bool> isLicensePlateExists(String licensePlateNumber) async {
    try {
      QuerySnapshot query = await _usersCollection
          .where('license_plate_number', isEqualTo: licensePlateNumber)
          .get();
      return query.docs.isNotEmpty;
    } catch (e) {
      throw 'ไม่สามารถตรวจสอบป้ายทะเบียนได้: $e';
    }
  }

  // Get user by license plate number
  Future<UserModel?> getUserByLicensePlate(String licensePlateNumber) async {
    try {
      QuerySnapshot query = await _usersCollection
          .where('license_plate_number', isEqualTo: licensePlateNumber)
          .get();

      if (query.docs.isNotEmpty) {
        DocumentSnapshot doc = query.docs.first;
        return UserModel.fromMap(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
      }
      return null;
    } catch (e) {
      throw 'ไม่สามารถค้นหาข้อมูลจากป้ายทะเบียนได้: $e';
    }
  }

  // Get all users (for admin purposes)
  Future<List<UserModel>> getAllUsers() async {
    try {
      QuerySnapshot query =
          await _usersCollection.orderBy('create_at', descending: true).get();

      return query.docs.map((doc) {
        return UserModel.fromMap(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
      }).toList();
    } catch (e) {
      throw 'ไม่สามารถดึงข้อมูลผู้ใช้ทั้งหมดได้: $e';
    }
  }

  // Stream user data (real-time updates)
  Stream<UserModel?> streamUser(String uid) {
    return _usersCollection.doc(uid).snapshots().map((doc) {
      if (doc.exists) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>, uid);
      }
      return null;
    });
  }

  // Update specific fields with methods
  Future<void> updateUserName(String uid, String name) async {
    try {
      await _usersCollection.doc(uid).update({
        'name': name,
        'update_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw 'ไม่สามารถอัปเดตชื่อผู้ใช้ได้: $e';
    }
  }

  // Update Facebook profile
  Future<void> updateUserFacebook(String uid, String facebook) async {
    try {
      await _usersCollection.doc(uid).update({
        'facebook': facebook,
        'update_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw 'ไม่สามารถอัปเดต Facebook ได้: $e';
    }
  }

  // Update additional info
  Future<void> updateAdditionalInfo(String uid, String additionalInfo) async {
    try {
      await _usersCollection.doc(uid).update({
        'additional_info': additionalInfo,
        'update_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw 'ไม่สามารถอัปเดตข้อมูลเพิ่มเติมได้: $e';
    }
  }

  // ฟังก์ชันหลักสำหรับอัปเดตข้อมูลผู้ใช้ (แบบเดิม - required ทุกฟิลด์)
  Future<void> updateUserProfile({
    required String uid,
    required String name,
    required String phoneNumber,
    String? licensePlateNumber,
    String? facebook,
    String? additionalInfo,
  }) async {
    try {
      // สร้าง Map สำหรับข้อมูลที่จะอัปเดต
      Map<String, dynamic> updateData = {
        'name': name,
        'phone_number': phoneNumber,
        'update_at': FieldValue.serverTimestamp(),
      };

      // เพิ่มข้อมูลที่ไม่เป็น null
      if (licensePlateNumber != null && licensePlateNumber.isNotEmpty) {
        updateData['license_plate_number'] = licensePlateNumber;
      }

      if (facebook != null && facebook.isNotEmpty) {
        updateData['facebook'] = facebook;
      }

      if (additionalInfo != null && additionalInfo.isNotEmpty) {
        updateData['additional_info'] = additionalInfo;
      }

      print('Updating user profile with data: $updateData');

      await _usersCollection.doc(uid).update(updateData);
      
      print('Profile updated successfully in Firestore');
    } catch (e) {
      print('Error updating user profile: $e');
      throw 'ไม่สามารถอัปเดตข้อมูลได้: $e';
    }
  }

  // **Method ใหม่สำหรับการอัปเดตแบบยืดหยุ่น และรองรับการลบข้อมูล**
  Future<void> updateUserProfileFlexible({
  required String uid,
  required Map<String, dynamic> updateData,
}) async {
  try {
    if (updateData.isEmpty) {
      print('No data to update');
      return;
    }

    // แปลง field names ให้ตรงกับ Firestore
    final Map<String, dynamic> firestoreData = {};
    
    updateData.forEach((key, value) {
      switch (key) {
        case 'name':
          firestoreData['name'] = value; // รองรับทั้ง null และ empty string
          break;
        case 'phoneNumber':
          firestoreData['phone_number'] = value;
          break;
        case 'licensePlateNumber':
          firestoreData['license_plate_number'] = value;
          break;
        case 'facebook':
          firestoreData['facebook'] = value;
          break;
        case 'additionalInfo':
          firestoreData['additional_info'] = value;
          break;
        default:
          firestoreData[key] = value;
      }
    });

    // เพิ่ม timestamp การอัปเดต
    firestoreData['update_at'] = FieldValue.serverTimestamp();

    print('Updating user profile flexibly with data: $firestoreData');

    // ส่งข้อมูลไป Firestore โดยตรง (ไม่แปลง empty string เป็น FieldValue.delete())
    await _usersCollection.doc(uid).update(firestoreData);
    
    print('User profile updated successfully');
  } catch (e) {
    print('Error updating user profile flexibly: $e');
    throw 'ไม่สามารถอัปเดตข้อมูลได้: $e';
  }
}

  // เพิ่มฟังก์ชันนี้เพื่อดึงข้อมูลผู้ใช้ด้วย uid
  Future<UserModel?> getUserById(String uid) async {
    try {
      DocumentSnapshot doc = await _usersCollection.doc(uid).get();
      if (doc.exists) {
        return UserModel.fromMap(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
      }
      return null;
    } catch (e) {
      print('Error getting user by ID: $e');
      throw 'ไม่สามารถดึงข้อมูลผู้ใช้ได้: $e';
    }
  }

  // Search users by name or license plate number
  Future<List<UserModel>> searchUsers(String searchTerm) async {
    try {
      // Search by license plate number
      QuerySnapshot plateQuery = await _usersCollection
          .where('license_plate_number', isGreaterThanOrEqualTo: searchTerm)
          .where('license_plate_number', isLessThan: '$searchTerm\uf8ff')
          .get();

      // Search by name (if exists)
      QuerySnapshot nameQuery = await _usersCollection
          .where('name', isGreaterThanOrEqualTo: searchTerm)
          .where('name', isLessThan: '$searchTerm\uf8ff')
          .get();

      // Combine results and remove duplicates
      Map<String, UserModel> userMap = {};

      for (var doc in plateQuery.docs) {
        userMap[doc.id] = UserModel.fromMap(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
      }

      for (var doc in nameQuery.docs) {
        userMap[doc.id] = UserModel.fromMap(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
      }

      return userMap.values.toList();
    } catch (e) {
      throw 'ไม่สามารถค้นหาข้อมูลได้: $e';
    }
  }

  // เพิ่มฟังก์ชันเช็คป้ายทะเบียนซ้ำ (แยกจากผู้ใช้ปัจจุบัน)
  Future<bool> isLicensePlateExistsExcludeUser(String licensePlateNumber, String excludeUid) async {
    try {
      QuerySnapshot query = await _usersCollection
          .where('license_plate_number', isEqualTo: licensePlateNumber)
          .get();

      // ตรวจสอบว่ามีเอกสารใดที่ไม่ใช่ของผู้ใช้ปัจจุบัน
      for (DocumentSnapshot doc in query.docs) {
        if (doc.id != excludeUid) {
          return true; // พบป้ายทะเบียนซ้ำจากผู้ใช้คนอื่น
        }
      }
      return false;
    } catch (e) {
      throw 'ไม่สามารถตรวจสอบป้ายทะเบียนได้: $e';
    }
  }

  
}