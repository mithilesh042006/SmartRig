// Firestore security rules tests. Run with `npm test` (starts the emulator).
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  arrayRemove,
  arrayUnion,
  deleteDoc,
  deleteField,
  doc,
  getDoc,
  increment,
  setDoc,
  Timestamp,
  updateDoc,
  writeBatch,
} from 'firebase/firestore';

let env;

const db = (uid) =>
  uid
    ? env.authenticatedContext(uid).firestore()
    : env.unauthenticatedContext().firestore();

const build = (userId, extra = {}) => ({
  id: 'b1',
  name: 'Gaming Beast',
  components: {},
  totalPrice: 1000,
  createdAt: Timestamp.now(),
  userId,
  isPublic: true,
  authorName: 'Alice',
  likesCount: 0,
  likedBy: [],
  ...extra,
});

const comment = (userId, extra = {}) => ({
  id: 'c1',
  buildId: 'b1',
  userId,
  userName: 'Bob',
  text: 'Nice build!',
  createdAt: Timestamp.now(),
  ...extra,
});

// Seed documents without rules
const seed = (path, data) =>
  env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), path), data));

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-smartrig',
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8') },
  });
});

after(() => env.cleanup());
beforeEach(() => env.clearFirestore());

describe('private builds', () => {
  test('owner can create, read and delete', async () => {
    const ref = doc(db('alice'), 'users/alice/builds/b1');
    await assertSucceeds(setDoc(ref, build('alice', { isPublic: false })));
    await assertSucceeds(getDoc(ref));
    await assertSucceeds(deleteDoc(ref));
  });

  test('other users and guests cannot read', async () => {
    await seed('users/alice/builds/b1', build('alice'));
    await assertFails(getDoc(doc(db('bob'), 'users/alice/builds/b1')));
    await assertFails(getDoc(doc(db(null), 'users/alice/builds/b1')));
  });

  test('cannot write into another user\'s collection', async () => {
    await assertFails(setDoc(doc(db('bob'), 'users/alice/builds/b1'), build('alice')));
  });

  test('userId must match the owner', async () => {
    await assertFails(setDoc(doc(db('alice'), 'users/alice/builds/b1'), build('bob')));
  });
});

describe('public builds', () => {
  test('signed-in users can read; guests cannot', async () => {
    await seed('public_builds/b1', build('alice'));
    await assertSucceeds(getDoc(doc(db('bob'), 'public_builds/b1')));
    await assertFails(getDoc(doc(db(null), 'public_builds/b1')));
  });

  test('owner can create with zero likes', async () => {
    await assertSucceeds(setDoc(doc(db('alice'), 'public_builds/b1'), build('alice')));
  });

  test('cannot create as someone else', async () => {
    await assertFails(setDoc(doc(db('bob'), 'public_builds/b1'), build('alice')));
  });

  test('cannot create with pre-filled likes', async () => {
    await assertFails(
      setDoc(doc(db('alice'), 'public_builds/b1'), build('alice', { likesCount: 99, likedBy: [] })),
    );
    await assertFails(
      setDoc(doc(db('alice'), 'public_builds/b1'), build('alice', { likesCount: 1, likedBy: ['x'] })),
    );
  });

  test('owner can rename but not change likes or owner', async () => {
    await seed('public_builds/b1', build('alice'));
    const ref = doc(db('alice'), 'public_builds/b1');
    await assertSucceeds(updateDoc(ref, { name: 'Renamed' }));
    await assertFails(updateDoc(ref, { likesCount: 50 }));
    await assertFails(updateDoc(ref, { userId: 'bob' }));
  });

  test('non-owner cannot edit other fields', async () => {
    await seed('public_builds/b1', build('alice'));
    await assertFails(updateDoc(doc(db('bob'), 'public_builds/b1'), { name: 'Hacked' }));
  });

  test('owner can delete; others cannot', async () => {
    await seed('public_builds/b1', build('alice'));
    await assertFails(deleteDoc(doc(db('bob'), 'public_builds/b1')));
    await assertSucceeds(deleteDoc(doc(db('alice'), 'public_builds/b1')));
  });
});

