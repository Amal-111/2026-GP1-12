import {onCall, HttpsError} from 'firebase-functions/v2/https';
import {actor, db, farmAccess, id, object} from './common';

const options = {region: 'us-central1', maxInstances: 10};

// These transactions span the RTDB root for cross-path consistency.
// Prototype-only: redesign for scale before production deployment.
export const connectDevice = onCall(options, async (request) => {
  const user = await actor(request);
  const d = object(request.data);
  const farmId = id(d.farmId, 'farmId');
  const palmId = id(d.palmId, 'palmId');
  const deviceId = id(d.deviceId, 'deviceId');
  await farmAccess(user.uid, user.role, farmId, user.farmId);
  const tx = await db().ref().transaction(root => {
    const farm = root?.farms?.[farmId];
    const palm = root?.palms?.[farmId]?.[palmId];
    if (!farm || farm.deleting || !palm || palm.deviceId) return;
    // Recheck current membership inside the transaction. The farmer may have
    // been removed after the initial farmAccess() lookup.
    const allowed = user.role === 'FarmOwner'
      ? (root.users?.[user.uid]?.role === 'FarmOwner' && farm.ownerId === user.uid)
      : (user.role === 'Farmer' &&
         root.users?.[user.uid]?.role === 'Farmer' &&
         root.users[user.uid].farmId === farmId);
    if (!allowed) return;
    root.monitoringDevices ??= {};
    const existing = root.monitoringDevices[deviceId];
    if (existing && (existing.farmId || existing.palmId)) return;
    // Paired device starts Offline until its first authenticated reading.
    root.monitoringDevices[deviceId] = {connectionStatus: 'Offline', farmId, palmId};
    palm.deviceId = deviceId;
    if (root.monitoringState) delete root.monitoringState[deviceId];
    return root;
  }, undefined, false);
  if (!tx.committed) throw new HttpsError('failed-precondition', 'Palm/device unavailable or already paired.');
  return {success: true};
});

// A registered palm must always have a paired sensor. Remove the palm to release it.
export const disconnectDevice = onCall(options, async (request) => {
  await actor(request);
  throw new HttpsError('failed-precondition',
    'A sensor cannot be disconnected from a registered palm. Delete the palm first.');
});
