import {onCall, HttpsError} from 'firebase-functions/v2/https';
import {actor, db, farmAccess, id, object, findDevicePalm} from './common';

const options = {region: 'us-central1', maxInstances: 10};

// Pair an available sensor with a registered palm.
export const connectDevice = onCall(options, async (request) => {
  const user = await actor(request);
  const data = object(request.data);
  const farmId = id(data.farmId, 'farmId');
  const palmId = id(data.palmId, 'palmId');
  const deviceId = id(data.deviceId, 'deviceId');

  await farmAccess(user.uid, user.role, farmId, user.farmId);

  // Use a root transaction to check membership and uniqueness across farms.
  let pairingApplied = false;
  const transaction = await db().ref().transaction(root => {
    pairingApplied = false;

    // Let the server compare the initially empty local cache using its current state.
    if (root === null) {
      return null;
    }

    const farm = root.farms?.[farmId];
    const palm = farm?.palms?.[palmId];

    if (!farm || farm.deleting || !palm || palm.deviceId) {
      return;
    }

    // Recheck current membership inside the transaction. The farmer may have
    // been removed after the initial farmAccess() lookup.
    const currentProfile = root.users?.[user.uid];
    if (user.role === 'FarmOwner') {
      if (currentProfile?.role !== 'FarmOwner' || farm.ownerId !== user.uid) {
        return;
      }
    } else if (
      user.role !== 'Farmer' ||
      currentProfile?.role !== 'Farmer' ||
      currentProfile.farmId !== farmId
    ) {
      return;
    }

    // Check all farms before assigning the sensor to this palm.
    if (findDevicePalm(root, deviceId)) {
      return;
    }

    palm.monitoringDevice = {
      deviceId,
      connectionStatus: 'Offline',
      farmId,
      palmId,
    };
    palm.deviceId = deviceId;
    pairingApplied = true;
    return root;
  }, undefined, false);

  if (!transaction.committed || !pairingApplied) {
    throw new HttpsError(
      'failed-precondition',
      'Palm/device unavailable or already paired.'
    );
  }

  return {success: true};
});

// A registered palm must always have a paired sensor. Remove the palm to release it.
export const disconnectDevice = onCall(options, async (request) => {
  await actor(request);
  throw new HttpsError(
    'failed-precondition',
    'A sensor cannot be disconnected from a registered palm. Delete the palm first.'
  );
});
