const test = require('node:test');
const assert = require('node:assert/strict');

const {
  DesktopUpdateService,
  compareReleaseVersions,
} = require('../../main/services/update-service');

test('compareReleaseVersions prefers semver before build number', () => {
  assert.equal(
    compareReleaseVersions(
      { version: '1.2.0', buildNumber: 1 },
      { version: '1.1.9', buildNumber: 99 }
    ),
    1
  );
  assert.equal(
    compareReleaseVersions(
      { version: '1.2.0', buildNumber: 2 },
      { version: '1.2.0', buildNumber: 1 }
    ),
    1
  );
  assert.equal(
    compareReleaseVersions(
      { version: '1.2.0', buildNumber: 1 },
      { version: '1.2.0', buildNumber: 1 }
    ),
    0
  );
  assert.equal(
    compareReleaseVersions(
      { version: '1.1.9', buildNumber: 9 },
      { version: '1.2.0', buildNumber: 1 }
    ),
    -1
  );
});

test('DesktopUpdateService reports update available from latest release payload', async () => {
  const requests = [];
  const service = new DesktopUpdateService({
    appVersion: '1.0.0',
    appBuildNumber: 1,
    softwareSlug: 'sms-sync',
    apiBaseUrl: 'http://111.228.32.128',
    fetchImpl: async (url) => {
      requests.push(url);
      return {
        ok: true,
        json: async () => ({
          success: true,
          data: {
            id: 42,
            version: '1.0.1',
            build_number: 3,
            download_url: 'http://111.228.32.128/files/sms-sync-1.0.1.exe',
            changelog: 'bug fixes',
          },
        }),
      };
    },
  });

  const state = await service.checkForUpdates();

  assert.deepEqual(requests, [
    'http://111.228.32.128/api/public/softwares/sms-sync/releases/latest',
  ]);
  assert.equal(state.status, 'available');
  assert.equal(state.isUpdateAvailable, true);
  assert.equal(state.latestRelease.version, '1.0.1');
  assert.equal(state.latestRelease.buildNumber, 3);
  assert.equal(
    state.latestRelease.downloadUrl,
    'http://111.228.32.128/files/sms-sync-1.0.1.exe'
  );
});

test('DesktopUpdateService falls back to the latest download endpoint when payload has no download url', async () => {
  const service = new DesktopUpdateService({
    appVersion: '1.0.0',
    appBuildNumber: 1,
    softwareSlug: 'sms-sync',
    apiBaseUrl: 'http://111.228.32.128/',
    fetchImpl: async () => ({
      ok: true,
      json: async () => ({
        success: true,
        data: {
          id: 42,
          version: '1.0.1',
          buildNumber: 3,
        },
      }),
    }),
  });

  const state = await service.checkForUpdates();

  assert.equal(state.status, 'available');
  assert.equal(
    state.latestRelease.downloadUrl,
    'http://111.228.32.128/api/public/download/sms-sync/latest'
  );
});

test('DesktopUpdateService resolves relative download urls against the api base url', async () => {
  const service = new DesktopUpdateService({
    appVersion: '1.0.0',
    appBuildNumber: 1,
    softwareSlug: 'sms-sync-desktop',
    apiBaseUrl: 'http://111.228.32.128:8002',
    fetchImpl: async () => ({
      ok: true,
      json: async () => ({
        success: true,
        data: {
          id: 26,
          version: '1.1.4',
          build_number: 6,
          download_url: '/api/public/download/26',
        },
      }),
    }),
  });

  const state = await service.checkForUpdates();

  assert.equal(state.status, 'available');
  assert.equal(
    state.latestRelease.downloadUrl,
    'http://111.228.32.128:8002/api/public/download/26'
  );
});

