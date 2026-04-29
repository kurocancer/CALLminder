import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_profile.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get currentUserId => _auth.currentUser?.uid ?? '';

  Stream<List<Map<String, dynamic>>> getFriends() {
    return _db
        .collection('users')
        .doc(currentUserId)
        .collection('friends')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              var data = doc.data();
              data['uid'] = doc.id;
              return data;
            }).toList());
  }

  Future<bool> sendFriendRequest(String friendEmail) async {
    try {
      var query = await _db
          .collection('users')
          .where('email', isEqualTo: friendEmail)
          .get();

      if (query.docs.isEmpty) return false;

      String toUserId = query.docs.first.id;

      await _db.collection('friend_requests').add({
        'fromUserId': currentUserId,
        'toUserId': toUserId,
        'fromName': _auth.currentUser?.displayName ?? 'Unknown',
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print("Friend request error: $e");
      return false;
    }
  }

  Stream<List<Map<String, dynamic>>> getPendingRequests() {
    return _db
        .collection('friend_requests')
        .where('toUserId', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              var data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList());
  }

  Future<void> acceptFriendRequest(String requestId, String fromUserId) async {
    await _db.collection('friend_requests').doc(requestId).update({
      'status': 'accepted',
    });

    await _db
        .collection('users')
        .doc(currentUserId)
        .collection('friends')
        .doc(fromUserId)
        .set({'uid': fromUserId});

    await _db
        .collection('users')
        .doc(fromUserId)
        .collection('friends')
        .doc(currentUserId)
        .set({'uid': currentUserId});
  }

  Future<bool> sendNudge(String toUserId, String message) async {
    try {
      await _db.collection('nudges').add({
        'fromUserId': currentUserId,
        'toUserId': toUserId,
        'fromName': _auth.currentUser?.displayName ?? 'Unknown',
        'message': message,
        'status': 'sent',
        'timestamp': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print("Nudge error: $e");
      return false;
    }
  }

  Future<void> blockFriend(String friendId) async {
    await _db
        .collection('users')
        .doc(currentUserId)
        .collection('friends')
        .doc(friendId)
        .update({'isBlocked': true});
  }

  Future<void> setShieldMode(bool enabled) async {
    await _db.collection('users').doc(currentUserId).update({
      'shieldMode': enabled,
    });
  }
}
