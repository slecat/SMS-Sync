# Update Download Route Selection Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add per-download route selection to both desktop and mobile update flows, including both Ops `local` and mirror download sources.

**Architecture:** Keep the existing latest-release update check on both clients, but normalize Ops download sources into a shared release shape on each platform. The UI stays thin: both clients present a route picker only when the user starts a download, then pass the selected URL into the existing download pipeline.

**Tech Stack:** Electron main/renderer IPC, Node.js `node:test`, Flutter, Dart tests, Android install bridge

---

### Task 1: Extend desktop update-service parsing for mirror routes

**Files:**
- Modify: `sms-sync/desktop/main/services/update-service.js`
- Test: `sms-sync/desktop/test/services/update-service.test.js`

**Step 1: Write the failing test**

Add a desktop service test that proves the latest-release payload is normalized into selectable Ops routes:

```js
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
          version: '1.2.1',
          build_number: 8,
          download_sources: [
            { type: 'local', name: 'Local', url: '/api/public/download/77' },
            { type: 'mirror', name: 'Line A', url: 'https://a.example.com/app.exe' },
          ],
          download_urls: [
            'https://a.example.com/app.exe',
            'https://b.example.com/app.exe',
          ],
        },
      }),
    }),
  });

  const state = await service.checkForUpdates();

  assert.deepEqual(state.latestRelease.downloadOptions, [
    {
      url: 'http://111.228.32.128:8002/api/public/download/77',
      label: 'Local',
      host: '111.228.32.128:8002',
    },
    {
      url: 'https://a.example.com/app.exe',
      label: 'Line A',
      host: 'a.example.com',
    },
    {
      url: 'https://b.example.com/app.exe',
      label: 'b.example.com',
      host: 'b.example.com',
    },
  ]);
});
```

**Step 2: Run test to verify it fails**

Run: `node --test test/services/update-service.test.js`

Expected: FAIL because `downloadOptions` is missing or empty.

**Step 3: Write minimal implementation**

Add a desktop-only normalization helper and include it in the normalized release:

```js
function normalizeDownloadOptions(rawRelease, apiBaseUrl) {
  const options = [];

  for (const source of rawRelease.download_sources ?? []) {
    if (String(source?.type || '').toLowerCase() === 'local') {
      continue;
    }

    const resolvedUrl = resolveDownloadUrl(source?.url, apiBaseUrl);
    if (!resolvedUrl) {
      continue;
    }

    options.push(buildDownloadOption(resolvedUrl, source?.name));
  }

  for (const rawUrl of rawRelease.download_urls ?? []) {
    const resolvedUrl = resolveDownloadUrl(rawUrl, apiBaseUrl);
    if (!resolvedUrl) {
      continue;
    }

    options.push(buildDownloadOption(resolvedUrl, ''));
  }

  return dedupeDownloadOptions(options);
}
```

Update `#normalizeRelease` to return:

```js
return {
  id: releaseId,
  version,
  buildNumber,
  changelog: rawRelease.changelog ?? '',
  downloadUrl: fallbackDownloadUrl,
  downloadOptions: normalizeDownloadOptions(rawRelease, this.apiBaseUrl),
  raw: rawRelease,
};
```

**Step 4: Run test to verify it passes**

Run: `node --test test/services/update-service.test.js`

Expected: PASS for the new normalization test.

**Step 5: Commit**

```bash
git add sms-sync/desktop/main/services/update-service.js sms-sync/desktop/test/services/update-service.test.js
git commit -m "feat(desktop): normalize update mirror routes"
```

### Task 2: Add route-aware desktop download and renderer picker

**Files:**
- Modify: `sms-sync/desktop/main/services/update-service.js`
- Modify: `sms-sync/desktop/main/app.js`
- Modify: `sms-sync/desktop/main/ipc.js`
- Modify: `sms-sync/desktop/preload.js`
- Modify: `sms-sync/desktop/index.html`
- Modify: `sms-sync/desktop/renderer/app.js`
- Modify: `sms-sync/desktop/renderer/styles.css`
- Test: `sms-sync/desktop/test/services/update-service.test.js`
- Test: `sms-sync/desktop/test/services/update-layout.test.js`

**Step 1: Write the failing tests**

Add one service test for explicit route selection:

