
import {initializeApp} from 'firebase-admin/app';
import {setGlobalOptions} from 'firebase-functions/v2';

initializeApp({
  databaseURL: 'https://rasd-6a036-default-rtdb.firebaseio.com',
});

setGlobalOptions({maxInstances: 10});

export {createFarm, updateFarm, deleteFarm} from './farms';
export {addPalm, updatePalm, deletePalm} from './palms';
export {connectDevice, disconnectDevice} from './devices';
export {receiveSensorData, checkOfflineDevices} from './monitoring';
export {recordTreatment} from './treatments';

export {
  sendInvitation,
  acceptInvitation,
  rejectInvitation,
  cancelInvitation,
  removeFarmer,
  getInvitationDetails
} from './invitations';
export {
  deleteAccount,
  registerProfile,
  updateProfile,
  getMyAssignedFarm
} from './accounts';
