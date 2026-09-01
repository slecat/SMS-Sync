import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sms_sync_mobile/services/app_update_service.dart';

void main() {
  group('AppUpdateService', () {
    test('compareReleaseVersions prefers semver before build number', () {
      expect(
        compareReleaseVersions(
          const AppRelease(version: '2.0.0', buildNumber: 1, downloadUrl: ''),
          const AppRelease(version: '1.9.9', buildNumber: 99, downloadUrl: ''),
        ),
        greaterThan(0),
      );
      expect(
        compareReleaseVersions(
          const AppRelease(version: '2.0.0', buildNumber: 3, downloadUrl: ''),
          const AppRelease(version: '2.0.0', buildNumber: 2, downloadUrl: ''),
        ),
        greaterThan(0),
      );
      expect(
        compareReleaseVersions(
          const AppRelease(version: '2.0.0', buildNumber: 2, downloadUrl: ''),
          const AppRelease(version: '2.0.0', buildNumber: 2, downloadUrl: ''),
        ),
        0,
      );
    });

    test('checkForUpdates reports available when remote release is newer', () async {
      final service = AppUpdateService(
        softwareSlug: 'sms-sync-mobile',
        apiBaseUrl: 'http://111.228.32.128',
        loadReleasePayload: (uri) async {
          expect(
            uri.toString(),
            'http://111.228.32.128/api/public/softwares/sms-sync-mobile/releases/latest',
          );
          return <String, dynamic>{
            'success': true,
            'data': <String, dynamic>{
              'version': '2.0.1',
              'build_number': 5,
              'download_url': 'http://111.228.32.128/files/sms-sync-mobile-2.0.1.apk',
            },
          };
        },
      );

      final state = await service.checkForUpdates(
        currentVersion: const AppVersionInfo(version: '2.0.0', buildNumber: 2),
      );

      expect(state.status, AppUpdateStatus.available);
      expect(state.latestRelease?.version, '2.0.1');
      expect(state.latestRelease?.buildNumber, 5);
      expect(
        state.latestRelease?.downloadUrl,
        'http://111.228.32.128/files/sms-sync-mobile-2.0.1.apk',
      );
    });

    test('checkForUpdates falls back to latest download endpoint', () async {
      final service = AppUpdateService(
        softwareSlug: 'sms-sync-mobile',
        apiBaseUrl: 'http://111.228.32.128/',
        loadReleasePayload: (_) async => <String, dynamic>{
          'success': true,
          'data': <String, dynamic>{
            'version': '2.0.1',
            'buildNumber': 5,
          },
        },
      );

      final state = await service.checkForUpdates(
        currentVersion: const AppVersionInfo(version: '2.0.0', buildNumber: 2),
      );

      expect(state.status, AppUpdateStatus.available);
      expect(
        state.latestRelease?.downloadUrl,
        'http://111.228.32.128/api/public/download/sms-sync-mobile/latest',
      );
    });

    test('checkForUpdates resolves relative primary download url', () async {
      final service = AppUpdateService(
        softwareSlug: 'sms-sync-mobile',
        apiBaseUrl: 'http://111.228.32.128:8002',
        loadReleasePayload: (_) async => <String, dynamic>{
          'success': true,
          'data': <String, dynamic>{
            'version': '2.0.1',
            'build_number': 5,
            'download_url': '/api/public/download/36',
          },
        },
      );

      final state = await service.checkForUpdates(
        currentVersion: const AppVersionInfo(version: '2.0.0', buildNumber: 2),
      );

      expect(state.status, AppUpdateStatus.available);
      expect(
        state.latestRelease?.downloadUrl,
        'http://111.228.32.128:8002/api/public/download/36',
      );
    });

    test('checkForUpdates normalizes mirror download options from Ops payload', () async {
      final service = AppUpdateService(
        softwareSlug: 'sms-sync-mobile',
        apiBaseUrl: 'http://111.228.32.128:8002',
        loadReleasePayload: (_) async => <String, dynamic>{
          'success': true,
          'data': <String, dynamic>{
            'version': '2.0.1',
            'build_number': 5,
            'download_sources': <Map<String, dynamic>>[
              <String, dynamic>{
                'type': 'local',
                'name': 'Local',
                'url': '/api/public/download/99',
              },
              <String, dynamic>{
                'type': 'mirror',
                'name': 'Line A',
                'url': 'https://a.example.com/sms-sync-mobile.apk',
              },
            ],
            'download_urls': <String>[
              'https://a.example.com/sms-sync-mobile.apk',
              'https://b.example.com/sms-sync-mobile.apk',
              '',
            ],
          },
        },
      );

      final state = await service.checkForUpdates(
        currentVersion: const AppVersionInfo(version: '2.0.0', buildNumber: 2),
      );

      expect(
        state.latestRelease?.downloadOptions,
        const <AppDownloadOption>[
          AppDownloadOption(
            url: 'http://111.228.32.128:8002/api/public/download/sms-sync-mobile/latest',
            label: '默认安装包',
            host: '111.228.32.128:8002',
          ),
          AppDownloadOption(
            url: 'http://111.228.32.128:8002/api/public/download/99',
            label: 'Local',
            host: '111.228.32.128:8002',
          ),
          AppDownloadOption(
            url: 'https://a.example.com/sms-sync-mobile.apk',
            label: 'Line A',
            host: 'a.example.com',
          ),
          AppDownloadOption(
            url: 'https://b.example.com/sms-sync-mobile.apk',
            label: 'b.example.com',
            host: 'b.example.com',
          ),
        ],
      );
    });

    test(
      'checkForUpdates keeps only one option when primary installer duplicates an Ops route',
      () async {
        final service = AppUpdateService(
          softwareSlug: 'sms-sync-mobile',
          apiBaseUrl: 'http://111.228.32.128:8002',
          loadReleasePayload: (_) async => <String, dynamic>{
            'success': true,
            'data': <String, dynamic>{
              'version': '2.0.1',
              'build_number': 5,
              'download_url': 'http://111.228.32.128:8002/api/public/download/99',
              'download_sources': <Map<String, dynamic>>[
                <String, dynamic>{
                  'type': 'local',
                  'name': 'Local',
                  'url': '/api/public/download/99',
                },
              ],
              'download_urls': <String>[
                'http://111.228.32.128:8002/api/public/download/99',
              ],
            },
          },
        );

        final state = await service.checkForUpdates(
          currentVersion: const AppVersionInfo(version: '2.0.0', buildNumber: 2),
        );

        expect(
          state.latestRelease?.downloadOptions,
          const <AppDownloadOption>[
            AppDownloadOption(
              url: 'http://111.228.32.128:8002/api/public/download/99',
              label: '默认安装包',
              host: '111.228.32.128:8002',
            ),
          ],
        );
      },
    );

    test('checkForUpdates reports upToDate when remote release is not newer', () async {
      final service = AppUpdateService(
        softwareSlug: 'sms-sync-mobile',
        apiBaseUrl: 'http://111.228.32.128',
        loadReleasePayload: (_) async => <String, dynamic>{
          'success': true,
          'data': <String, dynamic>{
            'version': '2.0.0',
            'build_number': 2,
          },
        },
      );

      final state = await service.checkForUpdates(
        currentVersion: const AppVersionInfo(version: '2.0.0', buildNumber: 2),
      );

      expect(state.status, AppUpdateStatus.upToDate);
      expect(state.isUpdateAvailable, isFalse);
    });

    test('checkForUpdates reports error on malformed payload', () async {
      final service = AppUpdateService(
        softwareSlug: 'sms-sync-mobile',
        apiBaseUrl: 'http://111.228.32.128',
        loadReleasePayload: (_) async => <String, dynamic>{
          'success': true,
          'data': <String, dynamic>{'build_number': 2},
        },
      );

      final state = await service.checkForUpdates(
        currentVersion: const AppVersionInfo(version: '2.0.0', buildNumber: 2),
      );

      expect(state.status, AppUpdateStatus.error);
      expect(state.message.toLowerCase(), contains('version'));
    });

    test('checkForUpdates reports a readable error when endpoint returns html', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);
      server.listen((request) async {
        request.response.headers.contentType = ContentType.html;
        request.response.statusCode = HttpStatus.notFound;
        request.response.write('<html><body>Not Found</body></html>');
        await request.response.close();
      });

      final service = AppUpdateService(
        softwareSlug: 'sms-sync-mobile',
        apiBaseUrl: 'http://${server.address.address}:${server.port}',
      );

      final state = await service.checkForUpdates(
        currentVersion: const AppVersionInfo(version: '2.0.0', buildNumber: 2),
      );

      expect(state.status, AppUpdateStatus.error);
      expect(state.message, contains('Unexpected update response'));
      expect(state.message, isNot(contains('FormatException')));
      expect(state.message, contains('404'));
      expect(state.message, contains('text/html'));
    });

    test('downloadUpdate streams progress and returns a readyToInstall state', () async {
      final progressStates = <AppUpdateState>[];
      final service = AppUpdateService(
        softwareSlug: 'sms-sync-mobile',
        apiBaseUrl: 'http://111.228.32.128',
        loadReleasePayload: (_) async => <String, dynamic>{},
        downloadReleaseFile: (uri, fileName, onProgress) async {
          expect(
            uri.toString(),
            'http://111.228.32.128/files/sms-sync-mobile-2.0.1.apk',
          );
          expect(fileName, 'sms-sync-mobile-2.0.1-build-5.apk');
          onProgress(3, 10);
          onProgress(10, 10);
          return DownloadedUpdateFile(
            filePath: '/tmp/sms-sync-mobile-2.0.1-build-5.apk',
            bytes: Uint8List.fromList(const [1, 2, 3, 4]),
          );
        },
      );

      final state = await service.downloadUpdate(
        release: const AppRelease(
          version: '2.0.1',
          buildNumber: 5,
          downloadUrl: 'http://111.228.32.128/files/sms-sync-mobile-2.0.1.apk',
        ),
        onStateChanged: progressStates.add,
      );

      expect(progressStates.map((state) => state.downloadProgress), containsAll(<int>[30, 100]));
      expect(state.status, AppUpdateStatus.readyToInstall);
      expect(state.downloadedFilePath, '/tmp/sms-sync-mobile-2.0.1-build-5.apk');
      expect(state.downloadedBytes, 4);
    });

    test('downloadUpdate uses the selected mirror route URL', () async {
      final requestedUris = <String>[];
      final service = AppUpdateService(
        softwareSlug: 'sms-sync-mobile',
        apiBaseUrl: 'http://111.228.32.128',
        loadReleasePayload: (_) async => <String, dynamic>{},
        downloadReleaseFile: (uri, fileName, onProgress) async {
          requestedUris.add(uri.toString());
          onProgress(4, 4);
          return DownloadedUpdateFile(
            filePath: '/tmp/sms-sync-mobile-2.0.1-build-5.apk',
            bytes: Uint8List.fromList(const [1, 2, 3, 4]),
          );
        },
      );

      await service.downloadUpdate(
        release: const AppRelease(
          version: '2.0.1',
          buildNumber: 5,
          downloadUrl: 'http://111.228.32.128/files/sms-sync-mobile-2.0.1.apk',
          downloadOptions: <AppDownloadOption>[
            AppDownloadOption(
              url: 'https://mirror.example.com/sms-sync-mobile.apk',
              label: 'mirror.example.com',
              host: 'mirror.example.com',
            ),
          ],
        ),
        selectedOption: const AppDownloadOption(
          url: 'https://mirror.example.com/sms-sync-mobile.apk',
          label: 'mirror.example.com',
          host: 'mirror.example.com',
        ),
      );

      expect(
        requestedUris,
        <String>['https://mirror.example.com/sms-sync-mobile.apk'],
      );
    });
  });
}