```js
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
              version: '1.2.1',
              build_number: 8,
              download_urls: ['https://b.example.com/SmsSyncSetup.exe'],
            },
          }),
        };
      }
      return successfulBinaryResponse();
    },
    fsImpl: fakeFs,
    osImpl: fakeOs,
    shellImpl: fakeShell,
  });

  await service.checkForUpdates();
  await service.downloadUpdate('https://b.example.com/SmsSyncSetup.exe');

  assert.equal(requestedUrls.at(-1), 'https://b.example.com/SmsSyncSetup.exe');
});
```

Add one renderer/layout regression test that checks the route picker container exists in the desktop HTML.

**Step 2: Run tests to verify they fail**

Run: `node --test test/services/update-service.test.js test/services/update-layout.test.js`

Expected: FAIL because the desktop download action does not accept a route URL and the picker markup is absent.

**Step 3: Write minimal implementation**

Update the desktop main-process API:

```js
downloadUpdate: async (_event, selectedUrl) => updateService.downloadUpdate(selectedUrl),
```

Update the service:

```js
async downloadUpdate(selectedUrl) {
  if (!selectedUrl) {
    throw new Error('A download route must be selected');
  }

  this.activeDownloadPromise = this.#downloadUpdateInternal(selectedUrl);
}
```

Update the renderer flow:

```js
downloadUpdateBtn.addEventListener('click', async () => {
  const options = currentUpdateState?.latestRelease?.downloadOptions ?? [];
  const selectedOption = await promptForDownloadOption(options);
  if (!selectedOption) {
    return;
  }

  const updateState = await window.electronAPI.downloadUpdate(selectedOption.url);
  renderUpdateState(updateState);
});
```

Add a simple modal with:

- title text
- route list container
- cancel button

**Step 4: Run tests to verify they pass**

Run: `node --test test/services/update-service.test.js test/services/update-layout.test.js`

Expected: PASS for the new route-selection coverage.

**Step 5: Commit**

```bash
git add sms-sync/desktop/main/services/update-service.js sms-sync/desktop/main/app.js sms-sync/desktop/main/ipc.js sms-sync/desktop/preload.js sms-sync/desktop/index.html sms-sync/desktop/renderer/app.js sms-sync/desktop/renderer/styles.css sms-sync/desktop/test/services/update-service.test.js sms-sync/desktop/test/services/update-layout.test.js
git commit -m "feat(desktop): add update mirror picker"
```

### Task 3: Extend mobile update-service parsing and route-aware download

**Files:**
- Modify: `sms-sync/mobile/lib/services/app_update_service.dart`
- Test: `sms-sync/mobile/test/services/app_update_service_test.dart`

**Step 1: Write the failing tests**

Add a Dart test that proves the mobile service normalizes Ops routes including `local`:

```dart
test('checkForUpdates normalizes mirror download options from Ops payload', () async {
  final service = AppUpdateService(
    softwareSlug: 'sms-sync-mobile',
    apiBaseUrl: 'http://111.228.32.128:8002',
    loadReleasePayload: (_) async => <String, dynamic>{
      'success': true,
      'data': <String, dynamic>{
        'version': '1.2.1',
        'build_number': 8,
        'download_sources': <Map<String, dynamic>>[
          <String, dynamic>{'type': 'local', 'name': 'Local', 'url': '/api/public/download/88'},
          <String, dynamic>{'type': 'mirror', 'name': 'Line A', 'url': 'https://a.example.com/app.apk'},
        ],
        'download_urls': <String>[
          'https://b.example.com/app.apk',
        ],
      },
    },
  );

  final state = await service.checkForUpdates(
    currentVersion: const AppVersionInfo(version: '1.2.0', buildNumber: 3),
  );

  expect(state.latestRelease?.downloadOptions.map((item) => item.url), [
    'http://111.228.32.128:8002/api/public/download/88',
    'https://a.example.com/app.apk',
    'https://b.example.com/app.apk',
  ]);
});
```

Add a second test that proves `downloadUpdate` uses the selected route URL.

**Step 2: Run tests to verify they fail**

Run: `flutter test test/services/app_update_service_test.dart`

Expected: FAIL because `downloadOptions` and selected-route download are not implemented.

**Step 3: Write minimal implementation**

Introduce a small route model:

