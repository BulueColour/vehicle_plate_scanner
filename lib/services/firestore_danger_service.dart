import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreDangerService {
  static final CollectionReference _dangerRef = 
    FirebaseFirestore.instance.collection('dangerous_plates');

    static Future<Map<String, dynamic>?> checkDangerousPlate(String plateText) async {
      try {
        print('Input plateText: "$plateText"');

        final normalized = plateText.replaceAll(' ', '').toUpperCase();
        print('Normalized: "$normalized"');

        final snapshot = await _dangerRef
          .where('plate', isEqualTo: normalized)
          .limit(1)
          .get();

          print('Found ${snapshot.docs.length} documents');


        if (snapshot.docs.isEmpty) {
          print('No matching plate found');
          return null;
        }

        final data = snapshot.docs.first.data() as Map<String, dynamic>;
        print('Found data: $data');
        return data;
        
      } catch (e) {
        print('FirestoreDangerService error: $e');
        return null;
      }
    }
}