import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

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
    this.fileSize,
    this.checksumSha256,
  });

  final String version;
  final int buildNumber;
  final String downloadUrl;
  final List<AppDownloadOption> downloadOptions;
  final String changelog;
  final int? fileSize;
  final String? checksumSha256;
}

class DownloadedUpdateFile {
  const DownloadedUpdateFile({
    required this.filePath,
    required this.size,
  });

  final String filePath;
  final int size;
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

      if (isUpdateAvailable) {
        final cachedFile = await _findCachedReleaseFile(latestRelease);
        if (cachedFile != null) {
          _state = _state.copyWith(
            status: AppUpdateStatus.readyToInstall,
            message: 'ready',
            latestRelease: latestRelease,
            isUpdateAvailable: true,
            downloadProgress: 100,
            downloadedFilePath: cachedFile.path,
            downloadedBytes: await cachedFile.length(),
          );
          return _state;
        }
      }

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

      await _verifyDownloadedReleaseFile(release, downloadedFile);

      _state = _state.copyWith(
        status: AppUpdateStatus.readyToInstall,
        message: 'ready',
        downloadProgress: 100,
        downloadedFilePath: downloadedFile.filePath,
        downloadedBytes: downloadedFile.size,
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

  /// 下载完成后校验安装包：优先比对服务端声明的文件大小，再校验 SHA-256。
  /// 校验失败时删除损坏文件并抛出异常，避免把损坏的 APK 交给系统安装器。
  Future<void> _verifyDownloadedReleaseFile(
    AppRelease release,
    DownloadedUpdateFile downloadedFile,
  ) async {
    final apkFile = File(downloadedFile.filePath);
    final expectedSize = release.fileSize;
    if (expectedSize != null && expectedSize > 0) {
      final actualSize = downloadedFile.size > 0
          ? downloadedFile.size
          : (await apkFile.exists() ? await apkFile.length() : 0);
      if (actualSize != expectedSize) {
        await _deleteQuietly(apkFile);
        throw StateError(
          '安装包下载不完整（$actualSize/$expectedSize 字节），请重新下载',
        );
      }
    }
    await _verifyChecksum(apkFile, release.checksumSha256);
  }

  /// 查找上一次下载、且通过校验的安装包，避免安装失败后被迫重新下载。
  Future<File?> _findCachedReleaseFile(AppRelease release) async {
    final expectedSize = release.fileSize;
    if (expectedSize == null || expectedSize <= 0) {
      return null;
    }
    final fileName = _buildDownloadFileName(release, release.downloadUrl);
    final cachedFile = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}$fileName',
    );
    if (!await cachedFile.exists()) {
      return null;
    }
    if (await cachedFile.length() != expectedSize) {
      await _deleteQuietly(cachedFile);
      return null;
    }
    try {
      await _verifyChecksum(cachedFile, release.checksumSha256);
    } on Exception {
      return null;
    }
    return cachedFile;
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

    final rawFileSize = rawRelease['file_size'] ?? rawRelease['fileSize'];
    final fileSize = rawFileSize == null
        ? null
        : int.tryParse(rawFileSize.toString());
    final checksum =
        (rawRelease['checksum_sha256'] ?? rawRelease['checksumSha256'])
            ?.toString()
            .trim();
    final checksumSha256 =
        (checksum == null || checksum.isEmpty) ? null : checksum;

    return AppRelease(
      version: version,
      buildNumber: buildNumber,
      downloadUrl: normalizedPrimaryDownloadUrl,
      downloadOptions: _normalizeDownloadOptions(
        rawRelease,
        primaryDownloadUrl: normalizedPrimaryDownloadUrl,
      ),
      changelog: (rawRelease['changelog'] ?? '').toString(),
      fileSize: fileSize,
      checksumSha256: checksumSha256,
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
    var receivedBytes = 0;

    try {
      await for (final chunk in response) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        onProgress(receivedBytes, totalBytes);
      }
    } finally {
      await sink.flush();
      await sink.close();
    }

    return DownloadedUpdateFile(
      filePath: file.path,
      size: receivedBytes,
    );
  } finally {
    client.close(force: true);
  }
}

/// 以流式方式计算文件 SHA-256，避免一次性读入整个安装包。
Future<String> _computeSha256(File file) async {
  final digestSink = _DigestSink();
  final byteSink = sha256.startChunkedConversion(digestSink);
  await for (final chunk in file.openRead()) {
    byteSink.add(chunk);
  }
  byteSink.close();
  return digestSink.digest!.toString();
}

class _DigestSink implements Sink<Digest> {
  Digest? digest;

  @override
  void add(Digest data) {
    digest = data;
  }

  @override
  void close() {}
}

/// 服务端声明了 SHA-256 时逐块校验下载内容，防止把损坏的安装包交给系统安装器。
Future<void> _verifyChecksum(File file, String? expectedSha256) async {
  final expected = (expectedSha256 ?? '').trim().toLowerCase();
  if (expected.isEmpty) {
    return;
  }
  final actual = await _computeSha256(file);
  if (actual != expected) {
    await _deleteQuietly(file);
    throw StateError('安装包校验失败（SHA-256 不匹配），已删除损坏文件，请重新下载');
  }
}

Future<void> _deleteQuietly(File file) async {
  try {
    if (await file.exists()) {
      await file.delete();
    }
  } catch (_) {
    // 清理失败不影响主流程，缓存复用前还会重新校验。
  }
}
