const test = require('node:test');
const assert = require('node:assert/strict');
const {
  extractVerificationCode,
  createMessageDeduper,
} = require('../../main/services/message-utils');

test('extractVerificationCode should return expected code from common message formats', () => {
  assert.equal(
    extractVerificationCode('【应用】您的验证码是 123456，5分钟内有效。'),
    '123456'
  );
  assert.equal(extractVerificationCode('验证码: 7788，请勿泄露给他人。'), '7788');
  assert.equal(extractVerificationCode('Your code is 246810.'), '246810');
});

test('extractVerificationCode should return null when no code exists', () => {
  assert.equal(extractVerificationCode('这是一条普通消息，没有验证码。'), null);
});

test('createMessageDeduper should block duplicates within dedup window', async () => {
  const isDuplicate = createMessageDeduper(30);

  assert.equal(isDuplicate('msg-1'), false);
  assert.equal(isDuplicate('msg-1'), true);

  await new Promise((resolve) => setTimeout(resolve, 35));
  assert.equal(isDuplicate('msg-1'), false);
});
