import {getAuth} from 'firebase-admin/auth';
import {getApp} from 'firebase-admin/app';
import {onCall, HttpsError} from 'firebase-functions/v2/https';
import {actor, db, id, object, stringField} from './common';

const options = {
  region: 'us-central1',
  maxInstances: 10,
};

type DataMap = Record<string, any>;

function asMap(value: unknown): DataMap | null {
  if (
    value === null ||
    typeof value !== 'object' ||
    Array.isArray(value)
  ) {
    return null;
  }

  return value as DataMap;
}

function isAssigned(value: unknown): boolean {
  return typeof value === 'string' && value.trim().length > 0;
}

// =====================================================
// 1. SEARCH FARMERS BY NAME
// =====================================================

export const searchFarmers = onCall(options, async request => {
  const user = await actor(request);

  if (user.role !== 'FarmOwner') {
    throw new HttpsError(
      'permission-denied',
      'Only farm owners can search for farmers.'
    );
  }

  const data = object(request.data);
  const farmId = id(data.farmId, 'farmId');
  const query = stringField(data.name, 'name', 80);

  if (query.length < 2) {
    throw new HttpsError(
      'invalid-argument',
      'Enter at least two characters.'
    );
  }

  // Verify that the requesting user owns this farm.
  const farmSnapshot = await db()
    .ref(`farms/${farmId}`)
    .get();

  const farm = asMap(farmSnapshot.val());

  if (
    !farm ||
    farm.ownerId !== user.uid ||
    farm.deleting === true
  ) {
    throw new HttpsError(
      'permission-denied',
      'You do not have access to this farm.'
    );
  }

  // Search using the beginning of fullName.
  // Results are deliberately limited.
  const snapshot = await db()
    .ref('users')
    .orderByChild('fullName')
    .startAt(query)
    .endAt(query + '\uf8ff')
    .limitToFirst(50)
    .get();

  const farmers: Array<{
    farmerId: string;
    fullName: string;
    phoneNumber: string;
  }> = [];

  snapshot.forEach(child => {
    const farmer = asMap(child.val());

    if (
      child.key &&
      farmer?.role === 'Farmer' &&
      !isAssigned(farmer.farmId)
    ) {
      farmers.push({
        farmerId: child.key,
        fullName: String(farmer.fullName ?? ''),
        phoneNumber: typeof farmer.phoneNumber === 'string'
          ? farmer.phoneNumber.trim()
          : '',
      });
    }

    // Stop after finding ten available farmers.
    return farmers.length >= 10;
  });

  return {
    farmers,
  };
});

// ETag compare-and-swap on a single farmer profile, never on the DB root.
// The farmer's invitation is canonical; the owner index is a UI projection.
const maxCasAttempts = 6;

type EditProfile = (profile: DataMap) => DataMap;


function profileUrl(uid: string): string {
  const app = getApp();
  const databaseURL = app.options.databaseURL;

  if (!databaseURL) {
    throw new HttpsError(
      'internal',
      'Database URL is missing.'
    );
  }

  const emulator = process.env.FIREBASE_DATABASE_EMULATOR_HOST;
  if (emulator) {
    const namespace = new URL(databaseURL).hostname.split('.')[0];
    const url = new URL(
      `http://${emulator}/users/${encodeURIComponent(uid)}.json`
    );
    url.searchParams.set('ns', namespace);
    return url.toString();
  }

  return `${databaseURL.replace(/\/$/, '')}/users/${encodeURIComponent(uid)}.json`;
}


async function restHeaders(): Promise<Record<string, string>> {
  if (process.env.FIREBASE_DATABASE_EMULATOR_HOST) {
    return {Authorization: 'Bearer owner'};
  }
  const credential = getApp().options.credential;
  if (!credential) throw new HttpsError('internal', 'Admin credential is unavailable.');
  const token = await credential.getAccessToken();
  return {Authorization: `Bearer ${token.access_token}`};
}

