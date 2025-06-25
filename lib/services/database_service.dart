import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Collection reference
  CollectionReference get _usersCollection => _db.collection('users');

  // Create user document
  Future<void> createUser(UserModel user) async {
    try {
      await _usersCollection.doc(user.uid).set(user.toMap());
    } catch (e) {
      throw 'ไม่สามารถบันทึกข้อมูลผู้ใช้ได้: $e';
    }
  }

  // Get user by UID
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

  // Update user with automatic updateAt timestamp
  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    try {
      // Add updateAt timestamp
      data['update_at'] = FieldValue.serverTimestamp(); // แก้เป็น update_at
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

  // Check if license plate number already exists (แก้ field name)
  Future<bool> isLicensePlateExists(String licensePlateNumber) async {
    try {
      QuerySnapshot query = await _usersCollection
          .where('license_plate_number', isEqualTo: licensePlateNumber) // แก้เป็น license_plate_number
          .get();
      return query.docs.isNotEmpty;
    } catch (e) {
      throw 'ไม่สามารถตรวจสอบป้ายทะเบียนได้: $e';
    }
  }

  // Get user by license plate number (แก้ field name)
  Future<UserModel?> getUserByLicensePlate(String licensePlateNumber) async {
    try {
      QuerySnapshot query = await _usersCollection
          .where('license_plate_number', isEqualTo: licensePlateNumber) // แก้เป็น license_plate_number
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

  // Get all users (for admin purposes) - แก้ field name
  Future<List<UserModel>> getAllUsers() async {
    try {
      QuerySnapshot query =
          await _usersCollection.orderBy('create_at', descending: true).get(); // แก้เป็น create_at

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

  // Update specific fields with methods - แก้ field name
  Future<void> updateUserName(String uid, String name) async {
    try {
      await _usersCollection.doc(uid).update({
        'name': name,
        'update_at': FieldValue.serverTimestamp(), // แก้เป็น update_at
      });
    } catch (e) {
      throw 'ไม่สามารถอัปเดตชื่อผู้ใช้ได้: $e';
    }
  }

  // Update Facebook profile - แก้ field name
  Future<void> updateUserFacebook(String uid, String facebook) async {
    try {
      await _usersCollection.doc(uid).update({
        'facebook': facebook,
        'update_at': FieldValue.serverTimestamp(), // แก้เป็น update_at
      });
    } catch (e) {
      throw 'ไม่สามารถอัปเดต Facebook ได้: $e';
    }
  }

  // Update additional info - แก้ field name
  Future<void> updateAdditionalInfo(String uid, String additionalInfo) async {
    try {
      await _usersCollection.doc(uid).update({
        'additional_info': additionalInfo, // แก้เป็น additional_info
        'update_at': FieldValue.serverTimestamp(), // แก้เป็น update_at
      });
    } catch (e) {
      throw 'ไม่สามารถอัปเดตข้อมูลเพิ่มเติมได้: $e';
    }
  }

  // ฟังก์ชันหลักสำหรับอัปเดตข้อมูลผู้ใช้ (แก้ field names ให้ตรงกับฐานข้อมูล)
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
        'phone_number': phoneNumber, // แก้เป็น phone_number ตามในฐานข้อมูล
        'update_at': FieldValue.serverTimestamp(), // แก้เป็น update_at
      };

      // เพิ่มข้อมูลที่ไม่เป็น null
      if (licensePlateNumber != null && licensePlateNumber.isNotEmpty) {
        updateData['license_plate_number'] = licensePlateNumber; // แก้เป็น license_plate_number
      }

      if (facebook != null && facebook.isNotEmpty) {
        updateData['facebook'] = facebook;
      }

      if (additionalInfo != null && additionalInfo.isNotEmpty) {
        updateData['additional_info'] = additionalInfo; // แก้เป็น additional_info
      }

      print('Updating user profile with data: $updateData'); // Debug log

      await _usersCollection.doc(uid).update(updateData);
      
      print('Profile updated successfully in Firestore'); // Debug log
    } catch (e) {
      print('Error updating user profile: $e'); // Debug log
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
      print('Error getting user by ID: $e'); // Debug log
      throw 'ไม่สามารถดึงข้อมูลผู้ใช้ได้: $e';
    }
  }

  // Search users by name or license plate number - แก้ field names
  Future<List<UserModel>> searchUsers(String searchTerm) async {
    try {
      // Search by license plate number
      QuerySnapshot plateQuery = await _usersCollection
          .where('license_plate_number', isGreaterThanOrEqualTo: searchTerm) // แก้เป็น license_plate_number
          .where('license_plate_number', isLessThan: searchTerm + '\uf8ff')
          .get();

      // Search by name (if exists)
      QuerySnapshot nameQuery = await _usersCollection
          .where('name', isGreaterThanOrEqualTo: searchTerm)
          .where('name', isLessThan: searchTerm + '\uf8ff')
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