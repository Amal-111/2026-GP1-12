
import {initializeApp} from 'firebase-admin/app';
import {setGlobalOptions} from 'firebase-functions/v2';

initializeApp({
  databaseURL: 'https://rasd-6a036-default-rtdb.europe-west1.firebasedatabase.app',
});

setGlobalOptions({maxInstances: 10});

export {createFarm, updateFarm, deleteFarm} from './farms';
export {addPalm, updatePalm, deletePalm} from './palms';
export {connectDevice, disconnectDevice} from './devices';
export {receiveSensorData, checkOfflineDevices} from './monitoring';
export {recordTreatment} from './treatments';

export {
  sendInvitation,
  searchFarmers,
  acceptInvitation,
  rejectInvitation,
  cancelInvitation,
  removeFarmer,
  getInvitationDetails,
  listFarmInvitations
} from './invitations';
export {
  deleteAccount,
  registerProfile,
  updateProfile,
  syncVerifiedEmail,
  getMyAssignedFarm
} from './accounts';
