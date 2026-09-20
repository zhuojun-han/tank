import assert from 'node:assert/strict';
import test from 'node:test';
import { createDraftWriteGuard } from '../app/native-draft-guard.ts';

test('confirmed fish closure defeats queued drafts without discarding another form or later edits', async () => {
  const guard = createDraftWriteGuard();
  const fishFields = [{ key: '0:text', value: 'old fish name' }];
  const remainingFields = [{ key: '0:number', value: '12' }];
  const beforeClose = { tankId: 1, fishModal: true, targetModal: true, tab: 'home', fields: fishFields };
  let resumeQueue!: () => void;
  const blocked = new Promise<void>(resolve => { resumeQueue = resolve; });
  // This snapshot was captured before the close began, but its write has not run.
  const queuedWrite = blocked.then(() => guard.apply('main', beforeClose));
  const release = guard.protect('main', value => {
    if (!value || typeof value !== 'object' || Reflect.get(value, 'tankId') !== 1) return value;
    return { ...value, fishModal: false, fields: remainingFields };
  });
  // A debounce firing during the close must also become a closed snapshot.
  const duringClose = guard.apply('main', beforeClose);
  resumeQueue();
  const expected = { ...beforeClose, fishModal: false, fields: remainingFields };
  assert.deepEqual(await queuedWrite, expected);
  assert.deepEqual(duringClose, expected);
  const photo = { imageRef: 'photo-1', rotation: 90 };
  const otherTank = { ...beforeClose, tankId: 2 };
  assert.equal(guard.apply('photo', photo), photo);
  assert.equal(guard.apply('main', otherTank), otherTank);
  assert.equal(beforeClose.fishModal, true, 'guard does not mutate captured input');
  // Release only once the confirmed close has rendered. A fresh editing session
  // must retain its own unsaved fields; an already guarded snapshot stays closed.
  release();
  assert.deepEqual(guard.apply('main', duringClose), expected);
  const reopened = { ...beforeClose, fields: [{ key: '0:text', value: 'new fish name' }] };
  assert.equal(guard.apply('main', reopened), reopened);
});
