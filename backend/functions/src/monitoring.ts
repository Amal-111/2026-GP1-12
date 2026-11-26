import {onRequest} from 'firebase-functions/v2/https';
import {timingSafeEqual} from 'node:crypto';
import {onSchedule} from 'firebase-functions/v2/scheduler';
import {defineSecret} from 'firebase-functions/params';
import {db, id, findDevicePalm} from './common';

const gatewayKey = defineSecret('RASD_GATEWAY_KEY');
const REGION = 'us-central1';
const CONFIRMATIONS = 3;
const OFFLINE_AFTER_MS = 15 * 60 * 1000;
type Result = 'Healthy' | 'Suspected';

function validGatewayKey(provided: string | undefined, expected: string): boolean {
  if (!provided || !expected) return false;
  const a = Buffer.from(provided, 'utf8');
  const b = Buffer.from(expected, 'utf8');
  return a.length === b.length && timingSafeEqual(a, b);
}
function validVibrationData(value: unknown): value is number[] {
  return Array.isArray(value) && value.length > 0 && value.length <= 2048 &&
    value.every(sample => typeof sample === 'number' && Number.isFinite(sample));
}
function validNumber(value: unknown, min: number, max: number): value is number {
  return typeof value === 'number' && Number.isFinite(value) && value >= min && value <= max;
}

// Gateway payload remains unchanged. Only the Firebase storage layout changes.
export const receiveSensorData = onRequest(
  {region: REGION, secrets: [gatewayKey], maxInstances: 10},
  async (req, res) => {
    if (req.method !== 'POST') {res.status(405).send('Method not allowed'); return;}
    if (!validGatewayKey(req.get('x-rasd-gateway-key'), gatewayKey.value())) {
      res.status(401).send('Unauthorized'); return;
    }
    const data = req.body;
    if (!data || typeof data !== 'object' || Array.isArray(data)) {
      res.status(400).send('Invalid payload'); return;
    }
    let deviceId: string;
    try {deviceId = id(data.deviceId, 'deviceId');} catch {res.status(400).send('Invalid deviceId'); return;}
    const {temperature, humidity, result, vibrationData} = data;
    if (!validNumber(temperature, -40, 85) || !validNumber(humidity, 0, 100) ||
      (result !== 'Healthy' && result !== 'Suspected')) {
      res.status(400).send('Invalid readings/result'); return;
    }
    if (vibrationData !== undefined && !validVibrationData(vibrationData)) {
      res.status(400).send('Invalid vibrationData'); return;
    }

    const now = Date.now();
    const readingKey = db().ref('farms').push().key!;
    const historyKey = db().ref('farms').push().key!;
    const alertKey = db().ref('farms').push().key!;

    // Prototype consistency: root transaction protects the embedded palm.
    // Do not deploy before concurrency testing.
    let applied = false;
    const tx = await db().ref().transaction(root => {
      applied = false;
      // An empty local cache must reach the server's compare-and-swap.
      // A populated server root is returned on conflict and retried.
      if (root === null) return null;
      // Find the palm that this sensor is paired with.
      const state = findDevicePalm(root, deviceId);
      if (!state) return;
      const farm = root.farms?.[state.farmId];
      const palm = farm?.palms?.[state.palmId];
      const device = palm?.monitoringDevice;
      if (!farm || farm.deleting || !palm || palm.deviceId !== deviceId ||
          device?.deviceId !== deviceId) return;
      if (typeof device.lastSeen === 'number' && device.lastSeen > now) return;
      device.temperature = temperature;
      device.humidity = humidity;
      device.lastSeen = now;
      device.connectionStatus = 'Online';
      device.sensorReadings ??= {};
      device.sensorReadings[readingKey] = {
        timestamp: now, temperature, humidity,
        ...(vibrationData !== undefined ? {vibrationData} : {}),
        detectionResult: {result},
      };
      // The confirmation streak is stored on the palm's monitoring device.
      const count = device.lastResult === result
        ? Math.min((device.count ?? 0) + 1, CONFIRMATIONS) : 1;
      device.lastResult = result;
      device.count = count;
      if (count >= CONFIRMATIONS && palm.healthStatus !== result) {
        palm.healthStatus = result as Result;
        palm.monitoringHistory ??= {};
        palm.monitoringHistory[historyKey] = {
          eventType: 'Monitoring', healthStatus: result, timestamp: now,
        };
        if (result === 'Suspected') {
          palm.alerts ??= {};
          palm.alerts[alertKey] = {
            palmId: state.palmId, alertType: 'PossiblePestDetected', timestamp: now,
          };
        }
      }
      applied = true;
      return root;
    }, undefined, false);
    if (!tx.committed || !applied) {res.status(409).json({error: 'Device not paired or farm unavailable'}); return;}
    res.status(200).json({success: true});
  },
);

export const checkOfflineDevices = onSchedule(
  {schedule: 'every 5 minutes', timeZone: 'Etc/UTC', region: REGION},
  async () => {
    const now = Date.now();
    // Search every palm's monitoring device for online sensors that stopped sending.
    const farmsSnapshot = await db().ref('farms').get();
    const candidates: Record<string, string> = {};
    for (const farm of Object.values(farmsSnapshot.val() ?? {}) as any[]) {
      for (const palm of Object.values(farm?.palms ?? {}) as any[]) {
        const device = palm?.monitoringDevice;
        if (device?.deviceId && device.connectionStatus === 'Online' &&
            typeof device.lastSeen === 'number' && now - device.lastSeen >= OFFLINE_AFTER_MS) {
          candidates[device.deviceId] = db().ref('farms').push().key!;
        }
      }
    }
    if (!Object.keys(candidates).length) return;
    await db().ref().transaction(root => {
      // Let the server retry a cold-cache transaction with the current root.
      if (root === null) return null;
      let changed = false;
      for (const [deviceId, alertId] of Object.entries(candidates)) {
        const state = findDevicePalm(root, deviceId);
        if (!state) continue;
        const farm = root.farms?.[state.farmId];
        const palm = farm?.palms?.[state.palmId];
        const device = palm?.monitoringDevice;
        if (!farm || farm.deleting || !palm || palm.deviceId !== deviceId ||
            device?.deviceId !== deviceId || device.connectionStatus !== 'Online' ||
            typeof device.lastSeen !== 'number' || now - device.lastSeen < OFFLINE_AFTER_MS) continue;
        device.connectionStatus = 'Offline';
        palm.alerts ??= {};
        palm.alerts[alertId] = {palmId: state.palmId, alertType: 'SensorOffline', timestamp: now};
        changed = true;
      }
      return changed ? root : undefined;
    }, undefined, false);
  },
);
