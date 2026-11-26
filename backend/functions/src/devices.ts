import {onCall, HttpsError} from 'firebase-functions/v2/https';
import {actor, db, farmAccess, id, object, findDevicePalm} from './common';

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
  let paired = false;
  const tx = await db().ref().transaction(root => {
    paired = false;
    // Let the server compare the initially empty local cache using its current state.
    if (root === null) return null;
    const farm = root.farms?.[farmId];
    const palm = farm?.palms?.[palmId];
    if (!farm || farm.deleting || !palm || palm.deviceId) return;
    // Recheck current membership inside the transaction. The farmer may have
    // been removed after the initial farmAccess() lookup.
    const allowed = user.role === 'FarmOwner'
      ? (root.users?.[user.uid]?.role === 'FarmOwner' && farm.ownerId === user.uid)
      : (user.role === 'Farmer' &&
         root.users?.[user.uid]?.role === 'Farmer' &&
         root.users[user.uid].farmId === farmId);
    if (!allowed) return;
    // A sensor can be paired with only one palm.
    if (findDevicePalm(root, deviceId)) return;
    palm.monitoringDevice = {deviceId, connectionStatus: 'Offline', farmId, palmId};
    palm.deviceId = deviceId;
    paired = true;
    return root;
  }, undefined, false);
  if (!tx.committed || !paired) throw new HttpsError('failed-precondition', 'Palm/device unavailable or already paired.');
  return {success: true};
});

// A registered palm must always have a paired sensor. Remove the palm to release it.
export const disconnectDevice = onCall(options, async (request) => {
  await actor(request);
  throw new HttpsError('failed-precondition',
    'A sensor cannot be disconnected from a registered palm. Delete the palm first.');
});
