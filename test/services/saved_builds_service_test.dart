import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pc_buildere/models/component.dart';
import 'package:pc_buildere/services/saved_builds_service.dart';

SavedBuild _build(String id, {required String userId, bool isPublic = false}) =>
    SavedBuild(
      id: id,
      name: 'Build $id',
      components: {
        ComponentType.cpu: const Component(
          id: 'B000000001',
          name: 'AMD Ryzen 5 5600X',
          brand: 'AMD',
          type: ComponentType.cpu,
          price: 150,
        ),
      },
      totalPrice: 150,
      createdAt: DateTime(2026, 10, 22),
      userId: userId,
      isPublic: isPublic,
      authorName: userId,
    );

void main() {
  late FakeFirebaseFirestore firestore;

  SavedBuildsService serviceFor(String uid) => SavedBuildsService(
    firestore: firestore,
    auth: MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: uid, displayName: uid),
    ),
  );

  Future<bool> exists(String path) async =>
      (await firestore.doc(path).get()).exists;

  setUp(() => firestore = FakeFirebaseFirestore());

  group('save and load', () {
    test('a private build is saved only to the owner\'s collection', () async {
      await serviceFor('alice').addBuild(_build('b1', userId: 'alice'));

      expect(await exists('users/alice/builds/b1'), isTrue);
      expect(await exists('public_builds/b1'), isFalse);
    });

    test('a public build is also published to the community feed', () async {
      await serviceFor(
        'alice',
      ).addBuild(_build('b1', userId: 'alice', isPublic: true));

      expect(await exists('users/alice/builds/b1'), isTrue);
      expect(await exists('public_builds/b1'), isTrue);
    });

    test('saved builds round-trip with their components', () async {
      final alice = serviceFor('alice');
      await alice.addBuild(_build('b1', userId: 'alice'));

      final builds = await alice.loadBuildsStream().first;
      expect(builds, hasLength(1));
      expect(builds.single.name, 'Build b1');
      expect(
        builds.single.components[ComponentType.cpu]?.name,
        'AMD Ryzen 5 5600X',
      );
    });

    test('users only see their own saved builds', () async {
      await serviceFor('alice').addBuild(_build('b1', userId: 'alice'));

      expect(await serviceFor('bob').loadBuildsStream().first, isEmpty);
    });

    test('signed-out users cannot save', () async {
      final service = SavedBuildsService(
        firestore: firestore,
        auth: MockFirebaseAuth(),
      );
      expect(
        () => service.addBuild(_build('b1', userId: 'alice')),
        throwsException,
      );
    });
  });

  group('delete', () {
    test('deleting a private build removes it', () async {
      final alice = serviceFor('alice');
      await alice.addBuild(_build('b1', userId: 'alice'));
      await alice.deleteBuild('b1');

      expect(await exists('users/alice/builds/b1'), isFalse);
    });

    test(
      'deleting a public build removes the feed copy and its comments',
      () async {
        final alice = serviceFor('alice');
        await alice.addBuild(_build('b1', userId: 'alice', isPublic: true));
        await serviceFor('bob').addComment('b1', 'Nice!');
        await serviceFor('carol').addComment('b1', 'Great GPU choice');

        await alice.deleteBuild('b1', isPublic: true);

        expect(await exists('users/alice/builds/b1'), isFalse);
        expect(await exists('public_builds/b1'), isFalse);
        final comments = await firestore
            .collection('public_builds/b1/comments')
            .get();
        expect(comments.docs, isEmpty);
      },
    );

    test('deletes more comments than fit in one batch', () async {
      final alice = serviceFor('alice');
      await alice.addBuild(_build('b1', userId: 'alice', isPublic: true));
      for (var i = 0; i < 520; i++) {
        await firestore.doc('public_builds/b1/comments/c$i').set({'i': i});
      }

      await alice.deleteBuild('b1', isPublic: true);

      final comments = await firestore
          .collection('public_builds/b1/comments')
          .get();
      expect(comments.docs, isEmpty);
      expect(await exists('public_builds/b1'), isFalse);
    });
  });

  group('likes', () {
    setUp(
      () => serviceFor(
        'alice',
      ).addBuild(_build('b1', userId: 'alice', isPublic: true)),
    );

    Future<Map<String, dynamic>> publicBuild() async =>
        (await firestore.doc('public_builds/b1').get()).data()!;

    test('like then unlike keeps likesCount equal to likedBy', () async {
      final bob = serviceFor('bob');

      expect(await bob.toggleLike('b1'), isTrue);
      var data = await publicBuild();
      expect(data['likedBy'], ['bob']);
      expect(data['likesCount'], 1);

      expect(await bob.toggleLike('b1'), isFalse);
      data = await publicBuild();
      expect(data['likedBy'], isEmpty);
      expect(data['likesCount'], 0);
    });

    // Real contention plus rules is covered by the emulator rules tests.
    test('concurrent likes from different users accumulate', () async {
      await Future.wait([
        serviceFor('bob').toggleLike('b1'),
        serviceFor('carol').toggleLike('b1'),
      ]);

      final data = await publicBuild();
      expect(data['likedBy'], unorderedEquals(['bob', 'carol']));
      expect(data['likesCount'], 2);
    });

    test('hasUserLiked reflects the current user', () async {
      await serviceFor('bob').toggleLike('b1');
      final build = (await serviceFor(
        'bob',
      ).loadPublicBuildsStream().first).single;

      expect(serviceFor('bob').hasUserLiked(build), isTrue);
      expect(serviceFor('carol').hasUserLiked(build), isFalse);
    });

    test('liking a missing build fails', () async {
      expect(() => serviceFor('bob').toggleLike('missing'), throwsException);
    });
  });

  group('comments', () {
    test('comments are stored as the signed-in user, oldest first', () async {
      await serviceFor(
        'alice',
      ).addBuild(_build('b1', userId: 'alice', isPublic: true));
      await serviceFor('bob').addComment('b1', 'First');
      await serviceFor('carol').addComment('b1', 'Second');

      final comments = await serviceFor('bob').getCommentsStream('b1').first;
      expect(comments.map((c) => c.text), ['First', 'Second']);
      expect(comments.map((c) => c.userId), ['bob', 'carol']);
      expect(comments.first.buildId, 'b1');
    });

    test('a comment can be deleted', () async {
      await serviceFor(
        'alice',
      ).addBuild(_build('b1', userId: 'alice', isPublic: true));
      final bob = serviceFor('bob');
      await bob.addComment('b1', 'Oops');
      final comment = (await bob.getCommentsStream('b1').first).single;

      await bob.deleteComment('b1', comment.id);

      expect(await bob.getCommentsStream('b1').first, isEmpty);
    });
  });

  group('component keys', () {
    Map<String, dynamic> legacyBuild({bool isPublic = false}) => {
      'id': 'old',
      'name': 'Old build',
      'components': {
        '0': {
          'id': 'c1',
          'name': 'AMD Ryzen 5 7600X',
          'brand': 'AMD',
          'type': 0,
          'price': 200.0,
          'specs': <String, dynamic>{},
        },
        '1': {
          'id': 'g1',
          'name': 'RTX 4070',
          'brand': 'NVIDIA',
          'type': 1,
          'price': 500.0,
          'specs': <String, dynamic>{},
        },
      },
      'totalPrice': 700.0,
      'createdAt': Timestamp.now(),
      'userId': 'alice',
      'isPublic': isPublic,
      'authorName': 'Alice',
      'likesCount': 0,
      'likedBy': <String>[],
    };

    late FakeFirebaseFirestore firestore;
    late SavedBuildsService service;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      service = SavedBuildsService(
        firestore: firestore,
        auth: MockFirebaseAuth(
          signedIn: true,
          mockUser: MockUser(uid: 'alice'),
        ),
      );
    });

    DocumentReference<Map<String, dynamic>> privateDoc(String id) =>
        firestore.collection('users').doc('alice').collection('builds').doc(id);

    test('new builds are written with stable names', () async {
      await privateDoc('old').set(legacyBuild());
      final build = SavedBuild.fromFirestore(await privateDoc('old').get());

      final json = build.toJson()['components'] as Map<String, dynamic>;
      expect(json.keys, containsAll(['cpu', 'gpu']));
      expect(json['cpu']['type'], 'cpu');
    });

    test('old enum-index builds still load', () async {
      await privateDoc('old').set(legacyBuild());
      final build = SavedBuild.fromFirestore(await privateDoc('old').get());

      expect(build.components[ComponentType.cpu]?.name, 'AMD Ryzen 5 7600X');
      expect(build.components[ComponentType.gpu]?.type, ComponentType.gpu);
    });

    test('unknown keys are skipped rather than crashing', () async {
      await privateDoc('old').set({
        ...legacyBuild(),
        'components': {'99': legacyBuild()['components']['0']},
      });
      final build = SavedBuild.fromFirestore(await privateDoc('old').get());
      expect(build.components, isEmpty);
    });

    test('migration rewrites private and public copies', () async {
      await privateDoc('old').set(legacyBuild(isPublic: true));
      await firestore
          .collection('public_builds')
          .doc('old')
          .set(legacyBuild(isPublic: true));

      await service.migrateLegacyComponentKeys();

      for (final doc in [
        await privateDoc('old').get(),
        await firestore.collection('public_builds').doc('old').get(),
      ]) {
        final components = doc.data()!['components'] as Map<String, dynamic>;
        expect(components.keys, unorderedEquals(['cpu', 'gpu']));
      }
    });

    test(
      'migration leaves new builds alone and survives a missing public copy',
      () async {
        await privateDoc('old').set(legacyBuild(isPublic: true));
        await privateDoc('new').set({
          ...legacyBuild(),
          'id': 'new',
          'name': 'Untouched',
          'components': {'cpu': legacyBuild()['components']['0']},
        });

        await service.migrateLegacyComponentKeys();

        final kept = (await privateDoc('new').get()).data()!;
        expect((kept['components'] as Map).keys, ['cpu']);
        final migrated = (await privateDoc('old').get()).data()!;
        expect(
          (migrated['components'] as Map).keys,
          unorderedEquals(['cpu', 'gpu']),
        );
      },
    );

    test('signed-out migration does nothing', () async {
      final signedOut = SavedBuildsService(
        firestore: firestore,
        auth: MockFirebaseAuth(signedIn: false),
      );
      await signedOut.migrateLegacyComponentKeys();
    });
  });
}
