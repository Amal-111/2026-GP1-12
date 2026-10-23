import {getAuth} from 'firebase-admin/auth';
import {onCall, HttpsError} from 'firebase-functions/v2/https';
import {actor, db, object, stringField} from './common';

const options = {region: 'us-central1', maxInstances: 10};

// Delete owned farm graph before deleting the Auth identity.
// RTDB and Auth are separate systems: production still needs retryable cleanup.
export const deleteAccount = onCall(options, async request => {
  const user = await actor(request);

  // Require a recent sign-in before deleting the account.
  const authTime = request.auth?.token.auth_time;

  if (
    typeof authTime !== 'number' ||
    Date.now() / 1000 - authTime > 300
  ) {
    throw new HttpsError(
      'failed-precondition',
      'Recent sign-in required.'
    );
  }

  const database = db();

  // Read the data required for account cleanup.
  const [
    farmsSnapshot,
    devicesSnapshot,
    usersSnapshot,
    invitationsSnapshot,
  ] = await Promise.all([
    database.ref('farms').get(),
    database.ref('monitoringDevices').get(),
    database.ref('users').get(),
    database.ref('farmInvitations').get(),
  ]);

  const updates: Record<string, unknown> = {};

  const ownedFarmIds: string[] = [];

  // Find farms owned by this account.
  farmsSnapshot.forEach(snapshot => {
    if (snapshot.val()?.ownerId === user.uid && snapshot.key) {
      ownedFarmIds.push(snapshot.key);
    }

    return false;
  });

  const ownedFarms = new Set(ownedFarmIds);

  // Remove each owned farm and its related records.
  for (const farmId of ownedFarmIds) {
    updates[`farms/${farmId}`] = null;
    updates[`palms/${farmId}`] = null;
    updates[`monitoringHistory/${farmId}`] = null;
    updates[`treatmentRecords/${farmId}`] = null;
    updates[`alerts/${farmId}`] = null;
  }

  // Release devices belonging to deleted farms.
  devicesSnapshot.forEach(snapshot => {
    const device = snapshot.val();

    if (
      snapshot.key &&
      device?.farmId &&
      ownedFarms.has(device.farmId)
    ) {
      const deviceId = snapshot.key;

      updates[`monitoringDevices/${deviceId}`] = {
        connectionStatus: 'Offline',
      };

      updates[`monitoringState/${deviceId}`] = null;
    }

    return false;
  });

  // Unassign farmers from deleted farms.
  usersSnapshot.forEach(snapshot => {
    const account = snapshot.val();

    if (
      snapshot.key &&
      snapshot.key !== user.uid &&
      account?.role === 'Farmer' &&
      account?.farmId &&
      ownedFarms.has(account.farmId)
    ) {
      updates[`users/${snapshot.key}/farmId`] = null;
    }

    return false;
  });

  // Remove invitations belonging to the user or deleted farms.
  invitationsSnapshot.forEach(snapshot => {
    const invitation = snapshot.val();

    if (
      snapshot.key &&
      (
        invitation?.farmerId === user.uid ||
        (
          invitation?.farmId &&
          ownedFarms.has(invitation.farmId)
        )
      )
    ) {
      updates[`farmInvitations/${snapshot.key}`] = null;
    }

    return false;
  });

  try {
    // Clean up related data, but preserve the user's profile.
    if (Object.keys(updates).length > 0) {
      await database.ref().update(updates);
    }

    // Delete Authentication after database cleanup succeeds.
    await getAuth().deleteUser(user.uid);

    // Remove the user profile only after Auth deletion succeeds.
    await database.ref(`users/${user.uid}`).remove();

    return {
      success: true,
    };
  } catch (error) {
    console.error('deleteAccount failed:', {
      uid: user.uid,
      error,
    });

    throw new HttpsError(
      'internal',
      'Account deletion could not be completed.'
    );
  }
});


// A signed-in Firebase Auth user may create their profile exactly once.
// Role and farmId are immutable to clients after registration.
export const registerProfile = onCall(options, async request => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in first.');
  const uid = request.auth.uid;
  const data = object(request.data);
  if (Object.keys(data).some(k => !['fullName', 'phoneNumber', 'role', 'preferredLanguage'].includes(k))) {
    throw new HttpsError('invalid-argument', 'Unexpected profile fields.');
  }
  const fullName = stringField(data.fullName, 'fullName', 120);
  const phoneNumber = stringField(data.phoneNumber, 'phoneNumber', 25);
  if (data.role !== 'FarmOwner' && data.role !== 'Farmer') throw new HttpsError('invalid-argument', 'Invalid role.');
  if (data.preferredLanguage !== 'ar' && data.preferredLanguage !== 'en') throw new HttpsError('invalid-argument', 'Invalid language.');
  const authUser = await getAuth().getUser(uid);
  if (!authUser.email || !authUser.emailVerified) throw new HttpsError('failed-precondition', 'Verified email required.');
  const profile = {fullName, phoneNumber, role: data.role, preferredLanguage: data.preferredLanguage,
    email: authUser.email, notificationsEnabled: true};
  const tx = await db().ref(`users/${uid}`).transaction(current => current ? undefined : profile, undefined, false);
  if (!tx.committed) throw new HttpsError('already-exists', 'Profile already exists.');
  return {success: true};
});

export const updateProfile = onCall(options, async request => {
  const user = await actor(request);
  const data = object(request.data);
  const allowed = ['fullName', 'phoneNumber', 'preferredLanguage', 'notificationsEnabled'];
  if (!Object.keys(data).length || Object.keys(data).some(k => !allowed.includes(k))) {
    throw new HttpsError('invalid-argument', 'Invalid profile changes.');
  }
  const patch: Record<string, unknown> = {};
  if ('fullName' in data) patch.fullName = stringField(data.fullName, 'fullName', 120);
  if ('phoneNumber' in data) patch.phoneNumber = stringField(data.phoneNumber, 'phoneNumber', 25);
  if ('preferredLanguage' in data) {
    if (data.preferredLanguage !== 'ar' && data.preferredLanguage !== 'en') throw new HttpsError('invalid-argument', 'Invalid language.');
    patch.preferredLanguage = data.preferredLanguage;
  }
  if ('notificationsEnabled' in data) {
    if (typeof data.notificationsEnabled !== 'boolean') throw new HttpsError('invalid-argument', 'Invalid notification setting.');
    patch.notificationsEnabled = data.notificationsEnabled;
  }
  await db().ref(`users/${user.uid}`).update(patch);
  return {success: true};
});



export const getMyAssignedFarm = onCall(options, async (request) => {
  const user = await actor(request);

  if (user.role !== 'Farmer') {
    throw new HttpsError(
      'permission-denied',
      'Only farmers can access this information.'
    );
  }

  const userSnapshot = await db().ref(`users/${user.uid}`).get();
  const farmer = userSnapshot.val();

  if (!farmer || !farmer.farmId) {
    return {farmName: null};
  }

  const farmSnapshot = await db()
    .ref(`farms/${farmer.farmId}`)
    .get();

  const farm = farmSnapshot.val();

  if (!farm || farm.deleting === true) {
    return {farmName: null};
  }

  return {
    farmName: String(farm.farmName ?? ''),
  };
});
