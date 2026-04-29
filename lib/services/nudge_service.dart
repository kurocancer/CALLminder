import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NudgeService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<NudgeResult> canSendNudge(String toUserId) async {
    final friendDoc = await _db
        .collection('users')
        .doc(_auth.currentUser!.uid)
        .collection('friends')
        .doc(toUserId)
        .get();

    if (friendDoc.exists) {
      final data = friendDoc.data()!;
      final lastSent = data['lastNudgeSent'] as Timestamp?;

      if (lastSent != null) {
        final diff = DateTime.now().difference(lastSent.toDate());
        if (diff.inMinutes < 30) {
          return NudgeResult(
            allowed: false,
            message: 'Cooldown: ${30 - diff.inMinutes}m left',
          );
        }
      }
    }

    final targetUserDoc =
        await _db.collection('users').doc(toUserId).get();

    if (targetUserDoc.exists) {
      final data = targetUserDoc.data()!;
      if (data['shieldMode'] == true) {
        return NudgeResult(
          allowed: false,
          message: "${data['name']}'s shield is active",
        );
      }
    }

    return NudgeResult(allowed: true);
  }

  Future<bool> sendNudge(String toUserId, String toName, String message) async {
    final result = await canSendNudge(toUserId);
    if (!result.allowed) return false;

    try {
      await _db
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .collection('friends')
          .doc(toUserId)
          .update({
        'lastNudgeSent': FieldValue.serverTimestamp(),
      });

      await _db.collection('nudges').add({
        'fromUserId': _auth.currentUser!.uid,
        'toUserId': toUserId,
        'fromName': _auth.currentUser!.displayName ?? 'Unknown',
        'toName': toName,
        'message': message,
        'status': 'sent',
        'createdAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print("Nudge error: $e");
      return false;
    }
  }
}

class NudgeResult {
  final bool allowed;
  final String? message;
  NudgeResult({required this.allowed, this.message});
}
