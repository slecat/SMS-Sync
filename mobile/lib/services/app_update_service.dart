import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

typedef ReleasePayloadLoader =
    Future<Map<String, dynamic>> Function(Uri uri);
typedef ReleaseFileDownloader =
    Future<DownloadedUpdateFile> Function(
      Uri uri,
      String fileName,
      void Function(int receivedBytes, int totalBytes) onProgress,
    );

class AppVersionInfo {
  const AppVersionInfo({
    required this.version,
    required this.buildNumber,
  });

  final String version;
  final int buildNumber;
}

class AppDownloadOption {
  const AppDownloadOption({
    required this.url,
    required this.label,
    required this.host,
  });

  final String url;
  final String label;
  final String host;

  @override
  bool operator ==(Object other) {
    return other is AppDownloadOption &&
        other.url == url &&
        other.label == label &&
        other.host == host;
  }

  @override
  int get hashCode => Object.hash(url, label, host);
}

class AppRelease {
  const AppRelease({
    required this.version,
    required this.buildNumber,
    required this.downloadUrl,
    this.downloadOptions = const <AppDownloadOption>[],
    this.changelog = '',
  });

  final String version;
  final int buildNumber;
  final String downloadUrl;
  final List<AppDownloadOption> downloadOptions;
  final String changelog;
}

class DownloadedUpdateFile {
  const DownloadedUpdateFile({
    required this.filePath,
    required this.bytes,
  });

  final String filePath;
  final Uint8List bytes;
}

enum AppUpdateStatus {
  idle,
  checking,
  available,
  upToDate,
  downloading,
  readyToInstall,
  error,
}

class AppUpdateState {
  const AppUpdateState({
    required this.status,
    required this.message,
    required this.currentVersion,
    required this.currentBuildNumber,
    required this.isUpdateAvailable,
    this.latestRelease,
    this.downloadProgress = 0,
    this.downloadedFilePath,
    this.downloadedBytes = 0,
  });

  factory AppUpdateState.initial() {
    return const AppUpdateState(
      status: AppUpdateStatus.idle,
      message: '',
      currentVersion: '',
      currentBuildNumber: 0,
      isUpdateAvailable: false,
    );
  }

  final AppUpdateStatus status;
  final String message;
  final String currentVersion;
  final int currentBuildNumber;
  final bool isUpdateAvailable;
  final AppRelease? latestRelease;
  final int downloadProgress;
  final String? downloadedFilePath;
  final int downloadedBytes;

  AppUpdateState copyWith({
    AppUpdateStatus? status,
    String? message,
    String? currentVersion,
    int? currentBuildNumber,
    bool? isUpdateAvailable,
    AppRelease? latestRelease,
    bool clearLatestRelease = false,
    int? downloadProgress,
    String? downloadedFilePath,
    bool clearDownloadedFilePath = false,
    int? downloadedBytes,
  }) {
    return AppUpdateState(
      status: status ?? this.status,
      message: message ?? this.message,
      currentVersion: currentVersion ?? this.currentVersion,
      currentBuildNumber: currentBuildNumber ?? this.currentBuildNumber,
      isUpdateAvailable: isUpdateAvailable ?? this.isUpdateAvailable,
      latestRelease: clearLatestRelease
          ? null
          : (latestRelease ?? this.latestRelease),
      downloadProgress: downloadProgress ?? this.downloadProgress,
      downloadedFilePath: clearDownloadedFilePath
          ? null
          : (downloadedFilePath ?? this.downloadedFilePath),
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
    );
  }
}

int compareReleaseVersions(AppRelease left, AppRelease right) {
  final leftParts = _parseVersion(left.version);
  final rightParts = _parseVersion(right.version);
  for (var index = 0; index < leftParts.length; index += 1) {
    if (leftParts[index] > rightParts[index]) {
      return 1;
    }
    if (leftParts[index] < rightParts[index]) {
      return -1;
    }
  }

  if (left.buildNumber > right.buildNumber) {
    return 1;
  }
  if (left.buildNumber < right.buildNumber) {
    return -1;
  }
  return 0;
}

class AppUpdateService {
  AppUpdateService({
    required this.softwareSlug,
    required this.apiBaseUrl,
    ReleasePayloadLoader? loadReleasePayload,
    ReleaseFileDownloader? downloadReleaseFile,
  }) : _loadReleasePayload =
           loadReleasePayload ?? _defaultLoadReleasePayload,
       _downloadReleaseFile =
           downloadReleaseFile ?? _defaultDownloadReleaseFile;

  final String softwareSlug;
  final String apiBaseUrl;
  final ReleasePayloadLoader _loadReleasePayload;
  final ReleaseFileDownloader _downloadReleaseFile;

  AppUpdateState _state = AppUpdateState.initial();

  AppUpdateState get state => _state;

