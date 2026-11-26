import {getDatabase} from 'firebase-admin/database';
import {getStorage} from 'firebase-admin/storage';
import {HttpsError, CallableRequest} from 'firebase-functions/v2/https';

export const db = () => getDatabase();
const farmPhotoBucket = 'rasd-6a036.firebasestorage.app';
const farmPhotoExtensions = ['jpg', 'jpeg', 'png', 'webp'];

export async function deleteFarmImages(ownerId: string, farmId: string): Promise<void> {
  const bucket = getStorage().bucket(farmPhotoBucket);
  for (const extension of farmPhotoExtensions) {
    await bucket.file(`farmImages/${ownerId}/${farmId}.${extension}`)
      .delete({ignoreNotFound: true});
  }
}

function farmPhotoPath(value: unknown, ownerId: string, farmId: string): string | undefined {
  if (typeof value !== 'string' || !value) return;
  try {
    const parts = new URL(value).pathname.split('/');
    if (parts.length !== 6 || parts.slice(1, 5).join('/') !==
      `v0/b/${farmPhotoBucket}/o`) return;
    const path = decodeURIComponent(parts[5]);
    const prefix = `farmImages/${ownerId}/${farmId}.`;
    if (path.startsWith(prefix) &&
      farmPhotoExtensions.includes(path.slice(prefix.length))) return path;
  } catch {
    // External or malformed legacy references have no managed object to delete.
  }
  return undefined;
}

export async function prepareFarmPhotoCleanup(
  ownerId: string, farmId: string, previous: unknown, next: unknown
): Promise<(() => Promise<void>) | undefined> {
  const path = farmPhotoPath(previous, ownerId, farmId);
  if (!path || path === farmPhotoPath(next, ownerId, farmId)) return;
  const bucket = getStorage().bucket(farmPhotoBucket);
  const [metadata] = await bucket.file(path).getMetadata().catch(error => {
    if (Number(error.code) === 404) return [undefined];
    throw error;
  });
  if (metadata?.generation === undefined) return;
  return async () => {
    await bucket.file(path, {
      preconditionOpts: {ifGenerationMatch: metadata.generation},
    }).delete({ignoreNotFound: true}).catch(error => {
      if (Number(error.code) !== 412) throw error;
      // A new upload replaced the previous generation.
    });
  };
}
export type Data = Record<string, unknown>;
export function object(value: unknown): Data {
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new HttpsError('invalid-argument', 'Expected an object.');
  return value as Data;
}
export function stringField(v: unknown, field: string, max = 150): string {
  if (typeof v !== 'string' || !v.trim() || v.trim().length > max) throw new HttpsError('invalid-argument', `Invalid ${field}.`);
  return v.trim();
}
export function optionalText(v: unknown, field: string, max = 1000): string | undefined {
  if (v === undefined || v === null || v === '') return undefined;
  if (typeof v !== 'string' || v.length > max) throw new HttpsError('invalid-argument', `Invalid ${field}.`);
  return v.trim() || undefined;
}
export function coord(v: unknown, field: string, min: number, max: number): number {
  if (typeof v !== 'number' || !Number.isFinite(v) || v < min || v > max) throw new HttpsError('invalid-argument', `Invalid ${field}.`);
  return v;
}
export function integer(v: unknown, field: string, min: number, max = 1000000): number {
  if (!Number.isSafeInteger(v) || (v as number) < min || (v as number) > max) throw new HttpsError('invalid-argument', `Invalid ${field}.`);
  return v as number;
}
export function id(v: unknown, field: string): string {
  const s = stringField(v, field, 128);
  // RTDB keys cannot contain ASCII control characters.
  // eslint-disable-next-line no-control-regex
  if (/[.#$[\]/\u0000-\u001f\u007f]/.test(s)) throw new HttpsError('invalid-argument', `Invalid ${field}.`);
  return s;
}
export async function actor(request: CallableRequest<unknown>): Promise<{uid: string; role: string; farmId?: string}> {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Please sign in.');
  const uid = request.auth.uid;
  const snap = await db().ref(`users/${uid}`).get();
  const u = snap.val();
  if (!u || !['FarmOwner', 'Farmer'].includes(u.role)) throw new HttpsError('permission-denied', 'User profile not authorized.');
  return {uid, role: u.role, farmId: u.farmId};
}
export async function farmAccess(uid: string, role: string, farmId: string, farmerFarmId?: string, ownerOnly = false): Promise<void> {
  const snap = await db().ref(`farms/${farmId}/ownerId`).get();
  const ownerId = snap.val();
  if (!ownerId) throw new HttpsError('not-found', 'Farm not found.');
  if (role === 'FarmOwner' && ownerId === uid) return;
  if (!ownerOnly && role === 'Farmer' && farmerFarmId === farmId) return;
  throw new HttpsError('permission-denied', 'No access to this farm.');
}

export function optionalFarmImage(v: unknown): string | undefined {
  if (v === undefined || v === null || v === '') {
    return undefined;
  }

  const s = stringField(v, 'farmImage', 2048);

  let url: URL;

  try {
    url = new URL(s);
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

  return s;
}



// Find the farm and palm that a sensor is paired with by searching the farms.
// Used instead of a separate device index (monitoringState).
export function findDevicePalm(root: any, deviceId: string): {farmId: string; palmId: string} | null {
  const farms = root?.farms ?? {};
  for (const [farmId, farm] of Object.entries(farms) as [string, any][]) {
    for (const [palmId, palm] of Object.entries(farm?.palms ?? {}) as [string, any][]) {
      if (palm?.deviceId === deviceId) return {farmId, palmId};
    }
  }
  return null;
}
