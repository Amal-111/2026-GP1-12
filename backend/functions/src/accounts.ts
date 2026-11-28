import {getAuth} from 'firebase-admin/auth';
import {onCall, HttpsError} from 'firebase-functions/v2/https';
import {actor, db, deleteFarmImages, object, stringField} from './common';

const options = {region: 'us-central1', maxInstances: 10};

// Account deletion and cleanup

// Remove owned farms and related records before deleting the Auth identity.
// RTDB and Auth are separate systems: production still needs retryable cleanup.
export const deleteAccount = onCall(options, async request => {
  const user = await actor(request);

  // Require a recent sign-in before deleting the account.
  const signInTimeSeconds = request.auth?.token.auth_time;

  if (
    typeof signInTimeSeconds !== 'number' ||
    Date.now() / 1000 - signInTimeSeconds > 300
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
    usersSnapshot,
  ] = await Promise.all([
    database.ref('farms').get(),
    database.ref('users').get(),
  ]);

  const cleanupUpdates: Record<string, unknown> = {};

  const ownedFarmIds: string[] = [];

  // Find farms owned by this account.
  farmsSnapshot.forEach(farmSnapshot => {
    if (farmSnapshot.val()?.ownerId === user.uid && farmSnapshot.key) {
      ownedFarmIds.push(farmSnapshot.key);
    }

    return false;
  });

  const ownedFarmIdSet = new Set(ownedFarmIds);

  // Remove each owned farm and its related records.
  for (const farmId of ownedFarmIds) {
    cleanupUpdates[`farms/${farmId}`] = null;
  }

  // Unassign farmers from deleted farms.
  usersSnapshot.forEach(profileSnapshot => {
    const profile = profileSnapshot.val();
    const profileId = profileSnapshot.key;

    if (
      profileId &&
      profileId !== user.uid &&
      profile?.role === 'Farmer' &&
      profile?.farmId &&
      ownedFarmIdSet.has(profile.farmId)
    ) {
      cleanupUpdates[`users/${profileId}/farmId`] = null;
    }

    return false;
  });

  // Clean up both the recipient's invitations and the owner's sent list.
  usersSnapshot.forEach(profileSnapshot => {
    const profileId = profileSnapshot.key;
    if (!profileId) {
      return false;
    }

    const receivedInvitations = profileSnapshot.val()?.farmInvitations ?? {};
    for (const [invitationId, invitation] of Object.entries(receivedInvitations) as [string, any][]) {
      if (
        profileId === user.uid ||
        invitation?.farmerId === user.uid ||
        ownedFarmIdSet.has(invitation?.farmId)
      ) {
        cleanupUpdates[`users/${profileId}/farmInvitations/${invitationId}`] = null;
      }
    }

    const sentInvitations = profileSnapshot.val()?.sentFarmInvitations ?? {};
    for (const [invitationId, invitation] of Object.entries(sentInvitations) as [string, any][]) {
      if (
        profileId === user.uid ||
        invitation?.farmerId === user.uid ||
        ownedFarmIdSet.has(invitation?.farmId)
      ) {
        cleanupUpdates[`users/${profileId}/sentFarmInvitations/${invitationId}`] = null;
      }
    }
    return false;
  });

  try {
    for (const farmId of ownedFarmIds) {
      await deleteFarmImages(user.uid, farmId);
    }

    // Clean up related data, but preserve the user's profile.
    if (Object.keys(cleanupUpdates).length > 0) {
      await database.ref().update(cleanupUpdates);
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

// Profile registration and updates

// Create one profile for a signed-in user with a verified email.
export const registerProfile = onCall(options, async request => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Sign in first.');
  }

  const uid = request.auth.uid;
  const data = object(request.data);
  const allowedFields = ['fullName', 'phoneNumber', 'role', 'preferredLanguage'];
  if (Object.keys(data).some(field => !allowedFields.includes(field))) {
    throw new HttpsError('invalid-argument', 'Unexpected profile fields.');
  }
  const fullName = stringField(data.fullName, 'fullName', 120);
  const phoneNumber = stringField(data.phoneNumber, 'phoneNumber', 25);
  if (data.role !== 'FarmOwner' && data.role !== 'Farmer') {
    throw new HttpsError('invalid-argument', 'Invalid role.');
  }
  if (data.preferredLanguage !== 'ar' && data.preferredLanguage !== 'en') {
    throw new HttpsError('invalid-argument', 'Invalid language.');
  }

  const authUser = await getAuth().getUser(uid);
  if (!authUser.email || !authUser.emailVerified) {
    throw new HttpsError('failed-precondition', 'Verified email required.');
  }

  const profile = {
    fullName,
    phoneNumber,
    role: data.role,
    preferredLanguage: data.preferredLanguage,
    email: authUser.email,
    notificationsEnabled: true,
  };

  // Check for an existing profile in the same transaction that creates it.
  const profileTransaction = await db().ref(`users/${uid}`).transaction(currentProfile => {
    if (currentProfile) {
      return undefined;
    }
    return profile;
  }, undefined, false);
  if (!profileTransaction.committed) {
    throw new HttpsError('already-exists', 'Profile already exists.');
  }
  return {success: true};
});

// Update editable profile fields without accepting role or farm assignment changes.
export const updateProfile = onCall(options, async request => {
  const user = await actor(request);
  const data = object(request.data);
  const allowedFields = ['fullName', 'phoneNumber', 'preferredLanguage', 'notificationsEnabled'];
  const requestedFields = Object.keys(data);
  if (requestedFields.length === 0 || requestedFields.some(field => !allowedFields.includes(field))) {
    throw new HttpsError('invalid-argument', 'Invalid profile changes.');
  }
  const profileUpdates: Record<string, unknown> = {};
  if ('fullName' in data) {
    profileUpdates.fullName = stringField(data.fullName, 'fullName', 120);
  }
  if ('phoneNumber' in data) {
    profileUpdates.phoneNumber = stringField(data.phoneNumber, 'phoneNumber', 25);
  }
  if ('preferredLanguage' in data) {
    if (data.preferredLanguage !== 'ar' && data.preferredLanguage !== 'en') {
      throw new HttpsError('invalid-argument', 'Invalid language.');
    }
    profileUpdates.preferredLanguage = data.preferredLanguage;
  }
  if ('notificationsEnabled' in data) {
    if (typeof data.notificationsEnabled !== 'boolean') {
      throw new HttpsError('invalid-argument', 'Invalid notification setting.');
    }
    profileUpdates.notificationsEnabled = data.notificationsEnabled;
  }
  await db().ref(`users/${user.uid}`).update(profileUpdates);
  return {success: true};
});

// Copy the signed-in user's verified email from Firebase Authentication.
export const syncVerifiedEmail = onCall(options, async request => {
  const user = await actor(request);

  // Read the email directly from Firebase Authentication.
  const authUser = await getAuth().getUser(user.uid);

  if (!authUser.email || !authUser.emailVerified) {
    throw new HttpsError(
      'failed-precondition',
      'A verified email is required.'
    );
  }

  const verifiedEmail = authUser.email.trim();

  // Update the saved profile using the verified Auth email.
  await db().ref(`users/${user.uid}/email`).set(verifiedEmail);

  return {
    success: true,
    email: verifiedEmail,
  };
});

// Farm assignment

// Return the assigned farm's name when the farm is available.
export const getMyAssignedFarm = onCall(options, async (request) => {
  const user = await actor(request);

  if (user.role !== 'Farmer') {
    throw new HttpsError(
      'permission-denied',
      'Only farmers can access this information.'
    );
  }

  const farmerSnapshot = await db().ref(`users/${user.uid}`).get();
  const farmer = farmerSnapshot.val();

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
