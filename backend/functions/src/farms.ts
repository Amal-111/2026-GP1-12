import {onCall, HttpsError} from 'firebase-functions/v2/https';
import {
  actor,
  db,
  object,
  id,
  stringField,
  optionalText,
  coord,
  integer,
  optionalFarmImage,
  deleteFarmImages,
  prepareFarmPhotoCleanup,
} from './common';

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

// =====================================================
// 1. CREATE FARM
// =====================================================

export const createFarm = onCall(options, async request => {
  const user = await actor(request);

  if (user.role !== 'FarmOwner') {
    throw new HttpsError(
      'permission-denied',
      'Only farm owners can create farms.'
    );
  }

  const data = object(request.data);

  const farmName = stringField(
    data.farmName,
    'farmName',
    100
  );

  const description = optionalText(
    data.description,
    'description'
  );

  const farmImage = optionalFarmImage(data.farmImage);

  const latitude = coord(
    data.latitude,
    'latitude',
    -90,
    90
  );

  const longitude = coord(
    data.longitude,
    'longitude',
    -180,
    180
  );

  const totalPalms = integer(
    data.totalPalms,
    'totalPalms',
    0
  );

  const farmRef = db().ref('farms').push();

  await farmRef.set({
    ownerId: user.uid,
    farmName,
    ...(description ? {description} : {}),
    ...(farmImage ? {farmImage} : {}),
    latitude,
    longitude,
    totalPalms,
    lastPalmNumber: 0,
  });

  return {
    success: true,
    farmId: farmRef.key,
  };
});

// =====================================================
// 2. UPDATE FARM
// =====================================================

export const updateFarm = onCall(options, async request => {
  const user = await actor(request);

  if (user.role !== 'FarmOwner') {
    throw new HttpsError(
      'permission-denied',
      'Only farm owners can update farms.'
    );
  }

  const data = object(request.data);
  const farmId = id(data.farmId, 'farmId');
  const patch = object(data.changes);

  const allowedFields = [
    'farmName',
    'description',
    'farmImage',
    'latitude',
    'longitude',
    'totalPalms',
  ];

  if (
    Object.keys(patch).length === 0 ||
    Object.keys(patch).some(
      key => !allowedFields.includes(key)
    )
  ) {
    throw new HttpsError(
      'invalid-argument',
      'Invalid farm fields.'
    );
  }

  const changes: DataMap = {};

  if ('farmName' in patch) {
    changes.farmName = stringField(
      patch.farmName,
      'farmName',
      100
    );
  }

  if ('description' in patch) {
    changes.description =
      optionalText(patch.description, 'description') ?? null;
  }

  if ('farmImage' in patch) {
    changes.farmImage =
      optionalFarmImage(patch.farmImage) ?? null;
  }

  if ('latitude' in patch) {
    changes.latitude = coord(
      patch.latitude,
      'latitude',
      -90,
      90
    );
  }

  if ('longitude' in patch) {
    changes.longitude = coord(
      patch.longitude,
      'longitude',
      -180,
      180
    );
  }

  if ('totalPalms' in patch) {
    changes.totalPalms = integer(
      patch.totalPalms,
      'totalPalms',
      1
    );
  }

  const farmRef = db().ref(`farms/${farmId}`);
  const includesPhotoChange = 'farmImage' in changes;
  let previousPhotoUrl: unknown;
  let cleanupPreviousPhoto: Awaited<ReturnType<typeof prepareFarmPhotoCleanup>>;

  // Capture the previous photo before updating its database reference.
  if (includesPhotoChange) {
    const farm = (await farmRef.get()).val();
    if (!farm || farm.ownerId !== user.uid || farm.deleting === true) {
      throw new HttpsError(
        'permission-denied',
        'Farm is unavailable or not owned by this account.'
      );
    }

    previousPhotoUrl = farm.farmImage ?? null;
    cleanupPreviousPhoto = await prepareFarmPhotoCleanup(
      user.uid,
      farmId,
      previousPhotoUrl,
      changes.farmImage
    );
  }

  let rejectionReason: 'unavailable' | 'capacity' | 'photo-changed' | undefined;
  const transaction = await farmRef.transaction(current => {
    rejectionReason = undefined;
    const farm = asMap(current);
    if (!farm || farm.ownerId !== user.uid || farm.deleting === true) {
      rejectionReason = 'unavailable';
      // Allow the conditional write to resolve a cold-cache null.
      return current === null ? null : undefined;
    }

    // Count palms in the transaction so concurrent additions are included.
    const registeredPalms = Object.keys(asMap(farm.palms) ?? {}).length;
    if ('totalPalms' in changes && changes.totalPalms < registeredPalms) {
      rejectionReason = 'capacity';
      // Let the server verify this snapshot and retry if the palm count changed.
      return farm;
    }

    // Abort if another update changed the photo after cleanup was prepared.
    if (includesPhotoChange && (farm.farmImage ?? null) !== previousPhotoUrl) {
      rejectionReason = 'photo-changed';
      return;
    }

    return {...farm, ...changes};
  }, undefined, false);

  if (rejectionReason === 'capacity') {
    throw new HttpsError(
      'failed-precondition',
      'Farm capacity cannot be less than registered palms.'
    );
  }
  if (rejectionReason === 'photo-changed') {
    throw new HttpsError(
      'aborted',
      'The farm photo changed. Reopen Farm Settings and retry.'
    );
  }
  if (!transaction.committed || rejectionReason === 'unavailable') {
    throw new HttpsError(
      'permission-denied',
      'Farm is unavailable or not owned by this account.'
    );
  }

  // Delete the previous image only after its reference has been updated.
  await cleanupPreviousPhoto?.();
  return {
    success: true,
  };
});

