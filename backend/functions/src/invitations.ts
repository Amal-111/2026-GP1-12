
import {getAuth} from 'firebase-admin/auth';
import {onCall, HttpsError} from 'firebase-functions/v2/https';
import {actor, db, id, object, stringField} from './common';

const options = {
  region: 'us-central1',
  maxInstances: 10,
};

type Invitation = {
  farmId: string;
  farmerId: string;
  createdAt: number;
};

type DataMap = Record<string, any>;

function asMap(value: unknown): DataMap | null {
  if (
    value === null ||
    typeof value !== 'object' ||
    Array.isArray(value)
  ) {
    return null;
  }

  return value as DataMap;
}

function isAssigned(value: unknown): boolean {
  return typeof value === 'string' && value.trim().length > 0;
}

function isPendingForFarmer(
  invitations: DataMap | null,
  farmerId: string
): boolean {
  return Object.values(invitations ?? {}).some(
    invite => asMap(invite)?.farmerId === farmerId
  );
}

// =====================================================
// 1. SEND INVITATION
// =====================================================

export const sendInvitation = onCall(options, async request => {
  const user = await actor(request);

  if (user.role !== 'FarmOwner') {
    throw new HttpsError(
      'permission-denied',
      'Only farm owners can invite farmers.'
    );
  }

  const data = object(request.data);
  const farmId = id(data.farmId, 'farmId');
  const email = stringField(data.email, 'email', 254)
    .trim()
    .toLowerCase();

  let farmerId: string;

  try {
    farmerId = (await getAuth().getUserByEmail(email)).uid;
  } catch (error: any) {
    if (error?.code === 'auth/user-not-found') {
      throw new HttpsError(
        'not-found',
        'Farmer account not found.'
      );
    }

    throw new HttpsError(
      'internal',
      'Unable to look up farmer account.'
    );
  }

  const [farmSnapshot, farmerSnapshot] = await Promise.all([
    db().ref(`farms/${farmId}`).get(),
    db().ref(`users/${farmerId}`).get(),
  ]);

  const farm = asMap(farmSnapshot.val());
  const farmer = asMap(farmerSnapshot.val());

  if (
    !farm ||
    farm.ownerId !== user.uid ||
    farm.deleting === true
  ) {
    throw new HttpsError(
      'permission-denied',
      'Farm is unavailable or not owned by this account.'
    );
  }

  if (!farmer || farmer.role !== 'Farmer') {
    throw new HttpsError(
      'failed-precondition',
      'This account is not registered as a Farmer.'
    );
  }

  if (isAssigned(farmer.farmId)) {
    throw new HttpsError(
      'failed-precondition',
      'This farmer is already assigned to a farm.'
    );
  }

  const invitationsRef = db().ref('farmInvitations');
  const invitationId = invitationsRef.push().key;

  if (!invitationId) {
    throw new HttpsError(
      'internal',
      'Unable to generate invitation ID.'
    );
  }

  const invitation: Invitation = {
    farmId,
    farmerId,
    createdAt: Date.now(),
  };

  const transaction = await invitationsRef.transaction(
    current => {
      const invitations = asMap(current) ?? {};

      if (isPendingForFarmer(invitations, farmerId)) {
        return;
      }

      return {
        ...invitations,
        [invitationId]: invitation,
      };
    },
    undefined,
    false
  );

  if (!transaction.committed) {
    throw new HttpsError(
      'already-exists',
      'This farmer already has a pending invitation.'
    );
  }

  return {
    success: true,
    invitationId,
  };
});

// =====================================================
// 2. ACCEPT INVITATION
// =====================================================

