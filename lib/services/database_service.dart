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
      data['updateAt'] = FieldValue.serverTimestamp();
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
          .where('licensePlateNumber', isEqualTo: licensePlateNumber)
          .get(); // ลบ .limit(1) ออก
      return query.docs.isNotEmpty;
    } catch (e) {
      throw 'ไม่สามารถตรวจสอบป้ายทะเบียนได้: $e';
    }
  }

  // Get user by license plate number
  Future<UserModel?> getUserByLicensePlate(String licensePlateNumber) async {
    try {
      QuerySnapshot query = await _usersCollection
          .where('licensePlateNumber', isEqualTo: licensePlateNumber)
          .get(); // ลบ .limit(1) และ order by ออก
      
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
      QuerySnapshot query = await _usersCollection
          .orderBy('createAt', descending: true)
          .get();
      
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
        'updateAt': FieldValue.serverTimestamp(),
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
        'updateAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw 'ไม่สามารถอัปเดต Facebook ได้: $e';
    }
  }

  // Update additional info
  Future<void> updateAdditionalInfo(String uid, String additionalInfo) async {
    try {
      await _usersCollection.doc(uid).update({
        'additionalInfo': additionalInfo,
        'updateAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw 'ไม่สามารถอัปเดตข้อมูลเพิ่มเติมได้: $e';
    }
  }

  // Search users by name or license plate number
  Future<List<UserModel>> searchUsers(String searchTerm) async {
    try {
      // Search by license plate number
      QuerySnapshot plateQuery = await _usersCollection
          .where('licensePlateNumber', isGreaterThanOrEqualTo: searchTerm)
          .where('licensePlateNumber', isLessThan: searchTerm + '\uf8ff')
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
}