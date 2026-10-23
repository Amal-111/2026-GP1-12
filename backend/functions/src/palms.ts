
import {onCall, HttpsError} from 'firebase-functions/v2/https';
import {applicationDefault, getApp} from 'firebase-admin/app';
import {actor, db, object, id, coord, integer, farmAccess} from './common';

const options = {region: 'us-central1', maxInstances: 10};

const TYPES = ['Sukkari', 'Khalas', 'Ajwa', 'Barhi'];

// Validate palm fields.
// Notes are not part of the palm data model.
function palmFields(
  d: Record<string, unknown>,
  partial: boolean
): Record<string, unknown> {
  const allowed = ['palmType', 'age', 'latitude', 'longitude'];

  if (
    Object.keys(d).some((key) => !allowed.includes(key)) ||
    (partial && Object.keys(d).length === 0)
  ) {
    throw new HttpsError(
      'invalid-argument',
      'Invalid palm fields.'
    );
  }

  const result: Record<string, unknown> = {};

  if (!partial || 'palmType' in d) {
    if (!TYPES.includes(d.palmType as string)) {
      throw new HttpsError(
        'invalid-argument',
        'Invalid palmType.'
      );
    }

    result.palmType = d.palmType;
  }

  if (!partial || 'age' in d) {
    result.age = integer(d.age, 'age', 0, 300);
  }

  if (!partial || 'latitude' in d) {
    result.latitude = coord(
      d.latitude,
      'latitude',
      -90,
      90
    );
  }

  if (!partial || 'longitude' in d) {
    result.longitude = coord(
      d.longitude,
      'longitude',
      -180,
      180
    );
  }

  return result;
}

// Use the Realtime Database REST endpoint for conditional writes.
function databaseEndpoint(): URL {
  const rootUrl = new URL(db().ref().toString());
  const emulatorHost = process.env.FIREBASE_DATABASE_EMULATOR_HOST;

  if (emulatorHost) {
    const configuredUrl = getApp().options.databaseURL;
    const sourceUrl = configuredUrl ? new URL(configuredUrl) : rootUrl;
    const namespace = sourceUrl.hostname.includes('.')
      ? sourceUrl.hostname.split('.')[0]
      : (getApp().options.projectId ?? '');

    if (!namespace) {
      throw new HttpsError('internal', 'Database namespace is missing.');
    }

    const url = new URL(`http://${emulatorHost}/.json`);
    url.searchParams.set('ns', namespace);
    return url;
  }

  return new URL('.json', rootUrl);
}

type DatabaseRoot = Record<string, any>;
const MAX_RETRIES = 5;

// Add a new palm and pair its sensor.
export const addPalm = onCall(options, async (request) => {
  const user = await actor(request);
  const d = object(request.data);

  const farmId = id(d.farmId, 'farmId');
  const deviceId = id(d.deviceId, 'deviceId');
  const fields = palmFields(object(d.palm), false);

  await farmAccess(user.uid, user.role, farmId, user.farmId);

  const endpoint = databaseEndpoint();
  const emulator = !!process.env.FIREBASE_DATABASE_EMULATOR_HOST;
  const token = emulator
    ? null
    : (await applicationDefault().getAccessToken()).access_token;

  // The owner token is supported only by the local database emulator.
  const authHeaders: Record<string, string> = emulator
    ? {Authorization: 'Bearer owner'}
    : {Authorization: `Bearer ${token}`};

  // Retry with fresh data when any concurrent database write occurs.
  for (let attempt = 0; attempt < MAX_RETRIES; attempt++) {
    const response = await fetch(endpoint, {
      method: 'GET',
      headers: {
        ...authHeaders,
        'X-Firebase-ETag': 'true',
      },
    });

    if (!response.ok) {
      const errorBody = await response.text();
      console.error('addPalm REST read failed', {
        status: response.status,
        error: errorBody,
      });
      throw new HttpsError('internal', 'Unable to read palm data.');
    }

    const etag = response.headers.get('etag');
    const root = await response.json() as DatabaseRoot | null;

    if (!etag || !root) {
      throw new HttpsError('failed-precondition', 'Database is empty or unavailable.');
    }

    const farm = root.farms?.[farmId];

    if (!farm) {
      throw new HttpsError('not-found', 'Farm not found in database.');
    }

    if (farm.deleting) {
      throw new HttpsError('failed-precondition', 'Unable to add palm: farm-deleting.');
    }

    // Recheck access against the current snapshot, not a previous one.
    const hasAccess = user.role === 'FarmOwner'
      ? farm.ownerId === user.uid
      : (user.role === 'Farmer' &&
          root.users?.[user.uid]?.role === 'Farmer' &&
          root.users[user.uid].farmId === farmId);

    if (!hasAccess) {
      throw new HttpsError('permission-denied', 'No access to this farm.');
    }

    const existingDevice = root.monitoringDevices?.[deviceId];

    if (existingDevice && (existingDevice.farmId || existingDevice.palmId)) {
      throw new HttpsError(
        'failed-precondition',
        'Unable to add palm: device-already-paired.'
      );
    }

    const registeredPalms = Object.keys(root.palms?.[farmId] ?? {}).length;
    const capacity = farm.totalPalms;

    if (!Number.isSafeInteger(capacity) || capacity <= 0) {
      throw new HttpsError('failed-precondition', 'Unable to add palm: invalid-farm-capacity.');
    }

    if (registeredPalms >= capacity) {
      throw new HttpsError('failed-precondition', 'Unable to add palm: farm-full.');
    }

    const nextNumber = (farm.lastPalmNumber ?? 0) + 1;

    if (!Number.isSafeInteger(nextNumber) || nextNumber <= 0) {
      throw new HttpsError('failed-precondition', 'Unable to add palm: invalid-palm-counter.');
    }

    const palmId = `P${String(nextNumber).padStart(3, '0')}`;

    if (root.palms?.[farmId]?.[palmId]) {
      throw new HttpsError('failed-precondition', 'Unable to add palm: palm-id-conflict.');
    }

    // Prepare all linked changes in the same conditional write.
    root.palms ??= {};
    root.palms[farmId] ??= {};
    root.palms[farmId][palmId] = {
      ...fields,
      deviceId,
      healthStatus: 'Healthy',
    };

    root.monitoringDevices ??= {};
    root.monitoringDevices[deviceId] = {
      ...(existingDevice ?? {}),
      farmId,
      palmId,
      connectionStatus: 'Offline',
    };

    if (root.monitoringState) {
      delete root.monitoringState[deviceId];
    }

    farm.lastPalmNumber = nextNumber;

    // A changed ETag rejects the entire write (HTTP 412).
    const writeResponse = await fetch(endpoint, {
      method: 'PUT',
      headers: {
        ...authHeaders,
        'Content-Type': 'application/json',
        'if-match': etag,
      },
      body: JSON.stringify(root),
    });

    if (writeResponse.ok) {
      console.log('Palm created successfully', {farmId, palmId, deviceId});
      return {success: true, palmId};
    }

    if (writeResponse.status === 412) {
      continue;
    }

    const errorBody = await writeResponse.text();
    console.error('addPalm REST write failed', {
      status: writeResponse.status,
      error: errorBody,
    });
    throw new HttpsError('internal', 'Unable to save palm data.');
  }

  throw new HttpsError(
    'aborted',
    'Palm could not be added due to concurrent updates. Please retry.'
  );
});

