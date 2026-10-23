import {getDatabase} from 'firebase-admin/database';
import {HttpsError, CallableRequest} from 'firebase-functions/v2/https';

export const db = () => getDatabase();
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
  if (/[.#$\[\]/\u0000-\u001f\u007f]/.test(s)) throw new HttpsError('invalid-argument', `Invalid ${field}.`);
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

  const isLocalEmulator =
    !!process.env.FIREBASE_STORAGE_EMULATOR_HOST &&
    url.protocol === 'http:' &&
    ['10.0.2.2', '127.0.0.1', 'localhost'].includes(url.hostname) &&
    url.port === '9199' &&
    url.pathname.startsWith('/v0/b/');

  if (!isHttps && !isLocalEmulator) {
    throw new HttpsError(
      'invalid-argument',
      'farmImage must be an HTTPS URL.'
    );
  }

  return s;
}

