import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get ownerId => _auth.currentUser!.uid;

  // Stream owner profile
  Stream<DocumentSnapshot<Map<String, dynamic>>> ownerStream() {
    return _db.collection('owners').doc(ownerId).snapshots();
  }
}