test('DesktopUpdateService normalizes mirror download options from Ops payload', async () => {
  const service = new DesktopUpdateService({
    appVersion: '1.2.0',
    appBuildNumber: 7,
    softwareSlug: 'sms-sync-desktop',
    apiBaseUrl: 'http://111.228.32.128:8002',
    fetchImpl: async () => ({
      ok: true,
      json: async () => ({
        success: true,
        data: {
          id: 77,
          version: '1.2.1',
          build_number: 8,
          download_sources: [
            {
              type: 'local',
              name: 'Local',
              url: '/api/public/download/77',
            },
            {
              type: 'mirror',
              name: 'Line A',
              url: 'https://a.example.com/SmsSyncSetup.exe',
            },
          ],
          download_urls: [
            'https://a.example.com/SmsSyncSetup.exe',
            'https://b.example.com/SmsSyncSetup.exe',
            '',
          ],
        },
      }),
    }),
  });

  const state = await service.checkForUpdates();

  assert.deepEqual(state.latestRelease.downloadOptions, [
    {
      url: 'http://111.228.32.128:8002/api/public/download/sms-sync-desktop/latest',
      label: '默认安装包',
      host: '111.228.32.128:8002',
    },
    {
      url: 'http://111.228.32.128:8002/api/public/download/77',
      label: 'Local',
      host: '111.228.32.128:8002',
    },
    {
      url: 'https://a.example.com/SmsSyncSetup.exe',
      label: 'Line A',
      host: 'a.example.com',
    },
    {
      url: 'https://b.example.com/SmsSyncSetup.exe',
      label: 'b.example.com',
      host: 'b.example.com',
    },
  ]);
});

test('DesktopUpdateService keeps only one option when primary installer duplicates an Ops route', async () => {
  const service = new DesktopUpdateService({
    appVersion: '1.2.0',
    appBuildNumber: 7,
    softwareSlug: 'sms-sync-desktop',
    apiBaseUrl: 'http://111.228.32.128:8002',
    fetchImpl: async () => ({
      ok: true,
      json: async () => ({
        success: true,
        data: {
          id: 77,
          version: '1.2.1',
          build_number: 8,
          download_url: 'http://111.228.32.128:8002/api/public/download/77',
          download_sources: [
            {
              type: 'local',
              name: 'Local',
              url: '/api/public/download/77',
            },
          ],
          download_urls: [
            'http://111.228.32.128:8002/api/public/download/77',
          ],
        },
      }),
    }),
  });

  const state = await service.checkForUpdates();

  assert.deepEqual(state.latestRelease.downloadOptions, [
    {
      url: 'http://111.228.32.128:8002/api/public/download/77',
      label: '默认安装包',
      host: '111.228.32.128:8002',
    },
  ]);
});

test('DesktopUpdateService reports current when latest release is not newer', async () => {
  const service = new DesktopUpdateService({
    appVersion: '1.0.0',
    appBuildNumber: 2,
    softwareSlug: 'sms-sync',
    apiBaseUrl: 'http://111.228.32.128',
    fetchImpl: async () => ({
      ok: true,
      json: async () => ({
        success: true,
        data: {
          id: 42,
          version: '1.0.0',
          build_number: 2,
        },
      }),
    }),
  });

  const state = await service.checkForUpdates();

  assert.equal(state.status, 'current');
  assert.equal(state.isUpdateAvailable, false);
});

test('DesktopUpdateService treats malformed payloads as errors', async () => {
  const service = new DesktopUpdateService({
    appVersion: '1.0.0',
    appBuildNumber: 1,
    softwareSlug: 'sms-sync',
    apiBaseUrl: 'http://111.228.32.128',
    fetchImpl: async () => ({
      ok: true,
      json: async () => ({
        success: true,
        data: {
          build_number: 1,
        },
      }),
    }),
  });

  const state = await service.checkForUpdates();

  assert.equal(state.status, 'error');
  assert.equal(state.isUpdateAvailable, false);
  assert.match(state.message, /version/i);
});

