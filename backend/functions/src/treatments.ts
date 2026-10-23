
import {onCall, HttpsError} from 'firebase-functions/v2/https';
import {applicationDefault, getApp} from 'firebase-admin/app';
import {actor, db, farmAccess, id, object, stringField, optionalText} from './common';

const options = {region: 'us-central1', maxInstances: 10};
const MAX_RETRIES = 5;

type DbObject = Record<string, any>;

// Build the REST endpoint for the current database.
function databaseEndpoint(): URL {
  const rootUrl = new URL(db().ref().toString());
  const emulatorHost = process.env.FIREBASE_DATABASE_EMULATOR_HOST;

  if (emulatorHost) {
    const configuredUrl = getApp().options.databaseURL;
    const sourceUrl = configuredUrl
      ? new URL(configuredUrl)
      : rootUrl;

    const namespace = sourceUrl.hostname.includes('.')
      ? sourceUrl.hostname.split('.')[0]
      : (getApp().options.projectId ?? '');

    if (!namespace) {
      throw new HttpsError(
        'internal',
        'Database namespace is missing.'
      );
    }

    const url = new URL(`http://${emulatorHost}/.json`);
    url.searchParams.set('ns', namespace);
    

    return url;
  }

  return new URL('.json', rootUrl);
}

// Record treatment and update the related data atomically.
export const recordTreatment = onCall(options, async (request) => {
  const user = await actor(request);
  const data = object(request.data);

  const farmId = id(data.farmId, 'farmId');
  const palmId = id(data.palmId, 'palmId');

  await farmAccess(user.uid, user.role, farmId, user.farmId);

  const treatmentMethod = stringField(
    data.treatmentMethod,
    'treatmentMethod',
    100
  );

  const notes = optionalText(data.notes, 'notes', 1000);

  const treatmentDate = stringField(
    data.treatmentDate,
    'treatmentDate',
    10
  );

  if (!/^\d{4}-\d{2}-\d{2}$/.test(treatmentDate)) {
    throw new HttpsError(
      'invalid-argument',
      'treatmentDate must be YYYY-MM-DD.'
    );
  }

  const parsed = new Date(`${treatmentDate}T00:00:00.000Z`);

  if (
    Number.isNaN(parsed.getTime()) ||
    parsed.toISOString().slice(0, 10) !== treatmentDate ||
    treatmentDate > new Date().toISOString().slice(0, 10)
  ) {
    throw new HttpsError(
      'invalid-argument',
      'treatmentDate must be a valid date, not in the future.'
    );
  }

  const allowed = [
    'farmId',
    'palmId',
    'treatmentMethod',
    'treatmentDate',
    'notes'
  ];

  if (Object.keys(data).some(key => !allowed.includes(key))) {
    throw new HttpsError(
      'invalid-argument',
      'Unexpected treatment fields.'
    );
  }

  // Generate record IDs only once.
  const treatmentId = db().ref('treatmentRecords').push().key;
  const historyId = db().ref('monitoringHistory').push().key;

  if (!treatmentId || !historyId) {
    throw new HttpsError(
      'internal',
      'Unable to generate record IDs.'
    );
  }

  const timestamp = Date.now();
  const endpoint = databaseEndpoint();

  // Use administrative credentials for REST requests.
  const emulator = !!process.env.FIREBASE_DATABASE_EMULATOR_HOST;
  const token = emulator
    ? null
    : (await applicationDefault().getAccessToken()).access_token;

  const authHeaders: Record<string, string> = emulator
  ? {Authorization: 'Bearer owner'}
  : {Authorization: `Bearer ${token}`};

  // Retry when another operation changes the database.
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

  console.error('Treatment REST read failed:', {
    status: response.status,
    error: errorBody,
  });

  throw new HttpsError(
    'internal',
    'Unable to read treatment data.'
  );
}

    const etag = response.headers.get('etag');
    const root = await response.json() as DbObject | null;

    if (!etag || !root) {
      throw new HttpsError(
        'internal',
        'Unable to read the current database state.'
      );
    }

    const farm = root.farms?.[farmId];
    const palm = root.palms?.[farmId]?.[palmId];

    if (!farm || !palm) {
      throw new HttpsError(
        'not-found',
        'Farm or palm not found.'
      );
    }

    if (farm.deleting || palm.healthStatus !== 'Suspected') {
      throw new HttpsError(
        'failed-precondition',
        'Palm must be Suspected and accessible.'
      );
    }

    // Verify access again using the current database state.
    const hasAccess = user.role === 'FarmOwner'
      ? farm.ownerId === user.uid
      : (
        user.role === 'Farmer' &&
        root.users?.[user.uid]?.farmId === farmId
      );

    if (!hasAccess) {
      throw new HttpsError(
        'permission-denied',
        'No access to this farm.'
      );
    }

    // Save the treatment.
    root.treatmentRecords ??= {};
    root.treatmentRecords[farmId] ??= {};
    root.treatmentRecords[farmId][palmId] ??= {};

    root.treatmentRecords[farmId][palmId][treatmentId] = {
      treatmentDate,
      treatmentMethod,
      ...(notes ? {notes} : {}),
    };

    // Update the palm status.
    palm.healthStatus = 'UnderMonitoring';

    // Record the status change in monitoring history.
    root.monitoringHistory ??= {};
    root.monitoringHistory[farmId] ??= {};
    root.monitoringHistory[farmId][palmId] ??= {};

    root.monitoringHistory[farmId][palmId][historyId] = {
      healthStatus: 'UnderMonitoring',
      timestamp,
    };

    // Write only if the database has not changed.
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
      return {
        success: true,
        treatmentId,
      };
    }

    // A concurrent change occurred; read again and retry.
    if (writeResponse.status === 412) {
      continue;
    }

    throw new HttpsError(
      'internal',
      'Unable to save treatment.'
    );
  }

  throw new HttpsError(
    'aborted',
    'Treatment could not be saved due to concurrent updates. Please retry.'
  );
});
