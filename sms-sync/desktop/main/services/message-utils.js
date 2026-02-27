const MESSAGE_DEDUP_TIME = 5000;

function extractVerificationCode(text = '') {
  const patterns = [
    /验证码[是：:]*\s*([0-9]{4,8})/i,
    /校验码[是：:]*\s*([0-9]{4,8})/i,
    /动态码[是：:]*\s*([0-9]{4,8})/i,
    /密码[是：:]*\s*([0-9]{4,8})/i,
    /code[是：:]*\s*([0-9]{4,8})/i,
    /([0-9]{4,8})/,
  ];

  for (const pattern of patterns) {
    const match = text.match(pattern);
    if (match && match[1]) {
      return match[1];
    }
  }
  return null;
}

function createMessageDeduper(defaultDedupTime = MESSAGE_DEDUP_TIME) {
  const receivedMessages = new Map();

  return function isDuplicateMessage(key, customDedupTime = null) {
    const now = Date.now();
    const dedupTime = customDedupTime || defaultDedupTime;

    if (receivedMessages.has(key)) {
      const existingTime = receivedMessages.get(key);
      if (now - existingTime <= dedupTime) {
        return true;
      }
      receivedMessages.delete(key);
    }

    receivedMessages.set(key, now);

    for (const [storedKey, timestamp] of receivedMessages) {
      if (now - timestamp > dedupTime) {
        receivedMessages.delete(storedKey);
      }
    }

    return false;
  };
}

module.exports = {
  MESSAGE_DEDUP_TIME,
  extractVerificationCode,
  createMessageDeduper,
};