async function compareAndSwapProfile(uid: string, edit: EditProfile): Promise<number> {
  const url = profileUrl(uid);
  const authHeaders = await restHeaders();
  for (let attempt = 0; attempt < maxCasAttempts; attempt++) {
    const read = await fetch(url, {
      headers: {...authHeaders, 'X-Firebase-ETag': 'true'},
    });
    if (!read.ok) throw new HttpsError('internal', 'Could not read farmer profile.');
    const etag = read.headers.get('etag');
    if (!etag) throw new HttpsError('internal', 'Firebase did not return an ETag.');
    const profile = asMap(await read.json());
    if (!profile) throw new HttpsError('not-found', 'Farmer profile not found.');
    const updated = edit(structuredClone(profile));
    const revision = (Number.isSafeInteger(profile.invitationRevision)
      ? profile.invitationRevision : 0) + 1;
    updated.invitationRevision = revision;
    const write = await fetch(url, {
      method: 'PUT',
      headers: {
        ...authHeaders,
        'Content-Type': 'application/json',
        'if-match': etag,
      },
      body: JSON.stringify(updated),
    });
    if (write.ok) return revision;
    if (write.status !== 412) {
      throw new HttpsError('internal', 'Could not update farmer profile.');
    }
  }
  throw new HttpsError('aborted', 'The profile changed concurrently. Please retry.');
}

function invitationOwnerId(farm: DataMap | null): string {
  if (!farm || farm.deleting === true || typeof farm.ownerId !== 'string') {
    throw new HttpsError('failed-precondition', 'Farm is unavailable.');
  }
  return farm.ownerId;
}

async function requireFarm(farmId: string): Promise<DataMap> {
  const farm = asMap((await db().ref(`farms/${farmId}`).get()).val());
  invitationOwnerId(farm);
  return farm!;
}

async function updateOwnerInvitationPair(
  ownerId: string, farmId: string, farmerId: string, revision: number,
  replacement?: {id: string; data: DataMap},
): Promise<boolean> {
  await db().ref(`users/${ownerId}`).transaction(current => {
    // An empty local cache must reach the server for comparison.
    if (current === null) return null;
    const owner = asMap(current);
    if (owner?.role !== 'FarmOwner') return;

    const revisions = asMap(owner.sentFarmInvitationRevisions) ?? {};
    const farmRevisions = asMap(revisions[farmId]) ?? {};
    // Retain the revision even when the last row is removed. A delayed write
    // from an older action must never recreate an accepted or canceled row.
    if ((farmRevisions[farmerId] ?? 0) >= revision) return;

    const sent = {...asMap(owner.sentFarmInvitations)};
    for (const [id, value] of Object.entries(sent)) {
      const entry = asMap(value);
      if (entry?.farmId === farmId && entry.farmerId === farmerId) delete sent[id];
    }
    if (replacement) sent[replacement.id] = replacement.data;

    return {
      ...owner,
      sentFarmInvitations: sent,
      sentFarmInvitationRevisions: {
        ...revisions,
        [farmId]: {...farmRevisions, [farmerId]: revision},
      },
    };
  }, undefined, false);

  if (!replacement) return true;
  // Farm deletion may have swept the user records before this projection ran.
  const farm = asMap((await db().ref(`farms/${farmId}`).get()).val());
  if (farm?.ownerId === ownerId && farm.deleting !== true) return true;
  await db().ref(`users/${ownerId}/sentFarmInvitations/${replacement.id}`).remove();
  return false;
}

// Recipient has the canonical invitation. Owner stores an embedded list index.
export const sendInvitation = onCall(options, async request => {
  const owner = await actor(request);
  if (owner.role !== 'FarmOwner') {
    throw new HttpsError('permission-denied', 'Only owners can invite farmers.');
  }
  const data = object(request.data);
  const farmId = id(data.farmId, 'farmId');
  let farmerId: string;
  if (data.farmerId !== undefined) {
    farmerId = id(data.farmerId, 'farmerId');
  } else {
    const email = stringField(data.email, 'email', 254).toLowerCase();
    try {
      farmerId = (await getAuth().getUserByEmail(email)).uid;
    } catch {
      throw new HttpsError('not-found', 'Farmer account not found.');
    }
  }
  const farm = await requireFarm(farmId);
  if (farm.ownerId !== owner.uid) {
    throw new HttpsError('permission-denied', 'You do not own this farm.');
  }
  const newId = db().ref('users').push().key!;
  const newInvitation = {farmId, farmerId, createdAt: Date.now()};
  let invitationId = newId;
  let invitation: DataMap = newInvitation;
  const revision = await compareAndSwapProfile(farmerId, profile => {
    if (profile.role !== 'Farmer' || isAssigned(profile.farmId)) {
      throw new HttpsError('failed-precondition', 'Farmer is assigned or already invited.');
    }
    const pending = Object.entries(asMap(profile.farmInvitations) ?? {});
    if (pending.length !== 0) {
      const [pendingId, value] = pending[0];
      const existing = asMap(value);
      if (pending.length !== 1 || !existing ||
          existing.farmId !== farmId || existing.farmerId !== farmerId) {
        throw new HttpsError('failed-precondition', 'Farmer is assigned or already invited.');
      }
      // Reproject an interrupted same-farm send using its canonical ID.
      invitationId = pendingId;
      invitation = existing;
      return profile;
    }
    invitationId = newId;
    invitation = newInvitation;
    profile.farmInvitations = {[invitationId]: invitation};
    return profile;
  });
  let farmAvailable: boolean;
  try {
    farmAvailable = await updateOwnerInvitationPair(owner.uid, farmId, farmerId, revision,
      {id: invitationId, data: invitation});
  } catch (error) {
    // Canonical invitation is safe; a retry must not create a second invite.
    console.error('Owner invitation index sync failed:', error);
    throw new HttpsError('internal', 'Invitation created but owner index sync failed.');
  }
  if (!farmAvailable) {
    // Remove only this invite. The farmer may already have another invitation.
    await compareAndSwapProfile(farmerId, profile => {
      const pending = asMap(profile.farmInvitations);
      if (pending?.[invitationId]?.farmId === farmId) delete pending[invitationId];
      return profile;
    });
    throw new HttpsError('failed-precondition', 'Farm is unavailable.');
  }
  return {success: true, invitationId};
});

