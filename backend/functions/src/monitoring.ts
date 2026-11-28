import {onRequest} from 'firebase-functions/v2/https';
import {createHash, timingSafeEqual} from 'node:crypto';
import {onSchedule} from 'firebase-functions/v2/scheduler';
import {defineSecret} from 'firebase-functions/params';
import {error} from 'firebase-functions/logger';
import {db, id, findDevicePalm} from './common';

const gatewayKey = defineSecret('RASD_GATEWAY_KEY');
const REGION = 'us-central1';
const CONFIRMATIONS = 3;
const OFFLINE_AFTER_MS = 15 * 60 * 1000;
const OFFLINE_FARM_CONCURRENCY = 4;
const MAX_DEVICE_ROUTES = 1024;
type Result = 'Healthy' | 'Suspected';
type DeviceRoute = NonNullable<ReturnType<typeof findDevicePalm>>;
const deviceRoutes = new Map<string, DeviceRoute>();

function rememberDeviceRoute(deviceId: string, route: DeviceRoute): void {
  deviceRoutes.delete(deviceId);
  deviceRoutes.set(deviceId, route);
  if (deviceRoutes.size > MAX_DEVICE_ROUTES) {
    const oldest = deviceRoutes.keys().next();
    if (!oldest.done) deviceRoutes.delete(oldest.value);
  }
}

async function resolveDeviceRoute(deviceId: string): Promise<DeviceRoute | null> {
  const farms = (await db().ref('farms').get()).val();
  return findDevicePalm({farms}, deviceId);
}

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
    const {temperature, humidity, result, vibrationData, readingId} = data;
    if (!validNumber(temperature, -40, 85) || !validNumber(humidity, 0, 100) ||
      (result !== 'Healthy' && result !== 'Suspected')) {
      res.status(400).send('Invalid readings/result'); return;
    }
    if (vibrationData !== undefined && !validVibrationData(vibrationData)) {
      res.status(400).send('Invalid vibrationData'); return;
    }
    if (readingId !== undefined && (typeof readingId !== 'string' ||
        readingId.length < 1 || readingId.length > 128 || /[^A-Za-z0-9_-]/.test(readingId))) {
      res.status(400).send('Invalid readingId'); return;
    }

    const now = Date.now();
    const readingKey = readingId === undefined ? db().ref('farms').push().key! :
      'reading_' + createHash('sha256').update(JSON.stringify([deviceId, readingId])).digest('hex');
    const historyKey = db().ref('farms').push().key!;
    const alertKey = db().ref('farms').push().key!;

    let route = deviceRoutes.get(deviceId) ?? await resolveDeviceRoute(deviceId);
    for (let attempt = 0; route && attempt < 2; attempt++) {
      const {farmId, palmId} = route;
      let assigned = false;
      let applied = false;
      let duplicate = false;
      let conflict = false;
      // Include the farm's deletion flag in the same transaction as the palm.
      const tx = await db().ref(`farms/${farmId}`).transaction(farm => {
        assigned = false;
        applied = false;
        duplicate = false;
        conflict = false;
        const palm = farm?.palms?.[palmId];
        const device = palm?.monitoringDevice;
        if (!farm || farm.deleting || !palm || palm.deviceId !== deviceId ||
            device?.deviceId !== deviceId) {
          // Confirm even a null or stale local snapshot with the server.
          return farm;
        }
        assigned = true;
        const existing = readingId === undefined ? undefined : device.sensorReadings?.[readingKey];
        if (existing !== undefined) {
          const storedVibration = existing?.vibrationData;
          const sameVibration = vibrationData === undefined ? storedVibration === undefined :
            Array.isArray(storedVibration) && storedVibration.length === vibrationData.length &&
              vibrationData.every((sample: number, index: number) => sample === storedVibration[index]);
          duplicate = existing?.temperature === temperature && existing?.humidity === humidity &&
            existing?.detectionResult?.result === result && sameVibration;
          conflict = !duplicate;
          // Confirm the stored reading against the server without changing the farm.
          return farm;
        }
        if (typeof device.lastSeen === 'number' && device.lastSeen > now) return farm;
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
              palmId, alertType: 'PossiblePestDetected', timestamp: now,
            };
          }
        }
        applied = true;
        return farm;
      }, undefined, false);

      if (tx.committed && (applied || duplicate)) {
        rememberDeviceRoute(deviceId, route);
        res.status(200).json({success: true});
        return;
      }
      if (tx.committed && conflict) {
        res.status(409).json({error: 'readingId already used with different measurements'});
        return;
      }
      if (assigned) break; // An older reading is rejected without rerouting it.

      // A concurrent request may already have refreshed the hint.
      if (deviceRoutes.get(deviceId) === route) deviceRoutes.delete(deviceId);
      if (attempt === 0) route = await resolveDeviceRoute(deviceId);
    }
    res.status(409).json({error: 'Device not paired or farm unavailable'});
  },
);

export const checkOfflineDevices = onSchedule(
  {schedule: 'every 5 minutes', timeZone: 'Etc/UTC', region: REGION},
  async () => {
    const now = Date.now();
    // Search every palm's monitoring device for online sensors that stopped sending.
    const farmsSnapshot = await db().ref('farms').get();
    const candidatesByFarm = new Map<string, {palmId: string; deviceId: string; alertId: string}[]>();
    for (const [farmId, farm] of Object.entries(farmsSnapshot.val() ?? {})) {
      const candidates = [];
      for (const [palmId, palm] of Object.entries((farm as any)?.palms ?? {})) {
        const device = (palm as any)?.monitoringDevice;
        if (device?.deviceId && device.connectionStatus === 'Online' &&
            typeof device.lastSeen === 'number' && now - device.lastSeen >= OFFLINE_AFTER_MS) {
          candidates.push({palmId, deviceId: device.deviceId, alertId: farmsSnapshot.ref.push().key!});
        }
      }
      if (candidates.length) candidatesByFarm.set(farmId, candidates);
    }

    const queue = candidatesByFarm.entries();
    let failures = 0;
    const processFarms = async () => {
      for (const [farmId, candidates] of queue) {
        try {
          await farmsSnapshot.ref.child(farmId).transaction(farm => {
            // Confirm a cold or stale local snapshot against the server.
            if (!farm || farm.deleting) return farm;
            for (const {palmId, deviceId, alertId} of candidates) {
              const palm = farm.palms?.[palmId];
              const device = palm?.monitoringDevice;
              if (!palm || palm.deviceId !== deviceId || device?.deviceId !== deviceId ||
                  device.connectionStatus !== 'Online' || typeof device.lastSeen !== 'number' ||
                  now - device.lastSeen < OFFLINE_AFTER_MS) continue;
              device.connectionStatus = 'Offline';
              palm.alerts ??= {};
              palm.alerts[alertId] = {palmId, alertType: 'SensorOffline', timestamp: now};
            }
            return farm;
          }, undefined, false);
        } catch {
          failures++;
          error('Offline device check failed for farm', {farmId, reason: 'RTDB transaction failed'});
        }
      }
    };
    await Promise.all(Array.from({length: Math.min(OFFLINE_FARM_CONCURRENCY, candidatesByFarm.size)}, processFarms));
    if (failures) throw new Error(`Offline device check failed for ${failures} farm(s)`);
  },
);
