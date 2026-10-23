
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
      0
    );
  }

  const farmRef = db().ref(`farms/${farmId}`);

  const [farmSnapshot, palmsSnapshot] = await Promise.all([
    farmRef.get(),
    db().ref(`palms/${farmId}`).get(),
  ]);

  const farm = asMap(farmSnapshot.val());

  if (
    !farm ||
    farm.ownerId !== user.uid ||
    farm.deleting === true
  ) {
    throw new HttpsError(
      'permission-denied',
      'Farm is unavailable or not owned by this account.'
    );
  }

  const palms = asMap(palmsSnapshot.val()) ?? {};
  const registeredPalms = Object.keys(palms).length;

  if (
    'totalPalms' in changes &&
    changes.totalPalms < registeredPalms
  ) {
    throw new HttpsError(
      'failed-precondition',
      'Farm capacity cannot be less than registered palms.'
    );
  }

  // Update only the requested fields.
  // This avoids a transaction on the database root.
  await farmRef.update(changes);

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
    const [
      devicesSnapshot,
      usersSnapshot,
      invitationsSnapshot,
    ] = await Promise.all([
      db().ref('monitoringDevices').get(),
      db().ref('users').get(),
      db().ref('farmInvitations').get(),
    ]);

    const updates: DataMap = {
      [`farms/${farmId}`]: null,
      [`palms/${farmId}`]: null,
      [`monitoringHistory/${farmId}`]: null,
      [`treatmentRecords/${farmId}`]: null,
      [`alerts/${farmId}`]: null,
    };

    // Disconnect devices associated with the deleted farm.
    
    // Release devices associated with the deleted farm.
    devicesSnapshot.forEach(snapshot => {
      const device = asMap(snapshot.val());

      if (device?.farmId === farmId && snapshot.key) {
        const deviceId = snapshot.key;

        // Remove the old farm and palm assignment.
        updates[`monitoringDevices/${deviceId}`] = {
          connectionStatus: 'Offline',
        };

        // Clear the previous sensor monitoring state.
        updates[`monitoringState/${deviceId}`] = null;
      }

      return false;
    });


    // Unassign all farmers belonging to this farm.
    usersSnapshot.forEach(snapshot => {
      const account = asMap(snapshot.val());

      if (
        account?.role === 'Farmer' &&
        account.farmId === farmId &&
        snapshot.key
      ) {
        updates[`users/${snapshot.key}/farmId`] = null;
      }

      return false;
    });

    // Remove all pending invitations for this farm.
    invitationsSnapshot.forEach(snapshot => {
      const invitation = asMap(snapshot.val());

      if (
        invitation?.farmId === farmId &&
        snapshot.key
      ) {
        updates[
          `farmInvitations/${snapshot.key}`
        ] = null;
      }

      return false;
    });

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