  Future<AppUpdateState> checkForUpdates({
    required AppVersionInfo currentVersion,
  }) async {
    _state = _state.copyWith(
      status: AppUpdateStatus.checking,
      message: 'checking',
      currentVersion: currentVersion.version,
      currentBuildNumber: currentVersion.buildNumber,
      isUpdateAvailable: false,
      downloadProgress: 0,
      clearDownloadedFilePath: true,
      downloadedBytes: 0,
    );

    try {
      final payload = await _loadReleasePayload(
        Uri.parse(
          '${_normalizeBaseUrl(apiBaseUrl)}/api/public/softwares/$softwareSlug/releases/latest',
        ),
      );
      if (payload['success'] != true || payload['data'] is! Map) {
        throw StateError(payload['error']?.toString() ?? 'Invalid release payload');
      }

      final latestRelease = _normalizeRelease(
        Map<String, dynamic>.from(payload['data'] as Map),
      );
      final currentRelease = AppRelease(
        version: currentVersion.version,
        buildNumber: currentVersion.buildNumber,
        downloadUrl: '',
      );
      final isUpdateAvailable =
          compareReleaseVersions(latestRelease, currentRelease) > 0;

      _state = _state.copyWith(
        status: isUpdateAvailable
            ? AppUpdateStatus.available
            : AppUpdateStatus.upToDate,
        message: isUpdateAvailable ? 'available' : 'current',
        latestRelease: latestRelease,
        isUpdateAvailable: isUpdateAvailable,
      );
    } catch (error) {
      _state = _state.copyWith(
        status: AppUpdateStatus.error,
        message: error.toString(),
        isUpdateAvailable: false,
      );
    }

    return _state;
  }

  Future<AppUpdateState> downloadUpdate({
    required AppRelease release,
    AppDownloadOption? selectedOption,
    void Function(AppUpdateState state)? onStateChanged,
  }) async {
    _state = _state.copyWith(
      status: AppUpdateStatus.downloading,
      message: 'downloading',
      latestRelease: release,
      isUpdateAvailable: true,
      downloadProgress: 0,
      clearDownloadedFilePath: true,
      downloadedBytes: 0,
    );
    onStateChanged?.call(_state);

    try {
      final selectedDownloadUrl =
          (selectedOption?.url.trim().isNotEmpty ?? false)
              ? selectedOption!.url
              : release.downloadUrl;
      final downloadedFile = await _downloadReleaseFile(
        Uri.parse(selectedDownloadUrl),
        _buildDownloadFileName(release, selectedDownloadUrl),
        (receivedBytes, totalBytes) {
          final progress = totalBytes <= 0
              ? 0
              : ((receivedBytes / totalBytes) * 100).round().clamp(0, 100);
          _state = _state.copyWith(downloadProgress: progress);
          onStateChanged?.call(_state);
        },
      );

      _state = _state.copyWith(
        status: AppUpdateStatus.readyToInstall,
        message: 'ready',
        downloadProgress: 100,
        downloadedFilePath: downloadedFile.filePath,
        downloadedBytes: downloadedFile.bytes.length,
      );
      onStateChanged?.call(_state);
    } catch (error) {
      _state = _state.copyWith(
        status: AppUpdateStatus.error,
        message: error.toString(),
        downloadProgress: 0,
        clearDownloadedFilePath: true,
        downloadedBytes: 0,
      );
      onStateChanged?.call(_state);
    }

    return _state;
  }

  AppRelease _normalizeRelease(Map<String, dynamic> rawRelease) {
    final version = (rawRelease['version'] ?? '').toString().trim();
    if (version.isEmpty) {
      throw StateError('Latest release payload is missing version');
    }

    final buildNumber =
        int.tryParse(
          (rawRelease['build_number'] ?? rawRelease['buildNumber'] ?? 0)
              .toString(),
        ) ??
        0;
    final explicitDownloadUrl =
        (rawRelease['download_url'] ??
                rawRelease['downloadUrl'] ??
                rawRelease['file_url'] ??
                rawRelease['fileUrl'])
            ?.toString()
            .trim();
    final resolvedPrimaryDownloadUrl = _resolveDownloadUrl(explicitDownloadUrl);
    final normalizedPrimaryDownloadUrl =
        resolvedPrimaryDownloadUrl.isNotEmpty
        ? resolvedPrimaryDownloadUrl
        : _resolveDownloadUrl('/api/public/download/$softwareSlug/latest');

    return AppRelease(
      version: version,
      buildNumber: buildNumber,
      downloadUrl: normalizedPrimaryDownloadUrl,
      downloadOptions: _normalizeDownloadOptions(
        rawRelease,
        primaryDownloadUrl: normalizedPrimaryDownloadUrl,
      ),
      changelog: (rawRelease['changelog'] ?? '').toString(),
    );
  }