export const acceptInvitation = onCall(options, async request => {
  const farmer = await actor(request);
  if (farmer.role !== 'Farmer') {
    throw new HttpsError('permission-denied', 'Only farmers can accept invitations.');
  }
  const invitationId = id(object(request.data).invitationId, 'invitationId');
  const invitation = asMap((await db().ref(`users/${farmer.uid}/farmInvitations/${invitationId}`).get()).val());
  if (!invitation || invitation.farmerId !== farmer.uid) {
    throw new HttpsError('not-found', 'Invitation not found.');
  }
  const farmId = id(invitation.farmId, 'farmId');
  const farm = await requireFarm(farmId);
  const ownerId = invitationOwnerId(farm);
  const revision = await compareAndSwapProfile(farmer.uid, profile => {
    const current = asMap(profile.farmInvitations)?.[invitationId];
    if (profile.role !== 'Farmer' || isAssigned(profile.farmId) ||
        !current || current.farmId !== farmId || current.farmerId !== farmer.uid) {
      throw new HttpsError('failed-precondition', 'Invitation unavailable or farmer already assigned.');
    }
    profile.farmId = farmId;
    delete profile.farmInvitations[invitationId];
    return profile;
  });
  await updateOwnerInvitationPair(ownerId, farmId, farmer.uid, revision);
  return {success: true};
});

export const rejectInvitation = onCall(options, async request => {
  const farmer = await actor(request);
  if (farmer.role !== 'Farmer') {
    throw new HttpsError('permission-denied', 'Only farmers can reject invitations.');
  }
  const invitationId = id(object(request.data).invitationId, 'invitationId');
  const invitation = asMap((await db().ref(`users/${farmer.uid}/farmInvitations/${invitationId}`).get()).val());
  if (!invitation || invitation.farmerId !== farmer.uid) {
    throw new HttpsError('not-found', 'Invitation not found.');
  }
  const farmId = id(invitation.farmId, 'farmId');
  const farm = asMap((await db().ref(`farms/${farmId}`).get()).val());
  const ownerId = farm?.deleting !== true && typeof farm?.ownerId === 'string'
    ? farm.ownerId : null;
  const revision = await compareAndSwapProfile(farmer.uid, profile => {
    const current = asMap(profile.farmInvitations)?.[invitationId];
    if (!current || current.farmerId !== farmer.uid || current.farmId !== farmId) {
      throw new HttpsError('not-found', 'Invitation not found.');
    }
    delete profile.farmInvitations[invitationId];
    return profile;
  });
  if (ownerId) {
    await updateOwnerInvitationPair(ownerId, farmId, farmer.uid, revision,
      {id: invitationId, data: {...invitation, status: 'rejected'}});
  }
  return {success: true};
});

