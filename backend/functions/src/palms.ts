import {onCall, HttpsError} from 'firebase-functions/v2/https';
import {applicationDefault, getApp} from 'firebase-admin/app';
import {actor, db, object, id, coord, integer, farmAccess, findDevicePalm} from './common';

const options = {region: 'us-central1', maxInstances: 10};

const PALM_TYPES = ['Sukkari', 'Khalas', 'Ajwa', 'Barhi'];

// Validate palm fields.
// Notes are not part of the palm data model.
function palmFields(
  palmInput: Record<string, unknown>,
  partial: boolean
): Record<string, unknown> {
  const allowed = ['palmType', 'age', 'latitude', 'longitude'];

  if (
    Object.keys(palmInput).some((key) => !allowed.includes(key)) ||
    (partial && Object.keys(palmInput).length === 0)
  ) {
    throw new HttpsError(
      'invalid-argument',
      'Invalid palm fields.'
    );
  }

  const result: Record<string, unknown> = {};

  if (!partial || 'palmType' in palmInput) {
    if (!PALM_TYPES.includes(palmInput.palmType as string)) {
      throw new HttpsError(
        'invalid-argument',
        'Invalid palmType.'
      );
    }

    result.palmType = palmInput.palmType;
  }

  if (!partial || 'age' in palmInput) {
    result.age = integer(palmInput.age, 'age', 0, 300);
  }

  if (!partial || 'latitude' in palmInput) {
    result.latitude = coord(
      palmInput.latitude,
      'latitude',
      -90,
      90
    );
  }

  if (!partial || 'longitude' in palmInput) {
    result.longitude = coord(
      palmInput.longitude,
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
const REST_TIMEOUT_MS = 15000;
const RETRY_BASE_MS = 120;

// Limit the duration of root ETag requests until the schema is migrated.
async function requestWithTimeout(endpoint: URL, options: RequestInit): Promise<Response> {
  try {
    return await fetch(endpoint, {
      ...options,
      signal: AbortSignal.timeout(REST_TIMEOUT_MS),
    });
  } catch (error) {
    console.error('Palm database request failed:', error);
    throw new HttpsError('unavailable', 'Palm database is unavailable. Try again.');
  }
}

// Reduce repeated conflicts without changing the existing atomic write.
async function waitAfterConflict(attempt: number): Promise<void> {
  const cap = Math.min(1000, RETRY_BASE_MS * 2 ** attempt);
  const delay = Math.floor(cap / 2 + Math.random() * cap / 2);
  await new Promise<void>(resolve => setTimeout(resolve, delay));
}

// Add a new palm and pair its sensor.
export const addPalm = onCall(options, async (request) => {
  const user = await actor(request);
  const data = object(request.data);

  const farmId = id(data.farmId, 'farmId');
  const deviceId = id(data.deviceId, 'deviceId');
  const palmInput = object(data.palm);
  const validatedPalmFields = palmFields(palmInput, false);

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

  // Read the root and its ETag together so the write can detect any intervening change.
  for (let attempt = 0; attempt < MAX_RETRIES; attempt++) {
    const readResponse = await requestWithTimeout(endpoint, {
      method: 'GET',
      headers: {
        ...authHeaders,
        'X-Firebase-ETag': 'true',
      },
    });

    if (!readResponse.ok) {
      const errorBody = await readResponse.text();
      console.error('addPalm REST read failed', {
        status: readResponse.status,
        error: errorBody,
      });
      throw new HttpsError('internal', 'Unable to read palm data.');
    }

    const etag = readResponse.headers.get('etag');
    const root = await readResponse.json() as DatabaseRoot | null;

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

    // Recheck ownership or assignment against the same snapshot used for the write.
    const currentProfile = root.users?.[user.uid];
    const stillOwnsFarm =
      user.role === 'FarmOwner' &&
      currentProfile?.role === 'FarmOwner' &&
      farm.ownerId === user.uid;
    const stillAssignedToFarm =
      user.role === 'Farmer' &&
      currentProfile?.role === 'Farmer' &&
      currentProfile.farmId === farmId;

    if (!stillOwnsFarm && !stillAssignedToFarm) {
      throw new HttpsError('permission-denied', 'No access to this farm.');
    }

    // Check all farms because a sensor can be paired with only one palm.
    if (findDevicePalm(root, deviceId)) {
      throw new HttpsError(
        'failed-precondition',
        'Unable to add palm: device-already-paired.'
      );
    }

    // Compare the current number of palms with the capacity in this snapshot.
    const registeredPalmCount = Object.keys(farm.palms ?? {}).length;
    const capacity = farm.totalPalms;

    if (!Number.isSafeInteger(capacity) || capacity <= 0) {
      throw new HttpsError('failed-precondition', 'Unable to add palm: invalid-farm-capacity.');
    }

    if (registeredPalmCount >= capacity) {
      throw new HttpsError('failed-precondition', 'Unable to add palm: farm-full.');
    }

    const candidatePalmNumber = (farm.lastPalmNumber ?? 0) + 1;

    if (!Number.isSafeInteger(candidatePalmNumber) || candidatePalmNumber <= 0) {
      throw new HttpsError('failed-precondition', 'Unable to add palm: invalid-palm-counter.');
    }

    const palmId = `P${String(candidatePalmNumber).padStart(3, '0')}`;

    if (farm.palms?.[palmId]) {
      throw new HttpsError('failed-precondition', 'Unable to add palm: palm-id-conflict.');
    }

    // Prepare all linked changes in the same conditional write.
    farm.palms ??= {};
    farm.palms[palmId] = {
      ...validatedPalmFields,
      deviceId,
      healthStatus: 'Healthy',
    };

    farm.palms[palmId].monitoringDevice = {
      deviceId,
      farmId,
      palmId,
      connectionStatus: 'Offline',
    };

    farm.lastPalmNumber = candidatePalmNumber;

    // Commit all changes only if the ETag still matches the root snapshot.
    const writeResponse = await requestWithTimeout(endpoint, {
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

    // A concurrent write changed the root. Read it again before retrying.
    if (writeResponse.status === 412) {
      if (attempt + 1 < MAX_RETRIES) {
        await waitAfterConflict(attempt);
      }
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

  const changes = object(data.changes);
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
    if (!PALM_TYPES.includes(changes.palmType as string)) {
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
    `farms/${farmId}/palms/${palmId}`
  );

  const transaction = await palmRef.transaction(current => {
    // A cold cache may be empty. A server-confirmed null is a no-op.
    if (current === null) {
      return null;
    }
    if (typeof current !== 'object' || Array.isArray(current)) {
      return;
    }
    return {...current, ...patch};
  }, undefined, false);
  if (!transaction.committed || !transaction.snapshot.exists()) {
    throw new HttpsError(
      'not-found',
      'Palm not found.'
    );
  }

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
    .ref(`farms/${farmId}/palms/${palmId}`)
    .get();

  if (!palmSnapshot.exists()) {
    throw new HttpsError(
      'not-found',
      'Palm not found.'
    );
  }

  // Deleting the palm also removes its sensor pairing and readings.
  const updates: Record<string, unknown> = {
    [`farms/${farmId}/palms/${palmId}`]: null,
  };
  await db().ref().update(updates);

  return {success: true};
});