test('DesktopUpdateService downloads the installer and opens it', async () => {
  const writes = [];
  const openedPaths = [];
  const service = new DesktopUpdateService({
    appVersion: '1.0.0',
    appBuildNumber: 1,
    softwareSlug: 'sms-sync',
    apiBaseUrl: 'http://111.228.32.128',
    fetchImpl: async (url) => {
      if (url.includes('/releases/latest')) {
        return {
          ok: true,
          json: async () => ({
            success: true,
            data: {
              id: 42,
              version: '1.0.1',
              build_number: 3,
              download_url: 'http://111.228.32.128/files/sms-sync-1.0.1.exe',
            },
          }),
        };
      }

      return {
        ok: true,
        headers: {
          get: (name) => (name.toLowerCase() === 'content-length' ? '4' : null),
        },
        body: {
          async *[Symbol.asyncIterator]() {
            yield Buffer.from([0, 1]);
            yield Buffer.from([2, 3]);
          },
        },
      };
    },
    fsImpl: {
      mkdir: async () => {},
      writeFile: async (targetPath, content) => {
        writes.push({ targetPath, content: Buffer.from(content) });
      },
      rm: async () => {},
    },
    osImpl: {
      tmpdir: () => 'C:/Temp',
    },
    shellImpl: {
      openPath: async (targetPath) => {
        openedPaths.push(targetPath);
        return '';
      },
    },
  });

  await service.checkForUpdates();
  const state = await service.downloadUpdate();

  assert.equal(state.status, 'ready');
  assert.equal(writes.length, 1);
  assert.equal(
    writes[0].targetPath,
    'C:\\Temp\\sms-sync-updates\\sms-sync-1.0.1-build-3.exe'
  );
  assert.deepEqual(Array.from(writes[0].content), [0, 1, 2, 3]);
  assert.deepEqual(openedPaths, [
    'C:\\Temp\\sms-sync-updates\\sms-sync-1.0.1-build-3.exe',
  ]);
  assert.equal(state.downloadProgress, 100);
  assert.equal(state.downloadedFilePath, 'C:\\Temp\\sms-sync-updates\\sms-sync-1.0.1-build-3.exe');
});

test('DesktopUpdateService downloads using the selected mirror route', async () => {
  const requestedUrls = [];
  const service = new DesktopUpdateService({
    appVersion: '1.2.0',
    appBuildNumber: 7,
    softwareSlug: 'sms-sync-desktop',
    apiBaseUrl: 'http://111.228.32.128:8002',
    fetchImpl: async (url) => {
      requestedUrls.push(url);
      if (url.includes('/releases/latest')) {
        return {
          ok: true,
          json: async () => ({
            success: true,
            data: {
              id: 77,
              version: '1.2.1',
              build_number: 8,
              download_urls: [
                'https://a.example.com/SmsSyncSetup.exe',
                'https://b.example.com/SmsSyncSetup.exe',
              ],
            },
          }),
        };
      }

      return {
        ok: true,
        headers: {
          get: (name) => {
            if (name.toLowerCase() === 'content-length') {
              return '4';
            }
            return null;
          },
        },
        body: {
          async *[Symbol.asyncIterator]() {
            yield Buffer.from([0, 1, 2, 3]);
          },
        },
      };
    },
    fsImpl: {
      mkdir: async () => {},
      writeFile: async () => {},
      rm: async () => {},
    },
    osImpl: {
      tmpdir: () => 'C:/Temp',
    },
    shellImpl: {
      openPath: async () => '',
    },
  });

  await service.checkForUpdates();
  const state = await service.downloadUpdate(
    'https://b.example.com/SmsSyncSetup.exe'
  );

  assert.equal(state.status, 'ready');
  assert.equal(
    requestedUrls.at(-1),
    'https://b.example.com/SmsSyncSetup.exe'
  );
});