export const cancelInvitation = onCall(options, async request => {
  const owner = await actor(request);
  if (owner.role !== 'FarmOwner') {
    throw new HttpsError('permission-denied', 'Only owners can cancel invitations.');
  }
  const invitationId = id(object(request.data).invitationId, 'invitationId');
  const invitation = asMap((await db().ref(`users/${owner.uid}/sentFarmInvitations/${invitationId}`).get()).val());
  if (!invitation) throw new HttpsError('not-found', 'Invitation not found.');
  if (invitation.status === 'rejected') {
    throw new HttpsError('failed-precondition', 'Rejected invitations cannot be canceled.');
  }
  const farmId = id(invitation.farmId, 'farmId');
  const farmerId = id(invitation.farmerId, 'farmerId');
  const farm = await requireFarm(farmId);
  if (farm.ownerId !== owner.uid) {
    throw new HttpsError('permission-denied', 'You do not own this farm.');
  }
  const revision = await compareAndSwapProfile(farmerId, profile => {
    const current = asMap(profile.farmInvitations)?.[invitationId];
    if (!current || current.farmerId !== farmerId || current.farmId !== farmId) {
      throw new HttpsError('failed-precondition', 'Invitation changed or unavailable.');
    }
    delete profile.farmInvitations[invitationId];
    return profile;
  });
  await updateOwnerInvitationPair(owner.uid, farmId, farmerId, revision);
  return {success: true};
});

export const removeFarmer = onCall(options, async request => {
  const owner = await actor(request);
  if (owner.role !== 'FarmOwner') throw new HttpsError('permission-denied', 'Only owners can remove farmers.');
  const data = object(request.data);
  const farmId = id(data.farmId, 'farmId');
  const farmerId = id(data.farmerId, 'farmerId');
  const farm = (await db().ref(`farms/${farmId}`).get()).val();
  if (!farm || farm.deleting || farm.ownerId !== owner.uid) {
    throw new HttpsError('permission-denied', 'You do not have access to this farm.');
  }
  const ref = db().ref(`users/${farmerId}`);
  let removed = false;
  const tx = await ref.transaction(current => {
    removed = false;
    // Let the server compare the initially empty local cache using its current state.
    if (current === null) return null;
    const profile = asMap(current);
    if (profile?.role !== 'Farmer' || profile.farmId !== farmId) return;
    const updated = {...profile};
    delete updated.farmId;
    removed = true;
    return updated;
  }, undefined, false);
  if (!tx.committed || !removed) throw new HttpsError('failed-precondition', 'Farmer not assigned to this farm.');
  return {success: true};
});

// Owner-facing listing replaces the old direct farmInvitations query.
export const listFarmInvitations = onCall(options, async request => {
  const owner = await actor(request);
  if (owner.role !== 'FarmOwner') throw new HttpsError('permission-denied', 'Only owners can list farm invitations.');
  const farmId = id(object(request.data).farmId, 'farmId');
  const farm = (await db().ref(`farms/${farmId}`).get()).val();
  if (!farm || farm.deleting || farm.ownerId !== owner.uid) {
    throw new HttpsError('permission-denied', 'You do not own this farm.');
  }
  const sent = (await db().ref(`users/${owner.uid}/sentFarmInvitations`).get()).val() ?? {};
  const invitations: Record<string, DataMap> = {};
  for (const [invitationId, invitation] of Object.entries(sent) as [string, DataMap][]) {
    if (invitation.farmId === farmId) invitations[invitationId] = invitation;
  }
  return {invitations};
});

export const getInvitationDetails = onCall(options, async request => {
  const user = await actor(request);
  const invitationId = id(object(request.data).invitationId, 'invitationId');
  const invitation = user.role === 'Farmer'
    ? asMap((await db().ref(`users/${user.uid}/farmInvitations/${invitationId}`).get()).val())
    : asMap((await db().ref(`users/${user.uid}/sentFarmInvitations/${invitationId}`).get()).val());
  const found = invitation ? {farmerId: id(invitation.farmerId, 'farmerId'), invitation} : null;
  if (!found?.invitation) throw new HttpsError('not-found', 'Invitation not found.');
  const farmId = id(found.invitation.farmId, 'farmId');
  const farmerId = id(found.farmerId, 'farmerId');
  const farm = (await db().ref(`farms/${farmId}`).get()).val();
  if (!farm || farm.deleting) throw new HttpsError('not-found', 'Farm not found.');
  if (!(user.role === 'FarmOwner' && farm.ownerId === user.uid) &&
      !(user.role === 'Farmer' && farmerId === user.uid)) {
    throw new HttpsError('permission-denied', 'You cannot view this invitation.');
  }
  const [farmerSnap, ownerSnap] = await Promise.all([
    db().ref(`users/${farmerId}`).get(), db().ref(`users/${farm.ownerId}`).get(),
  ]);
  return {
    farmName: String(farm.farmName ?? 'Unknown Farm'),
    ownerName: String(ownerSnap.val()?.fullName ?? 'Unknown Owner'),
    farmerName: String(farmerSnap.val()?.fullName ?? 'Unknown Farmer'),
    farmerEmail: String(farmerSnap.val()?.email ?? 'Unknown Farmer'),
  };
});