export const acceptInvitation = onCall(options, async request => {
  const user = await actor(request);

  if (user.role !== 'Farmer') {
    throw new HttpsError(
      'permission-denied',
      'Only farmers can accept invitations.'
    );
  }

  const invitationId = id(
    object(request.data).invitationId,
    'invitationId'
  );

  const invitationRef = db().ref(
    `farmInvitations/${invitationId}`
  );

  const invitationSnapshot = await invitationRef.get();

  if (!invitationSnapshot.exists()) {
    throw new HttpsError(
      'not-found',
      'Invitation not found.'
    );
  }

  const invitation = asMap(invitationSnapshot.val());

  if (!invitation || invitation.farmerId !== user.uid) {
    throw new HttpsError(
      'permission-denied',
      'This invitation does not belong to you.'
    );
  }

  const farmId = id(invitation.farmId, 'farmId');
  const farmerRef = db().ref(`users/${user.uid}`);

  const [farmSnapshot, farmerSnapshot] = await Promise.all([
    db().ref(`farms/${farmId}`).get(),
    farmerRef.get(),
  ]);

  const farm = asMap(farmSnapshot.val());
  const farmer = asMap(farmerSnapshot.val());

  if (!farm || farm.deleting === true) {
    throw new HttpsError(
      'failed-precondition',
      'Farm is no longer available.'
    );
  }

  if (!farmer || farmer.role !== 'Farmer') {
    throw new HttpsError(
      'failed-precondition',
      'Farmer account is unavailable.'
    );
  }

  if (
    isAssigned(farmer.farmId) &&
    farmer.farmId !== farmId
  ) {
    throw new HttpsError(
      'failed-precondition',
      'Farmer is already assigned to another farm.'
    );
  }

  // Firebase may initially supply null to a transaction.
  // Use the verified server snapshot as the proposed value.
  const transaction = await farmerRef.transaction(
    current => {
      const currentFarmer = asMap(current);

      if (currentFarmer === null) {
        return {
          ...farmer,
          farmId,
        };
      }

      if (
        currentFarmer.role !== 'Farmer' ||
        (
          isAssigned(currentFarmer.farmId) &&
          currentFarmer.farmId !== farmId
        )
      ) {
        return;
      }

      return {
        ...currentFarmer,
        farmId,
      };
    },
    undefined,
    false
  );

  if (!transaction.committed) {
    const latest = asMap((await farmerRef.get()).val());

    if (latest?.farmId !== farmId) {
      throw new HttpsError(
        'failed-precondition',
        'Unable to assign farmer. Please try again.'
      );
    }
  }

  // Assignment succeeded. Remove the accepted invitation.
  await invitationRef.remove();

  return {success: true};
});

// =====================================================
// 3. REJECT INVITATION
// =====================================================

export const rejectInvitation = onCall(options, async request => {
  const user = await actor(request);

  if (user.role !== 'Farmer') {
    throw new HttpsError(
      'permission-denied',
      'Only farmers can reject invitations.'
    );
  }

  const invitationId = id(
    object(request.data).invitationId,
    'invitationId'
  );

  const invitationRef = db().ref(
    `farmInvitations/${invitationId}`
  );

  const invitationSnapshot = await invitationRef.get();

  if (!invitationSnapshot.exists()) {
    throw new HttpsError(
      'not-found',
      'Invitation not found.'
    );
  }

  const invitation = asMap(invitationSnapshot.val());

  if (!invitation || invitation.farmerId !== user.uid) {
    throw new HttpsError(
      'permission-denied',
      'This invitation does not belong to you.'
    );
  }

  const transaction = await invitationRef.transaction(
    current => {
      const currentInvitation = asMap(current);

      if (currentInvitation === null) {
        return invitation;
      }

      if (
        currentInvitation.farmerId !== user.uid ||
        currentInvitation.farmId !== invitation.farmId
      ) {
        return;
      }

      return null;
    },
    undefined,
    false
  );

  if (!transaction.committed) {
    throw new HttpsError(
      'failed-precondition',
      'Unable to reject invitation. Please try again.'
    );
  }

  return {success: true};
});

// =====================================================
// 4. CANCEL INVITATION (FARM OWNER)
// =====================================================

export const cancelInvitation = onCall(options, async request => {
  const user = await actor(request);

  if (user.role !== 'FarmOwner') {
    throw new HttpsError(
      'permission-denied',
      'Only farm owners can cancel invitations.'
    );
  }

  const invitationId = id(
    object(request.data).invitationId,
    'invitationId'
  );

  const invitationRef = db().ref(
    `farmInvitations/${invitationId}`
  );

  const invitationSnapshot = await invitationRef.get();

  if (!invitationSnapshot.exists()) {
    throw new HttpsError(
      'not-found',
      'Invitation not found.'
    );
  }

  const invitation = asMap(invitationSnapshot.val());

  if (!invitation) {
    throw new HttpsError(
      'not-found',
      'Invitation is unavailable.'
    );
  }

  const farmId = id(invitation.farmId, 'farmId');

  const farmSnapshot = await db()
    .ref(`farms/${farmId}`)
    .get();

  const farm = asMap(farmSnapshot.val());

  if (
    !farm ||
    farm.ownerId !== user.uid ||
    farm.deleting === true
  ) {
    throw new HttpsError(
      'permission-denied',
      'You cannot cancel this invitation.'
    );
  }

  const transaction = await invitationRef.transaction(
    current => {
      const currentInvitation = asMap(current);

      if (currentInvitation === null) {
        return invitation;
      }

      if (
        currentInvitation.farmId !== farmId ||
        currentInvitation.farmerId !== invitation.farmerId
      ) {
        return;
      }

      return null;
    },
    undefined,
    false
  );

  if (!transaction.committed) {
    throw new HttpsError(
      'failed-precondition',
      'Unable to cancel invitation. Please try again.'
    );
  }

  return {success: true};
});

