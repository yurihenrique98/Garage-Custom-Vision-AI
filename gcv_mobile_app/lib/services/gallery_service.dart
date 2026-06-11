import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class GalleryService {
  Future<String> saveBuild({
    required String userId,
    required Uint8List imageBytes,
  }) async {
    final String fileName = 'build_${DateTime.now().millisecondsSinceEpoch}.png';

    final Reference ref = FirebaseStorage.instance
        .ref()
        .child('users/$userId/$fileName');

    await ref.putData(
      imageBytes,
      SettableMetadata(contentType: 'image/png'),
    );

    final String downloadUrl = await ref.getDownloadURL();

    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('builds')
        .add({
      'timestamp': FieldValue.serverTimestamp(),
      'image_url': downloadUrl,
    });

    return downloadUrl;
  }

  Future<List<Map<String, dynamic>>> loadGallery(String userId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('builds')
        .orderBy('timestamp', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      return {
        'id': doc.id,
        'url': doc.data()['image_url'],
      };
    }).toList();
  }

  Future<void> deleteBuild({
    required String userId,
    required String docId,
  }) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('builds')
        .doc(docId)
        .delete();
  }
}