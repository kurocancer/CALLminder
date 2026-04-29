import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  String uid;
  String name;
  String email;
  String? photoUrl;
  String? fcmToken;
  List<String> friends;
  List<String> friendRequests;
  List<String> sentRequests;
  bool shieldMode;
  DateTime? shieldUntil;
  DateTime createdAt;

  UserProfile({
    required this.uid,
    required this.name,
    required this.email,
    this.photoUrl,
    this.fcmToken,
    this.friends = const [],
    this.friendRequests = const [],
    this.sentRequests = const [],
    this.shieldMode = false,
    this.shieldUntil,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        "uid": uid,
        "name": name,
        "email": email,
        "photoUrl": photoUrl,
        "fcmToken": fcmToken,
        "friends": friends,
        "friendRequests": friendRequests,
        "sentRequests": sentRequests,
        "shieldMode": shieldMode,
        "shieldUntil": shieldUntil != null
            ? Timestamp.fromDate(shieldUntil!)
            : null,
        "createdAt": Timestamp.fromDate(createdAt),
      };

  factory UserProfile.fromJson(Map<String, dynamic> json, String uid) {
    return UserProfile(
      uid: uid,
      name: json['name'] ?? 'Unknown',
      email: json['email'] ?? '',
      photoUrl: json['photoUrl'],
      fcmToken: json['fcmToken'],
      friends: List<String>.from(json['friends'] ?? []),
      friendRequests: List<String>.from(json['friendRequests'] ?? []),
      sentRequests: List<String>.from(json['sentRequests'] ?? []),
      shieldMode: json['shieldMode'] ?? false,
      shieldUntil: json['shieldUntil'] != null
          ? (json['shieldUntil'] as Timestamp).toDate()
          : null,
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}
