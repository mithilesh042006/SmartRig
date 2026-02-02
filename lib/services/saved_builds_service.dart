import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/component.dart';

/// Model for a comment on a build
class BuildComment {
  final String id;
  final String buildId;
  final String userId;
  final String userName;
  final String text;
  final DateTime createdAt;

  const BuildComment({
    required this.id,
    required this.buildId,
    required this.userId,
    required this.userName,
    required this.text,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'buildId': buildId,
      'userId': userId,
      'userName': userName,
      'text': text,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory BuildComment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final createdAtTimestamp = data['createdAt'] as Timestamp?;
    return BuildComment(
      id: doc.id,
      buildId: data['buildId'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Anonymous',
      text: data['text'] ?? '',
      createdAt: createdAtTimestamp?.toDate() ?? DateTime.now(),
    );
  }
}

/// Model for a saved PC build
class SavedBuild {
  final String id;
  final String name;
  final Map<ComponentType, Component> components;
  final double totalPrice;
  final DateTime createdAt;
  final String userId;
  final bool isPublic;
  final String authorName;
  final int likesCount;
  final List<String> likedBy; // List of user IDs who liked

  const SavedBuild({
    required this.id,
    required this.name,
    required this.components,
    required this.totalPrice,
    required this.createdAt,
    required this.userId,
    this.isPublic = false,
    this.authorName = 'Anonymous',
    this.likesCount = 0,
    this.likedBy = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'components': components.map(
        (key, value) => MapEntry(key.index.toString(), _componentToJson(value)),
      ),
      'totalPrice': totalPrice,
      'createdAt': Timestamp.fromDate(createdAt),
      'userId': userId,
      'isPublic': isPublic,
      'authorName': authorName,
      'likesCount': likesCount,
      'likedBy': likedBy,
    };
  }

  factory SavedBuild.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final componentsMap = <ComponentType, Component>{};
    final componentsJson = data['components'] as Map<String, dynamic>? ?? {};

    componentsJson.forEach((key, value) {
      final typeIndex = int.tryParse(key);
      if (typeIndex != null && typeIndex < ComponentType.values.length) {
        componentsMap[ComponentType.values[typeIndex]] = _componentFromJson(
          value,
        );
      }
    });

    final createdAtTimestamp = data['createdAt'] as Timestamp?;
    final createdAt = createdAtTimestamp?.toDate() ?? DateTime.now();
    final likedByList = (data['likedBy'] as List?)?.cast<String>() ?? [];

    return SavedBuild(
      id: doc.id,
      name: data['name'] ?? 'Unnamed Build',
      components: componentsMap,
      totalPrice: (data['totalPrice'] as num?)?.toDouble() ?? 0.0,
      createdAt: createdAt,
      userId: data['userId'] ?? '',
      isPublic: data['isPublic'] ?? false,
      authorName: data['authorName'] ?? 'Anonymous',
      likesCount: (data['likesCount'] as num?)?.toInt() ?? 0,
      likedBy: likedByList,
    );
  }

  static Map<String, dynamic> _componentToJson(Component c) {
    return {
      'id': c.id,
      'name': c.name,
      'brand': c.brand,
      'type': c.type.index,
      'price': c.price,
      'imageUrl': c.imageUrl,
      'specs': c.specs,
    };
  }

  static Component _componentFromJson(Map<String, dynamic> json) {
    return Component(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      brand: json['brand'] ?? '',
      type: ComponentType.values[json['type'] ?? 0],
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      imageUrl: json['imageUrl'],
      specs: Map<String, dynamic>.from(json['specs'] ?? {}),
    );
  }
}

/// Service for persisting saved builds to Firestore
class SavedBuildsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get the current user's builds collection reference
  CollectionReference? _getUserBuildsCollection() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return null;
    return _firestore.collection('users').doc(userId).collection('builds');
  }

  /// Get the public builds collection reference
  CollectionReference get _publicBuildsCollection =>
      _firestore.collection('public_builds');

  /// Load all builds for the current user
  Stream<List<SavedBuild>> loadBuildsStream() {
    final collection = _getUserBuildsCollection();
    if (collection == null) {
      return Stream.value([]);
    }

    return collection.orderBy('createdAt', descending: true).snapshots().map((
      snapshot,
    ) {
      return snapshot.docs.map((doc) => SavedBuild.fromFirestore(doc)).toList();
    });
  }

  /// Load all public builds from community
  Stream<List<SavedBuild>> loadPublicBuildsStream() {
    return _publicBuildsCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => SavedBuild.fromFirestore(doc))
              .toList();
        });
  }

  /// Add a new build to Firestore
  Future<void> addBuild(SavedBuild build) async {
    final collection = _getUserBuildsCollection();
    if (collection == null) {
      throw Exception('User not authenticated');
    }

    // Save to user's private collection
    await collection.doc(build.id).set(build.toJson());

    // If public, also save to public collection
    if (build.isPublic) {
      await _publicBuildsCollection.doc(build.id).set(build.toJson());
    }
  }

  /// Delete a build from Firestore
  Future<void> deleteBuild(String id, {bool isPublic = false}) async {
    final collection = _getUserBuildsCollection();
    if (collection == null) {
      throw Exception('User not authenticated');
    }

    // Delete from user's private collection
    await collection.doc(id).delete();

    // If it was public, also delete from public collection
    if (isPublic) {
      await _publicBuildsCollection.doc(id).delete();
    }
  }

  /// Toggle like on a public build
  Future<bool> toggleLike(String buildId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    final docRef = _publicBuildsCollection.doc(buildId);
    final doc = await docRef.get();

    if (!doc.exists) throw Exception('Build not found');

    final data = doc.data() as Map<String, dynamic>;
    final likedBy = List<String>.from(data['likedBy'] ?? []);
    final isLiked = likedBy.contains(userId);

    if (isLiked) {
      // Unlike
      likedBy.remove(userId);
    } else {
      // Like
      likedBy.add(userId);
    }

    await docRef.update({'likedBy': likedBy, 'likesCount': likedBy.length});

    return !isLiked; // Return new like state
  }

  /// Check if current user has liked a build
  bool hasUserLiked(SavedBuild build) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return false;
    return build.likedBy.contains(userId);
  }

  /// Add a comment to a build
  Future<void> addComment(String buildId, String text) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    final commentsRef = _publicBuildsCollection
        .doc(buildId)
        .collection('comments');
    final commentId = commentsRef.doc().id;

    final comment = BuildComment(
      id: commentId,
      buildId: buildId,
      userId: userId,
      userName: currentUserName,
      text: text,
      createdAt: DateTime.now(),
    );

    await commentsRef.doc(commentId).set(comment.toJson());
  }

  /// Get comments stream for a build
  Stream<List<BuildComment>> getCommentsStream(String buildId) {
    return _publicBuildsCollection
        .doc(buildId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => BuildComment.fromFirestore(doc))
              .toList();
        });
  }

  /// Delete a comment (only by author)
  Future<void> deleteComment(String buildId, String commentId) async {
    await _publicBuildsCollection
        .doc(buildId)
        .collection('comments')
        .doc(commentId)
        .delete();
  }

  /// Generate unique ID for a new build
  String generateId() {
    final collection = _getUserBuildsCollection();
    if (collection == null) {
      return DateTime.now().millisecondsSinceEpoch.toString();
    }
    return collection.doc().id;
  }

  /// Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  /// Get current user display name
  String get currentUserName => _auth.currentUser?.displayName ?? 'Anonymous';
}

/// Provider for SavedBuildsService
final savedBuildsServiceProvider = Provider((ref) => SavedBuildsService());

/// Stream provider for saved builds (auto-updates)
final savedBuildsStreamProvider = StreamProvider<List<SavedBuild>>((ref) {
  final service = ref.watch(savedBuildsServiceProvider);
  return service.loadBuildsStream();
});

/// Stream provider for public/community builds
final publicBuildsStreamProvider = StreamProvider<List<SavedBuild>>((ref) {
  final service = ref.watch(savedBuildsServiceProvider);
  return service.loadPublicBuildsStream();
});

/// Stream provider for comments on a specific build
final buildCommentsProvider = StreamProvider.family<List<BuildComment>, String>(
  (ref, buildId) {
    final service = ref.watch(savedBuildsServiceProvider);
    return service.getCommentsStream(buildId);
  },
);