test('DesktopUpdateService uses the response filename when the download url has no extension', async () => {
  const writes = [];
  const openedPaths = [];
  const service = new DesktopUpdateService({
    appVersion: '1.2.0',
    appBuildNumber: 7,
    softwareSlug: 'sms-sync-desktop',
    apiBaseUrl: 'http://111.228.32.128:8002',
    fetchImpl: async (url) => {
      if (url.includes('/releases/latest')) {
        return {
          ok: true,
          json: async () => ({
            success: true,
            data: {
              id: 77,
              version: '1.2.1',
              build_number: 8,
              download_url: '/api/public/download/sms-sync-desktop/latest',
            },
          }),
        };
      }

      return {
        ok: true,
        headers: {
          get: (name) => {
            if (name.toLowerCase() === 'content-length') {
              return '4';
            }
            if (name.toLowerCase() === 'content-disposition') {
              return 'attachment; filename="SmsSyncSetup.exe"';
            }
            return null;
          },
        },
        body: {
          async *[Symbol.asyncIterator]() {
            yield Buffer.from([0, 1, 2, 3]);
          },
        },
      };
    },
    fsImpl: {
      mkdir: async () => {},
      writeFile: async (targetPath, content) => {
        writes.push({ targetPath, content: Buffer.from(content) });
      },
      rm: async () => {},
    },
    osImpl: {
      tmpdir: () => 'C:/Temp',
    },
    shellImpl: {
      openPath: async (targetPath) => {
        openedPaths.push(targetPath);
        return '';
      },
    },
  });

  await service.checkForUpdates();
  const state = await service.downloadUpdate();

  assert.equal(state.status, 'ready');
  assert.equal(writes.length, 1);
  assert.equal(
    writes[0].targetPath,
    'C:\\Temp\\sms-sync-desktop-updates\\SmsSyncSetup.exe'
  );
  assert.deepEqual(openedPaths, [
    'C:\\Temp\\sms-sync-desktop-updates\\SmsSyncSetup.exe',
  ]);
  assert.equal(
    state.downloadedFilePath,
    'C:\\Temp\\sms-sync-desktop-updates\\SmsSyncSetup.exe'
  );
});

test('DesktopUpdateService removes partial downloads after a failure', async () => {
  const removedPaths = [];
  const service = new DesktopUpdateService({
    appVersion: '1.0.0',
    appBuildNumber: 1,
    softwareSlug: 'sms-sync',
    apiBaseUrl: 'http://111.228.32.128',
    fetchImpl: async (url) => {
      if (url.includes('/releases/latest')) {
        return {
          ok: true,
          json: async () => ({
            success: true,
            data: {
              id: 42,
              version: '1.0.1',
              build_number: 3,
              download_url: 'http://111.228.32.128/files/sms-sync-1.0.1.exe',
            },
          }),
        };
      }

      throw new Error('network down');
    },
    fsImpl: {
      mkdir: async () => {},
      writeFile: async () => {},
      rm: async (targetPath) => {
        removedPaths.push(targetPath);
      },
    },
    osImpl: {
      tmpdir: () => 'C:/Temp',
    },
    shellImpl: {
      openPath: async () => '',
    },
  });

  await service.checkForUpdates();
  const state = await service.downloadUpdate();

  assert.equal(state.status, 'error');
  assert.match(state.message, /network down/i);
  assert.deepEqual(removedPaths, [
    'C:\\Temp\\sms-sync-updates\\sms-sync-1.0.1-build-3.exe',
  ]);
});

test('DesktopUpdateService rejects concurrent downloads', async () => {
  let releaseDownload;
  const service = new DesktopUpdateService({
    appVersion: '1.0.0',
    appBuildNumber: 1,
    softwareSlug: 'sms-sync',
    apiBaseUrl: 'http://111.228.32.128',
    fetchImpl: async (url) => {
      if (url.includes('/releases/latest')) {
        return {
          ok: true,
          json: async () => ({
            success: true,
            data: {
              id: 42,
              version: '1.0.1',
              build_number: 3,
              download_url: 'http://111.228.32.128/files/sms-sync-1.0.1.exe',
            },
          }),
        };
      }

      return {
        ok: true,
        headers: {
          get: () => '2',
        },
        body: {
          async *[Symbol.asyncIterator]() {
            yield Buffer.from([0, 1]);
            await new Promise((resolve) => {
              releaseDownload = resolve;
            });
          },
        },
      };
    },
    fsImpl: {
      mkdir: async () => {},
      writeFile: async () => {},
      rm: async () => {},
    },
    osImpl: {
      tmpdir: () => 'C:/Temp',
    },
    shellImpl: {
      openPath: async () => '',
    },
  });

  await service.checkForUpdates();
  const firstDownload = service.downloadUpdate();
  await new Promise((resolve) => setTimeout(resolve, 0));

  await assert.rejects(
    () => service.downloadUpdate(),
    /download already in progress/i
  );

  releaseDownload();
  await firstDownload;
});