```dart
class AppDownloadOption {
  const AppDownloadOption({
    required this.url,
    required this.label,
    required this.host,
  });

  final String url;
  final String label;
  final String host;
}
```

Update `AppRelease`:

```dart
class AppRelease {
  const AppRelease({
    required this.version,
    required this.buildNumber,
    required this.downloadUrl,
    required this.downloadOptions,
    this.changelog = '',
  });

  final List<AppDownloadOption> downloadOptions;
}
```

Update `downloadUpdate` to require the chosen route:

```dart
Future<AppUpdateState> downloadUpdate({
  required AppRelease release,
  required AppDownloadOption selectedOption,
  void Function(AppUpdateState state)? onStateChanged,
}) async {
  final downloadedFile = await _downloadReleaseFile(
    Uri.parse(selectedOption.url),
    _buildDownloadFileName(selectedOption.url, release),
    onProgress,
  );
}
```

**Step 4: Run tests to verify they pass**

Run: `flutter test test/services/app_update_service_test.dart`

Expected: PASS for the new route parsing and selected-route download tests.

**Step 5: Commit**

```bash
git add sms-sync/mobile/lib/services/app_update_service.dart sms-sync/mobile/test/services/app_update_service_test.dart
git commit -m "feat(mobile): normalize update mirror routes"
```

### Task 4: Add mobile route picker UI and integrate with install flow

**Files:**
- Modify: `sms-sync/mobile/lib/ui/home/settings_tab.dart`
- Test: `sms-sync/mobile/test/ui/` (add or extend the smallest practical widget test)

**Step 1: Write the failing test**

Add a widget-level or interaction-level test that proves:

- tapping the update action with multiple routes opens the picker
- choosing one route calls the update service with that route

If the current Flutter test harness makes a full widget test too expensive, add a focused stateful helper test for the picker decision function instead.

Example interaction target:

```dart
await tester.tap(find.text('下载并安装'));
await tester.pumpAndSettle();

expect(find.text('选择下载路线'), findsOneWidget);
expect(find.text('a.example.com'), findsOneWidget);
```

**Step 2: Run test to verify it fails**

Run: `flutter test`

Expected: FAIL because the mobile UI does not expose route selection yet.

**Step 3: Write minimal implementation**

Add a picker helper in `SettingsTab`:

```dart
Future<AppDownloadOption?> _promptDownloadOption(List<AppDownloadOption> options) {
  return showModalBottomSheet<AppDownloadOption>(
    context: context,
    builder: (context) {
      return ListView(
        children: options.map((option) {
          return ListTile(
            title: Text(option.label),
            subtitle: Text(option.url),
            onTap: () => Navigator.of(context).pop(option),
          );
        }).toList(),
      );
    },
  );
}
```

Wire it into the existing action:

```dart
final selectedOption = await _promptDownloadOption(latestRelease.downloadOptions);
if (selectedOption == null) {
  return;
}

final nextState = await _appUpdateService.downloadUpdate(
  release: latestRelease,
  selectedOption: selectedOption,
  onStateChanged: ...
);
```

Preserve the existing APK install logic after the download succeeds.

**Step 4: Run tests to verify they pass**

Run: `flutter test`

Expected: PASS for the new mobile picker behavior and existing update tests.

**Step 5: Commit**

```bash
git add sms-sync/mobile/lib/ui/home/settings_tab.dart sms-sync/mobile/test/ui
git commit -m "feat(mobile): add update mirror picker"
```

### Task 5: Run focused verification and update docs if behavior text changes

**Files:**
- Modify: `README.md` only if update user-facing behavior or commands are documented there
- Modify: `AGENTS.md` only if repository-level commands or structure change

**Step 1: Run focused desktop verification**

Run: `npm test -- test/services/update-service.test.js test/services/update-layout.test.js`

Expected: PASS

**Step 2: Run focused mobile verification**

Run: `flutter test test/services/app_update_service_test.dart`

Expected: PASS

**Step 3: Run broader sanity checks if touched files require it**

Run: `npm test`
Run: `flutter test`

Expected: PASS, or document any unrelated pre-existing failures.

**Step 4: Update docs only if needed**

If the user-facing update flow is described in existing docs, add a short note that users now choose an Ops mirror route at download time.

**Step 5: Commit**

```bash
git add README.md AGENTS.md
git commit -m "docs: mention selectable update routes"
```