// =====================================================
// 5. REMOVE FARMER (FARM OWNER)
// =====================================================

export const removeFarmer = onCall(options, async request => {
  const user = await actor(request);

  if (user.role !== 'FarmOwner') {
    throw new HttpsError(
      'permission-denied',
      'Only farm owners can remove farmers.'
    );
  }

  const data = object(request.data);
  const farmId = id(data.farmId, 'farmId');
  const farmerId = id(data.farmerId, 'farmerId');

  const farmSnapshot = await db()
    .ref(`farms/${farmId}`)
    .get();

  const farm = asMap(farmSnapshot.val());

  if (
    !farm ||
    farm.ownerId !== user.uid ||
    farm.deleting === true
  ) {
    throw new HttpsError(
      'permission-denied',
      'You do not have access to this farm.'
    );
  }

  const farmerRef = db().ref(`users/${farmerId}`);
  const farmerSnapshot = await farmerRef.get();
  const farmer = asMap(farmerSnapshot.val());

  if (!farmer || farmer.role !== 'Farmer') {
    throw new HttpsError(
      'failed-precondition',
      'Farmer account not found or invalid.'
    );
  }

  if (farmer.farmId !== farmId) {
    throw new HttpsError(
      'failed-precondition',
      'Farmer is not assigned to this farm.'
    );
  }

  // The farmer is verified before starting the transaction.
  // If Firebase initially supplies null, propose the
  // verified farmer data with farmId removed.
  const transaction = await farmerRef.transaction(
    current => {
      const currentFarmer = asMap(current);

      if (currentFarmer === null) {
        const updated = {...farmer};
        delete updated.farmId;
        return updated;
      }

      if (
        currentFarmer.role !== 'Farmer' ||
        currentFarmer.farmId !== farmId
      ) {
        return;
      }

      const updated = {...currentFarmer};
      delete updated.farmId;

      return updated;
    },
    undefined,
    false
  );

  if (!transaction.committed) {
    const latest = asMap((await farmerRef.get()).val());

    if (latest && !isAssigned(latest.farmId)) {
      return {success: true};
    }

    throw new HttpsError(
      'failed-precondition',
      'Unable to remove farmer. Please try again.'
    );
  }

  return {success: true};
});

export const getInvitationDetails = onCall(options, async request => {
  const user = await actor(request);

  const invitationId = id(
    object(request.data).invitationId,
    'invitationId'
  );

  const invitationSnapshot = await db()
    .ref(`farmInvitations/${invitationId}`)
    .get();

  if (!invitationSnapshot.exists()) {
    throw new HttpsError(
      'not-found',
      'Invitation not found.'
    );
  }

  const invitation = asMap(invitationSnapshot.val());

  if (!invitation) {
    throw new HttpsError(
      'not-found',
      'Invitation data is unavailable.'
    );
  }

  const farmId = id(invitation.farmId, 'farmId');
  const farmerId = id(invitation.farmerId, 'farmerId');

  const farmSnapshot = await db()
    .ref(`farms/${farmId}`)
    .get();

  const farm = asMap(farmSnapshot.val());

  if (!farm || farm.deleting === true) {
    throw new HttpsError(
      'not-found',
      'Farm not found.'
    );
  }

  const isOwner =
    user.role === 'FarmOwner' &&
    farm.ownerId === user.uid;

  const isFarmer =
    user.role === 'Farmer' &&
    farmerId === user.uid;

  if (!isOwner && !isFarmer) {
    throw new HttpsError(
      'permission-denied',
      'You cannot view this invitation.'
    );
  }

  const [farmerSnapshot, ownerSnapshot] = await Promise.all([
    db().ref(`users/${farmerId}`).get(),
    db().ref(`users/${farm.ownerId}`).get(),
  ]);

  const farmer = asMap(farmerSnapshot.val());
  const owner = asMap(ownerSnapshot.val());

  return {
    farmName: String(farm.farmName ?? 'Unknown Farm'),
    ownerName: String(owner?.fullName ?? 'Unknown Owner'),
    farmerEmail: String(farmer?.email ?? 'Unknown Farmer'),
  };
});