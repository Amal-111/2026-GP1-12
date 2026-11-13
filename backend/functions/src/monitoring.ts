import {onRequest} from 'firebase-functions/v2/https';
import {timingSafeEqual} from 'node:crypto';
import {onSchedule} from 'firebase-functions/v2/scheduler';
import {defineSecret} from 'firebase-functions/params';
import {db, id} from './common';

const gatewayKey = defineSecret('RASD_GATEWAY_KEY');
const REGION = 'us-central1';
// Provisional values. Calibrate with real sensor/TinyML testing.
const CONFIRMATIONS = 3;
const OFFLINE_AFTER_MS = 15 * 60 * 1000;

type Result = 'Healthy' | 'Suspected';

// Compare configured gateway credentials without a timing-dependent string match.
function validGatewayKey(provided: string | undefined, expected: string): boolean {
  if (!provided || !expected) return false;
  const a = Buffer.from(provided, 'utf8');
  const b = Buffer.from(expected, 'utf8');
  return a.length === b.length && timingSafeEqual(a, b);
}


// Accept bounded numeric vibration samples without changing older gateways.
function validVibrationData(value: unknown): value is number[] {
  return Array.isArray(value) &&
    value.length > 0 &&
    value.length <= 2048 &&
    value.every(sample =>
      typeof sample === 'number' &&
      Number.isFinite(sample)
    );
}
function validNumber(value: unknown, min: number, max: number): value is number {
  return typeof value === 'number' && Number.isFinite(value) && value >= min && value <= max;
}
function appendHistory(root: any, farmId: string, palmId: string, status: string, timestamp: number, key: string): void {
  root.monitoringHistory ??= {};
  root.monitoringHistory[farmId] ??= {};
  root.monitoringHistory[farmId][palmId] ??= {};

  root.monitoringHistory[farmId][palmId][key] = {
    eventType: 'Monitoring',
    healthStatus: status,
    timestamp,
  };
}
function appendAlert(root: any, farmId: string, palmId: string, alertType: string, timestamp: number, key: string): void {
  root.alerts ??= {};
  root.alerts[farmId] ??= {};
  root.alerts[farmId][key] = {palmId, alertType, timestamp};
}

// HTTPS endpoint called by the Gateway, NOT by Flutter.
// Configure a strong gateway secret and never embed it in the mobile app.
export const receiveSensorData = onRequest(
  {region: REGION, secrets: [gatewayKey], maxInstances: 10},
  async (req, res) => {
    if (req.method !== 'POST') {res.status(405).send('Method not allowed'); return;}
    const expected = gatewayKey.value();
    if (!validGatewayKey(req.get('x-rasd-gateway-key'), expected)) {
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

    // Reject invalid/unpaired devices before opening an expensive root transaction.
    // The transaction below rechecks all links because they may change meanwhile.
    const deviceSnapshot = await db().ref(`monitoringDevices/${deviceId}`).get();
    const linkedDevice = deviceSnapshot.val();
    if (!linkedDevice?.farmId || !linkedDevice?.palmId) {
      res.status(409).json({error: 'Device not paired or farm unavailable'});
      return;
    }

    // A request overtaken by a newer reading must not restore older sensor state.

const readingKey = db().ref('sensorReadings').push().key!;
const historyKey = db().ref('monitoringHistory').push().key!;
const alertKey = db().ref('alerts').push().key!;
    const tx = await db().ref().transaction(root => {
      const device = root?.monitoringDevices?.[deviceId];
      if (!device?.farmId || !device?.palmId) return;
      const farmId: string = device.farmId;
      const palmId: string = device.palmId;
      const farm = root.farms?.[farmId];
      const palm = root.palms?.[farmId]?.[palmId];
      if (!farm || farm.deleting || !palm || palm.deviceId !== deviceId) return;
      if (typeof device.lastSeen === 'number' && device.lastSeen > now) return;
      device.temperature = temperature;
      device.humidity = humidity;
      device.lastSeen = now;
      device.connectionStatus = 'Online';

      // Save the incoming sensor reading.
      root.sensorReadings ??= {};
      root.sensorReadings[deviceId] ??= {};

      root.sensorReadings[deviceId][readingKey] = {
        timestamp: now,
        temperature,
        humidity,
        // Preserve historical gateway payloads that lack vibration samples.
        ...(vibrationData !== undefined ? {vibrationData} : {}),
        detectionResult: {
          result,
        },
      };

      // Internal streak data stays in a private backend-only path.
      root.monitoringState ??= {};
      const prev = root.monitoringState[deviceId] ?? {};
      const count = prev.lastResult === result ? Math.min((prev.count ?? 0) + 1, CONFIRMATIONS) : 1;
      root.monitoringState[deviceId] = {lastResult: result, count};
      if (count >= CONFIRMATIONS && palm.healthStatus !== result) {
        // UnderMonitoring transitions only when a new result is confirmed.
        // Healthy <-> Suspected and first status are handled here too.
        palm.healthStatus = result as Result;
        appendHistory(root, farmId, palmId, result, now, historyKey);
        if (result === 'Suspected') appendAlert(root, farmId, palmId, 'PossiblePestDetected', now, alertKey);
      }
      return root;
    }, undefined, false);
    if (!tx.committed) {res.status(409).json({error: 'Device not paired or farm unavailable'}); return;}
    res.status(200).json({success: true});
  },
);

// Scheduled functions require billing configuration when deployed.
export const checkOfflineDevices = onSchedule(
  {schedule: 'every 5 minutes', timeZone: 'Etc/UTC', region: REGION},
  async () => {
    const now = Date.now();
    // Most scheduled runs have nothing to change. Avoid a root transaction
    // unless at least one connected device is a candidate for an offline alert.
    // The transaction still rechecks freshness before changing anything.
    const onlineSnapshot = await db().ref('monitoringDevices')
      .orderByChild('connectionStatus').equalTo('Online').get();
    let hasCandidate = false;
    onlineSnapshot.forEach(child => {
      const device = child.val();
      if (device?.farmId && device?.palmId &&
          typeof device.lastSeen === 'number' &&
          now - device.lastSeen >= OFFLINE_AFTER_MS) {
        hasCandidate = true;
      }
    });
    if (!hasCandidate) return;

    // Generate one stable ID per device outside the retryable transaction.
    const alertKeys: Record<string, string> = {};
    onlineSnapshot.forEach(child => {
      alertKeys[child.key!] = db().ref('alerts').push().key!;
    });
    await db().ref().transaction(root => {
      if (!root?.monitoringDevices) return;
      let changed = false;
      for (const [deviceId, device] of Object.entries(root.monitoringDevices) as [string, any][]) {
        if (!device.farmId || !device.palmId || device.connectionStatus !== 'Online') continue;
        const farm = root.farms?.[device.farmId];
        const palm = root.palms?.[device.farmId]?.[device.palmId];
        // Do not change a device if the palm has since been paired elsewhere.
        if (!farm || farm.deleting || !palm || palm.deviceId !== deviceId) continue;
        // No lastSeen yet: don't guess a pairing time or raise an offline alert.
        if (typeof device.lastSeen !== 'number' || now - device.lastSeen < OFFLINE_AFTER_MS) continue;
        device.connectionStatus = 'Offline';
        const alertKey = alertKeys[deviceId];
        if (alertKey) appendAlert(root, device.farmId, device.palmId, 'SensorOffline', now, alertKey);
        changed = true;
      }
      return changed ? root : undefined;
    }, undefined, false);
  },
);