describe('component key migration', () => {
  const part = { id: 'c1', name: 'Ryzen', type: 0 };
  const legacy = { components: { 0: part, 1: { ...part, id: 'g1', type: 1 } } };
  // Same writes as SavedBuildsService.migrateLegacyComponentKeys.
  const update = {
    'components.0': deleteField(),
    'components.1': deleteField(),
    'components.cpu': { ...part, type: 'cpu' },
    'components.gpu': { ...part, id: 'g1', type: 'gpu' },
  };

  test('owner migrates both copies, old keys are removed, likes survive', async () => {
    const liked = { likedBy: ['carol'], likesCount: 1 };
    await seed('users/alice/builds/b1', build('alice', { ...legacy }));
    await seed('public_builds/b1', build('alice', { ...legacy, ...liked }));

    const alice = db('alice');
    const batch = writeBatch(alice);
    batch.update(doc(alice, 'users/alice/builds/b1'), update);
    batch.update(doc(alice, 'public_builds/b1'), update);
    await assertSucceeds(batch.commit());

    const after = (await getDoc(doc(alice, 'public_builds/b1'))).data();
    assert.deepEqual(Object.keys(after.components).sort(), ['cpu', 'gpu']);
    assert.equal(after.components.cpu.type, 'cpu');
    assert.equal(after.likesCount, 1);
    assert.deepEqual(after.likedBy, ['carol']);
  });

  test('others cannot migrate a build they do not own', async () => {
    await seed('public_builds/b1', build('alice', { ...legacy }));
    await assertFails(updateDoc(doc(db('bob'), 'public_builds/b1'), update));
  });
});

describe('likes', () => {
  test('user can like and unlike with their own UID', async () => {
    await seed('public_builds/b1', build('alice', { likedBy: ['carol'], likesCount: 1 }));
    const ref = doc(db('bob'), 'public_builds/b1');
    await assertSucceeds(updateDoc(ref, { likedBy: ['carol', 'bob'], likesCount: 2 }));
    await assertSucceeds(updateDoc(ref, { likedBy: ['carol'], likesCount: 1 }));
  });

  test('owner can like their own build', async () => {
    await seed('public_builds/b1', build('alice'));
    await assertSucceeds(
      updateDoc(doc(db('alice'), 'public_builds/b1'), { likedBy: ['alice'], likesCount: 1 }),
    );
  });

  test('cannot add someone else\'s UID', async () => {
    await seed('public_builds/b1', build('alice'));
    await assertFails(
      updateDoc(doc(db('bob'), 'public_builds/b1'), { likedBy: ['mallory'], likesCount: 1 }),
    );
  });

  test('cannot remove someone else\'s like', async () => {
    await seed('public_builds/b1', build('alice', { likedBy: ['carol'], likesCount: 1 }));
    await assertFails(updateDoc(doc(db('bob'), 'public_builds/b1'), { likedBy: [], likesCount: 0 }));
  });

  test('count must equal likedBy size', async () => {
    await seed('public_builds/b1', build('alice'));
    await assertFails(
      updateDoc(doc(db('bob'), 'public_builds/b1'), { likedBy: ['bob'], likesCount: 10 }),
    );
  });

  test('cannot like twice', async () => {
    await seed('public_builds/b1', build('alice', { likedBy: ['bob'], likesCount: 1 }));
    await assertFails(
      updateDoc(doc(db('bob'), 'public_builds/b1'), { likedBy: ['bob', 'bob'], likesCount: 2 }),
    );
  });

  test('cannot sneak other fields into a like', async () => {
    await seed('public_builds/b1', build('alice'));
    await assertFails(
      updateDoc(doc(db('bob'), 'public_builds/b1'), {
        likedBy: ['bob'],
        likesCount: 1,
        name: 'Hacked',
      }),
    );
  });

  test('concurrent likes do not overwrite each other', async () => {
    await seed('public_builds/b1', build('alice'));

    // Same reads and writes as SavedBuildsService.toggleLike.
    const toggleLike = async (uid) => {
      const ref = doc(db(uid), 'public_builds/b1');
      const liked = (await getDoc(ref)).data().likedBy.includes(uid);
      await updateDoc(ref, {
        likedBy: liked ? arrayRemove(uid) : arrayUnion(uid),
        likesCount: increment(liked ? -1 : 1),
      });
    };

    const users = ['bob', 'carol', 'dave', 'erin', 'frank', 'grace', 'heidi', 'ivan'];
    await Promise.all(users.map(toggleLike));

    let data;
    await env.withSecurityRulesDisabled(async (ctx) => {
      data = (await getDoc(doc(ctx.firestore(), 'public_builds/b1'))).data();
    });
    assert.deepEqual([...data.likedBy].sort(), users);
    assert.equal(data.likesCount, users.length);
  });

  test('a stale double-like is rejected instead of corrupting the count', async () => {
    await seed('public_builds/b1', build('alice', { likedBy: ['bob'], likesCount: 1 }));
    await assertFails(
      updateDoc(doc(db('bob'), 'public_builds/b1'), {
        likedBy: arrayUnion('bob'),
        likesCount: increment(1),
      }),
    );
  });

  test('guests cannot like', async () => {
    await seed('public_builds/b1', build('alice'));
    await assertFails(updateDoc(doc(db(null), 'public_builds/b1'), { likedBy: ['x'], likesCount: 1 }));
  });
});

