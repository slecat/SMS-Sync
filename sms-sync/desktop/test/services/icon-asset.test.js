const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

function readEmbeddedImageSize(buffer, imageOffset, imageSize) {
  const imageBuffer = buffer.subarray(imageOffset, imageOffset + imageSize);
  const pngSignature = '89504e470d0a1a0a';
  if (imageBuffer.subarray(0, 8).toString('hex') === pngSignature) {
    return {
      width: imageBuffer.readUInt32BE(16),
      height: imageBuffer.readUInt32BE(20),
    };
  }

  const dibHeaderSize = imageBuffer.readUInt32LE(0);
  if (dibHeaderSize < 40) {
    throw new Error('Unsupported ICO image header');
  }

  return {
    width: imageBuffer.readInt32LE(4),
    height: imageBuffer.readInt32LE(8) / 2,
  };
}

test('desktop build icon should contain installable icon sizes', () => {
  const iconPath = path.join(__dirname, '..', '..', 'build', 'icon.ico');
  const iconBuffer = fs.readFileSync(iconPath);

  assert.equal(iconBuffer.readUInt16LE(0), 0);
  assert.equal(iconBuffer.readUInt16LE(2), 1);

  const imageCount = iconBuffer.readUInt16LE(4);
  assert.ok(imageCount >= 1, 'icon should contain at least one image');

  for (let index = 0; index < imageCount; index += 1) {
    const entryOffset = 6 + index * 16;
    const imageSize = iconBuffer.readUInt32LE(entryOffset + 8);
    const imageOffset = iconBuffer.readUInt32LE(entryOffset + 12);

    assert.ok(imageSize > 0, 'icon image size should be positive');
    assert.ok(imageOffset + imageSize <= iconBuffer.length, 'icon image should fit inside file');

    const { width, height } = readEmbeddedImageSize(
      iconBuffer,
      imageOffset,
      imageSize
    );
    assert.ok(width > 0 && width <= 256, `icon width ${width} must be between 1 and 256`);
    assert.ok(
      height > 0 && height <= 256,
      `icon height ${height} must be between 1 and 256`
    );
  }
});