// Update palm age and type only.
export const updatePalm = onCall(options, async (request) => {
  const user = await actor(request);
  const d = object(request.data);

  const farmId = id(d.farmId, 'farmId');
  const palmId = id(d.palmId, 'palmId');

  await farmAccess(
    user.uid,
    user.role,
    farmId,
    user.farmId,
    true
  );

  const changes = object(d.changes);
  const allowed = ['age', 'palmType'];

  if (
    Object.keys(changes).length === 0 ||
    Object.keys(changes).some(
      (key) => !allowed.includes(key)
    )
  ) {
    throw new HttpsError(
      'invalid-argument',
      'Only age and palmType can be updated.'
    );
  }

  const patch: Record<string, unknown> = {};

  if ('age' in changes) {
    patch.age = integer(
      changes.age,
      'age',
      0,
      300
    );
  }

  if ('palmType' in changes) {
    if (!TYPES.includes(changes.palmType as string)) {
      throw new HttpsError(
        'invalid-argument',
        'Invalid palmType.'
      );
    }

    patch.palmType = changes.palmType;
  }

  const farmSnapshot = await db()
    .ref(`farms/${farmId}`)
    .get();

  if (
    !farmSnapshot.exists() ||
    farmSnapshot.child('deleting').val() === true
  ) {
    throw new HttpsError(
      'failed-precondition',
      'Farm is unavailable.'
    );
  }

  const palmRef = db().ref(
    `palms/${farmId}/${palmId}`
  );

  const existing = await palmRef.get();

  if (!existing.exists()) {
    throw new HttpsError(
      'not-found',
      'Palm not found.'
    );
  }

  // This avoids the initial-null transaction issue.
  // However, a concurrent deletion could occur after
  // the existence check, so this is not a final
  // concurrency-safe implementation.
  await palmRef.update(patch);

  return {success: true};
});

// Delete a palm and release its sensor.

export const deletePalm = onCall(options, async (request) => {
  const user = await actor(request);
  const data = object(request.data);

  const farmId = id(data.farmId, 'farmId');
  const palmId = id(data.palmId, 'palmId');

  await farmAccess(
    user.uid,
    user.role,
    farmId,
    user.farmId,
    true
  );

  const farmSnapshot = await db()
    .ref(`farms/${farmId}`)
    .get();

  if (
    !farmSnapshot.exists() ||
    farmSnapshot.child('deleting').val() === true
  ) {
    throw new HttpsError(
      'failed-precondition',
      'Farm is unavailable.'
    );
  }

  const palmSnapshot = await db()
    .ref(`palms/${farmId}/${palmId}`)
    .get();

  if (!palmSnapshot.exists()) {
    throw new HttpsError(
      'not-found',
      'Palm not found.'
    );
  }

  const palm = palmSnapshot.val();
  const deviceId = palm.deviceId;

  const updates: Record<string, unknown> = {
    [`palms/${farmId}/${palmId}`]: null,
    [`monitoringHistory/${farmId}/${palmId}`]: null,
    [`treatmentRecords/${farmId}/${palmId}`]: null,
  };

  if (deviceId) {
    const deviceSnapshot = await db()
      .ref(`monitoringDevices/${deviceId}`)
      .get();

    const device = deviceSnapshot.val();

    if (
      device &&
      device.farmId === farmId &&
      device.palmId === palmId
    ) {
      updates[`monitoringDevices/${deviceId}`] = {
        connectionStatus: 'Offline',
      };

      updates[`monitoringState/${deviceId}`] = null;
    }
  }

  const alertsSnapshot = await db()
    .ref(`alerts/${farmId}`)
    .get();

  alertsSnapshot.forEach((child) => {
    if (child.val()?.palmId === palmId) {
      updates[`alerts/${farmId}/${child.key}`] = null;
    }
  });

  await db().ref().update(updates);

  return {success: true};
});