describe('comments', () => {
  const path = 'public_builds/b1/comments/c1';

  test('signed-in user can comment as themselves', async () => {
    await seed('public_builds/b1', build('alice'));
    await assertSucceeds(setDoc(doc(db('bob'), path), comment('bob')));
  });

  test('cannot comment as someone else', async () => {
    await seed('public_builds/b1', build('alice'));
    await assertFails(setDoc(doc(db('bob'), path), comment('carol')));
  });

  test('cannot comment on a build that does not exist', async () => {
    await assertFails(setDoc(doc(db('bob'), path), comment('bob')));
  });

  test('text must be 1–1000 characters', async () => {
    await seed('public_builds/b1', build('alice'));
    await assertFails(setDoc(doc(db('bob'), path), comment('bob', { text: '' })));
    await assertFails(setDoc(doc(db('bob'), path), comment('bob', { text: 'x'.repeat(1001) })));
    await assertSucceeds(setDoc(doc(db('bob'), path), comment('bob', { text: 'x'.repeat(1000) })));
  });

  test('only the author can delete; nobody can edit', async () => {
    await seed('public_builds/b1', build('alice'));
    await seed(path, comment('bob'));
    await assertFails(updateDoc(doc(db('bob'), path), { text: 'edited' }));
    await assertFails(deleteDoc(doc(db('carol'), path)));
    await assertSucceeds(deleteDoc(doc(db('bob'), path)));
  });

  test('build owner can delete any comment on their build', async () => {
    await seed('public_builds/b1', build('alice'));
    await seed(path, comment('bob'));
    await assertSucceeds(deleteDoc(doc(db('alice'), path)));
  });

  test('owner deletes build, its comments and private copy in one batch', async () => {
    await seed('users/alice/builds/b1', build('alice'));
    await seed('public_builds/b1', build('alice'));
    await seed(path, comment('bob'));
    await seed('public_builds/b1/comments/c2', comment('carol', { id: 'c2' }));

    const alice = db('alice');
    const batch = writeBatch(alice);
    batch.delete(doc(alice, path));
    batch.delete(doc(alice, 'public_builds/b1/comments/c2'));
    batch.delete(doc(alice, 'public_builds/b1'));
    batch.delete(doc(alice, 'users/alice/builds/b1'));
    await assertSucceeds(batch.commit());
  });

  test('others cannot clear comments on a build they do not own', async () => {
    await seed('public_builds/b1', build('alice'));
    await seed(path, comment('bob'));
    const carol = db('carol');
    const batch = writeBatch(carol);
    batch.delete(doc(carol, path));
    await assertFails(batch.commit());
  });
});

describe('everything else', () => {
  test('api_cache is server-only', async () => {
    await seed('api_cache/k', { value: 1 });
    await assertFails(getDoc(doc(db('alice'), 'api_cache/k')));
    await assertFails(setDoc(doc(db('alice'), 'api_cache/k'), { value: 2 }));
  });

  test('rate_limits is server-only', async () => {
    await seed('rate_limits/alice', { start: 0, count: 120 });
    await assertFails(getDoc(doc(db('alice'), 'rate_limits/alice')));
    await assertFails(setDoc(doc(db('alice'), 'rate_limits/alice'), { start: 0, count: 0 }));
  });

  test('unknown collections are denied', async () => {
    await assertFails(setDoc(doc(db('alice'), 'random/x'), { a: 1 }));
  });
});
