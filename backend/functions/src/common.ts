import {getDatabase} from 'firebase-admin/database';
import {getStorage} from 'firebase-admin/storage';
import {HttpsError, CallableRequest} from 'firebase-functions/v2/https';

export const db = () => getDatabase();

// Request validation

export type Data = Record<string, unknown>;

// Read a request object and reject arrays or missing values.
export function object(value: unknown): Data {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    throw new HttpsError('invalid-argument', 'Expected an object.');
  }

  return value as Data;
}

// Required strings are trimmed before checking their length.
export function stringField(value: unknown, field: string, max = 150): string {
  if (typeof value !== 'string') {
    throw new HttpsError('invalid-argument', `Invalid ${field}.`);
  }

  const trimmedValue = value.trim();
  if (!trimmedValue || trimmedValue.length > max) {
    throw new HttpsError('invalid-argument', `Invalid ${field}.`);
  }

  return trimmedValue;
}

// Optional text is checked against the length limit before trimming.
export function optionalText(value: unknown, field: string, max = 1000): string | undefined {
  if (value === undefined || value === null || value === '') {
    return undefined;
  }
  if (typeof value !== 'string' || value.length > max) {
    throw new HttpsError('invalid-argument', `Invalid ${field}.`);
  }

  return value.trim() || undefined;
}

// Validate a finite coordinate within the given range.
export function coord(value: unknown, field: string, min: number, max: number): number {
  if (typeof value !== 'number' || !Number.isFinite(value) || value < min || value > max) {
    throw new HttpsError('invalid-argument', `Invalid ${field}.`);
  }

  return value;
}

// Validate a safe integer within the given range.
export function integer(value: unknown, field: string, min: number, max = 1000000): number {
  if (!Number.isSafeInteger(value) || (value as number) < min || (value as number) > max) {
    throw new HttpsError('invalid-argument', `Invalid ${field}.`);
  }

  return value as number;
}

// Validate an ID before using it as a Realtime Database key.
export function id(value: unknown, field: string): string {
  const key = stringField(value, field, 128);

  // RTDB keys reject reserved punctuation and ASCII control characters.
  // eslint-disable-next-line no-control-regex
  if (/[.#$[\]/\u0000-\u001f\u007f]/.test(key)) {
    throw new HttpsError('invalid-argument', `Invalid ${field}.`);
  }

  return key;
}

// Authentication and farm access

// Load the signed-in user's authorized role and farm assignment.
export async function actor(
  request: CallableRequest<unknown>
): Promise<{uid: string; role: string; farmId?: string}> {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Please sign in.');
  }

  const uid = request.auth.uid;
  const profileSnapshot = await db().ref(`users/${uid}`).get();
  const profile = profileSnapshot.val();
  if (!profile || !['FarmOwner', 'Farmer'].includes(profile.role)) {
    throw new HttpsError('permission-denied', 'User profile not authorized.');
  }

  return {uid, role: profile.role, farmId: profile.farmId};
}

// Allow the owner or, where permitted, a farmer assigned to this farm.
export async function farmAccess(
  uid: string,
  role: string,
  farmId: string,
  farmerFarmId?: string,
  ownerOnly = false
): Promise<void> {
  const ownerSnapshot = await db().ref(`farms/${farmId}/ownerId`).get();
  const ownerId = ownerSnapshot.val();
  if (!ownerId) {
    throw new HttpsError('not-found', 'Farm not found.');
  }

  const isOwner = role === 'FarmOwner' && ownerId === uid;
  if (isOwner) {
    return;
  }

  const isAssignedFarmer = !ownerOnly && role === 'Farmer' && farmerFarmId === farmId;
  if (isAssignedFarmer) {
    return;
  }

  throw new HttpsError('permission-denied', 'No access to this farm.');
}

// Farm photo validation and cleanup

const farmPhotoBucket = 'rasd-6a036.firebasestorage.app';
const farmPhotoExtensions = ['jpg', 'jpeg', 'png', 'webp'];