// =====================================================
// 3. DELETE FARM
// =====================================================

export const deleteFarm = onCall(options, async request => {
  const user = await actor(request);

  if (user.role !== 'FarmOwner') {
    throw new HttpsError(
      'permission-denied',
      'Only farm owners can delete farms.'
    );
  }

  const farmId = id(
    object(request.data).farmId,
    'farmId'
  );

  const farmRef = db().ref(`farms/${farmId}`);
  const farmSnapshot = await farmRef.get();
  const farm = asMap(farmSnapshot.val());

  if (!farm) {
    throw new HttpsError(
      'not-found',
      'Farm not found.'
    );
  }

  if (farm.ownerId !== user.uid) {
    throw new HttpsError(
      'permission-denied',
      'You do not own this farm.'
    );
  }

  // Allow retrying an incomplete farm deletion.
  if (farm.deleting !== true) {
    await farmRef.update({
      deleting: true,
    });
  }

  try {
    const usersSnapshot = await db().ref('users').get();
    const updates: DataMap = {[`farms/${farmId}`]: null};
    usersSnapshot.forEach(snapshot => {
      const account = asMap(snapshot.val());
      if (!snapshot.key || !account) {
        return false;
      }

      if (account.role === 'Farmer' && account.farmId === farmId) {
        updates[`users/${snapshot.key}/farmId`] = null;
      }

      const invitations = asMap(account.farmInvitations) ?? {};
      for (const [inviteId, invite] of Object.entries(invitations)) {
        if (asMap(invite)?.farmId === farmId) {
          updates[`users/${snapshot.key}/farmInvitations/${inviteId}`] = null;
        }
      }
      const sent = asMap(account.sentFarmInvitations) ?? {};
      for (const [inviteId, invite] of Object.entries(sent)) {
        if (asMap(invite)?.farmId === farmId) {
          updates[`users/${snapshot.key}/sentFarmInvitations/${inviteId}`] = null;
        }
      }
      return false;
    });

    // Delete all images belonging to this farm.
    await deleteFarmImages(user.uid, farmId);

    // Apply all cleanup changes in one database update.
    await db().ref().update(updates);

    return {
      success: true,
    };
  } catch (error) {
    // Leave deleting=true so a failed cleanup does not
    // make the farm appear active again.
    console.error('deleteFarm cleanup failed:', error);

    throw new HttpsError(
      'internal',
      'Farm deletion could not be completed.'
    );
  }
});
