const fs = require('fs');
const path = require('path');

function getIconPath({ baseDir = __dirname, existsSync = fs.existsSync } = {}) {
  const candidates = [
    path.join(baseDir, '..', 'desktop_icon.png'),
    path.join(baseDir, '..', '..', 'desktop_icon.png'),
    path.join(baseDir, '..', 'icon.png'),
    path.join(baseDir, '..', '..', 'icon.png'),
  ];

  for (const filePath of candidates) {
    if (existsSync(filePath)) {
      return filePath;
    }
  }
  return null;
}

module.exports = {
  getIconPath,
};