  List<AppDownloadOption> _normalizeDownloadOptions(
    Map<String, dynamic> rawRelease,
    {required String primaryDownloadUrl,}
  ) {
    final options = <AppDownloadOption>[];
    final seenUrls = <String>{};
    final rawSources =
        rawRelease['download_sources'] is List ? rawRelease['download_sources'] as List : const [];
    final rawUrls =
        rawRelease['download_urls'] is List ? rawRelease['download_urls'] as List : const [];

    _appendDownloadOption(options, seenUrls, primaryDownloadUrl, '默认安装包');

    for (final source in rawSources.whereType<Map>()) {
      final resolvedUrl = _resolveDownloadUrl(
        (source['url'] ?? source['download_url'] ?? source['downloadUrl'])
            ?.toString(),
      );
      _appendDownloadOption(
        options,
        seenUrls,
        resolvedUrl,
        (source['name'] ?? source['label'])?.toString() ?? '',
      );
    }

    for (final rawUrl in rawUrls) {
      final resolvedUrl = _resolveDownloadUrl(rawUrl?.toString());
      _appendDownloadOption(options, seenUrls, resolvedUrl, '');
    }

    return options;
  }

  void _appendDownloadOption(
    List<AppDownloadOption> options,
    Set<String> seenUrls,
    String resolvedUrl,
    String label,
  ) {
    if (resolvedUrl.isEmpty || seenUrls.contains(resolvedUrl)) {
      return;
    }

    final host = _extractHost(resolvedUrl);
    options.add(
      AppDownloadOption(
        url: resolvedUrl,
        label: label.trim().isNotEmpty ? label.trim() : (host.isNotEmpty ? host : resolvedUrl),
        host: host,
      ),
    );
    seenUrls.add(resolvedUrl);
  }

  String _resolveDownloadUrl(String? rawUrl) {
    final normalized = (rawUrl ?? '').trim();
    if (normalized.isEmpty) {
      return '';
    }

    final resolvedUri = Uri.tryParse(
      Uri.parse('${_normalizeBaseUrl(apiBaseUrl)}/').resolve(normalized).toString(),
    );
    return resolvedUri?.toString() ?? normalized;
  }

  String _extractHost(String downloadUrl) {
    final uri = Uri.tryParse(downloadUrl);
    if (uri == null) {
      return '';
    }
    if (uri.hasPort) {
      return '${uri.host}:${uri.port}';
    }
    return uri.host;
  }

  String _buildDownloadFileName(AppRelease release, String downloadUrl) {
    final downloadUri = Uri.tryParse(downloadUrl);
    var extension = '.apk';
    final pathSegments = downloadUri?.pathSegments ?? const <String>[];
    if (pathSegments.isNotEmpty) {
      final fileName = pathSegments.last;
      final dotIndex = fileName.lastIndexOf('.');
      if (dotIndex >= 0) {
        extension = fileName.substring(dotIndex);
      }
    }

    return '$softwareSlug-${release.version}-build-${release.buildNumber}$extension';
  }
}

String _normalizeBaseUrl(String apiBaseUrl) {
  final raw = apiBaseUrl.trim();
  if (raw.endsWith('/')) {
    return raw.substring(0, raw.length - 1);
  }
  return raw;
}

List<int> _parseVersion(String version) {
  final match = RegExp(r'^\d+\.\d+\.\d+$').hasMatch(version);
  if (!match) {
    throw StateError('Invalid version: $version');
  }
  return version.split('.').map(int.parse).toList(growable: false);
}

Future<Map<String, dynamic>> _defaultLoadReleasePayload(Uri uri) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(uri);
    final response = await request.close();
    final content = await utf8.decodeStream(response);
    final contentTypeHeader =
        response.headers.value(HttpHeaders.contentTypeHeader) ?? 'unknown';
    final normalizedContentType = contentTypeHeader.toLowerCase();
    final isJsonResponse = normalizedContentType.contains('application/json');

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Unexpected update response: HTTP ${response.statusCode} ($contentTypeHeader)',
      );
    }

    if (!isJsonResponse) {
      throw StateError(
        'Unexpected update response: HTTP ${response.statusCode} ($contentTypeHeader)',
      );
    }

    final decoded = jsonDecode(content);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('Invalid JSON payload');
    }
    return decoded;
  } finally {
    client.close(force: true);
  }
}

Future<DownloadedUpdateFile> _defaultDownloadReleaseFile(
  Uri uri,
  String fileName,
  void Function(int receivedBytes, int totalBytes) onProgress,
) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(uri);
    final response = await request.close();
    final totalBytes = response.contentLength;
    final file = File('${Directory.systemTemp.path}${Platform.pathSeparator}$fileName');
    if (await file.exists()) {
      await file.delete();
    }

    final sink = file.openWrite();
    final collected = BytesBuilder(copy: false);
    var receivedBytes = 0;

    try {
      await for (final chunk in response) {
        sink.add(chunk);
        collected.add(chunk);
        receivedBytes += chunk.length;
        onProgress(receivedBytes, totalBytes);
      }
    } finally {
      await sink.flush();
      await sink.close();
    }

    return DownloadedUpdateFile(
      filePath: file.path,
      bytes: collected.takeBytes(),
    );
  } finally {
    client.close(force: true);
  }
}