// Validate the photo URL, allowing local HTTP for the Storage Emulator.
export function optionalFarmImage(value: unknown): string | undefined {
  if (value === undefined || value === null || value === '') {
    return undefined;
  }

  const imageUrl = stringField(value, 'farmImage', 2048);
  let url: URL;

  try {
    url = new URL(imageUrl);
  } catch {
    throw new HttpsError(
      'invalid-argument',
      'farmImage must be a valid URL.'
    );
  }

  const isHttps = url.protocol === 'https:';
  const emulatorPort = process.env.FIREBASE_STORAGE_EMULATOR_HOST
    ?.match(/:(\d+)\/?$/)?.[1];
  const isLocalEmulator =
    emulatorPort !== undefined &&
    url.protocol === 'http:' &&
    ['10.0.2.2', '127.0.0.1', 'localhost'].includes(url.hostname) &&
    url.port === emulatorPort &&
    url.pathname.startsWith('/v0/b/');

  if (!isHttps && !isLocalEmulator) {
    throw new HttpsError(
      'invalid-argument',
      'farmImage must be an HTTPS URL.'
    );
  }

  return imageUrl;
}

// Delete each supported image variant for this farm.
export async function deleteFarmImages(ownerId: string, farmId: string): Promise<void> {
  const bucket = getStorage().bucket(farmPhotoBucket);
  for (const extension of farmPhotoExtensions) {
    await bucket.file(`farmImages/${ownerId}/${farmId}.${extension}`)
      .delete({ignoreNotFound: true});
  }
}

// Resolve a managed Storage object belonging to this owner and farm.
function farmPhotoPath(value: unknown, ownerId: string, farmId: string): string | undefined {
  if (typeof value !== 'string' || !value) {
    return;
  }

  try {
    const pathSegments = new URL(value).pathname.split('/');
    if (
      pathSegments.length !== 6 ||
      pathSegments.slice(1, 5).join('/') !== `v0/b/${farmPhotoBucket}/o`
    ) {
      return;
    }

    const objectPath = decodeURIComponent(pathSegments[5]);
    const farmPathPrefix = `farmImages/${ownerId}/${farmId}.`;
    if (
      objectPath.startsWith(farmPathPrefix) &&
      farmPhotoExtensions.includes(objectPath.slice(farmPathPrefix.length))
    ) {
      return objectPath;
    }
  } catch {
    // External or malformed legacy references have no managed object to delete.
  }

  return undefined;
}

// Capture the old photo generation before returning its cleanup operation.
export async function prepareFarmPhotoCleanup(
  ownerId: string, farmId: string, previous: unknown, next: unknown
): Promise<(() => Promise<void>) | undefined> {
  const previousPhotoPath = farmPhotoPath(previous, ownerId, farmId);
  if (!previousPhotoPath || previousPhotoPath === farmPhotoPath(next, ownerId, farmId)) {
    return;
  }

  const bucket = getStorage().bucket(farmPhotoBucket);
  const [metadata] = await bucket.file(previousPhotoPath).getMetadata().catch(error => {
    if (Number(error.code) === 404) {
      return [undefined];
    }
    throw error;
  });

  if (metadata?.generation === undefined) {
    return;
  }

  return async () => {
    await bucket.file(previousPhotoPath, {
      // Delete only the generation captured before the farm update.
      preconditionOpts: {ifGenerationMatch: metadata.generation},
    }).delete({ignoreNotFound: true}).catch(error => {
      if (Number(error.code) !== 412) {
        throw error;
      }
      // A new upload replaced the previous generation.
    });
  };
}

// Device lookup

// Find the farm and palm paired with a sensor by scanning embedded palm records.
export function findDevicePalm(root: any, deviceId: string): {farmId: string; palmId: string} | null {
  const farms = root?.farms ?? {};
  for (const [farmId, farm] of Object.entries(farms) as [string, any][]) {
    for (const [palmId, palm] of Object.entries(farm?.palms ?? {}) as [string, any][]) {
      if (palm?.deviceId === deviceId) {
        return {farmId, palmId};
      }
    }
  }

  return null;
}
