const { EventEmitter } = require('node:events');
const fs = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');

function normalizeBaseUrl(apiBaseUrl) {
  const raw = String(apiBaseUrl || '').trim();
  if (!raw) {
    throw new Error('apiBaseUrl is required');
  }
  return raw.endsWith('/') ? raw.slice(0, -1) : raw;
}

function resolveDownloadUrl(downloadUrl, apiBaseUrl) {
  const normalized = String(downloadUrl || '').trim();
  if (!normalized) {
    return '';
  }

  try {
    return new URL(normalized, `${apiBaseUrl}/`).toString();
  } catch (_) {
    return normalized;
  }
}

function extractHostName(downloadUrl) {
  const normalized = String(downloadUrl || '').trim();
  if (!normalized) {
    return '';
  }

  try {
    return new URL(normalized).host;
  } catch (_) {
    return '';
  }
}

function buildDownloadOption(downloadUrl, label) {
  const url = String(downloadUrl || '').trim();
  if (!url) {
    return null;
  }

  const host = extractHostName(url);
  const normalizedLabel = String(label || '').trim() || host || url;
  return {
    url,
    label: normalizedLabel,
    host,
  };
}

function appendDownloadOption(options, seenUrls, downloadUrl, label) {
  const option = buildDownloadOption(downloadUrl, label);
  if (!option) {
    return;
  }

  if (seenUrls.has(option.url)) {
    return;
  }

  seenUrls.add(option.url);
  options.push(option);
}

function normalizeDownloadOptions(rawRelease, apiBaseUrl) {
  const options = [];
  const seenUrls = new Set();
  const primaryDownloadUrl = resolveDownloadUrl(
    rawRelease?.download_url ??
      rawRelease?.downloadUrl ??
      rawRelease?.file_url ??
      rawRelease?.fileUrl ??
      '',
    apiBaseUrl
  );
  const downloadSources = Array.isArray(rawRelease?.download_sources)
    ? rawRelease.download_sources
    : [];
  const downloadUrls = Array.isArray(rawRelease?.download_urls)
    ? rawRelease.download_urls
    : [];

  appendDownloadOption(options, seenUrls, primaryDownloadUrl, '默认安装包');

  for (const source of downloadSources) {
    const resolvedUrl = resolveDownloadUrl(
      source?.url ?? source?.download_url ?? source?.downloadUrl,
      apiBaseUrl
    );
    appendDownloadOption(options, seenUrls, resolvedUrl, source?.name ?? source?.label);
  }

  for (const rawUrl of downloadUrls) {
    const resolvedUrl = resolveDownloadUrl(rawUrl, apiBaseUrl);
    appendDownloadOption(options, seenUrls, resolvedUrl, '');
  }

  return options;
}

function parseVersion(version) {
  const normalized = String(version || '').trim();
  if (!/^\d+\.\d+\.\d+$/.test(normalized)) {
    throw new Error(`Invalid version: ${version}`);
  }
  return normalized.split('.').map((part) => Number(part));
}

function sanitizeFileName(fileName) {
  const normalized = String(fileName || '').trim();
  if (!normalized) {
    return '';
  }

  const baseName = normalized.replace(/^.*[\\/]/, '').trim();
  if (!baseName) {
    return '';
  }

  return baseName.replace(/[<>:"|?*]/g, '_');
}

function parseContentDispositionFileName(headerValue) {
  const normalized = String(headerValue || '').trim();
  if (!normalized) {
    return '';
  }

  const utf8Match = normalized.match(/filename\*\s*=\s*([^;]+)/i);
  if (utf8Match) {
    const rawValue = utf8Match[1].trim().replace(/^"(.*)"$/, '$1');
    const encodedFileName = rawValue.replace(/^utf-8''/i, '');
    try {
      const decoded = decodeURIComponent(encodedFileName);
      const sanitized = sanitizeFileName(decoded);
      if (sanitized) {
        return sanitized;
      }
    } catch (_) {
      // Fall back to filename= parsing below.
    }
  }

  const fileNameMatch = normalized.match(/filename\s*=\s*("?)([^";]+)\1/i);
  if (!fileNameMatch) {
    return '';
  }

  return sanitizeFileName(fileNameMatch[2]);
}

function compareReleaseVersions(left, right) {
  const leftParts = parseVersion(left.version);
  const rightParts = parseVersion(right.version);

  for (let index = 0; index < leftParts.length; index += 1) {
    if (leftParts[index] > rightParts[index]) {
      return 1;
    }
    if (leftParts[index] < rightParts[index]) {
      return -1;
    }
  }

  const leftBuildNumber = Number(left.buildNumber || 0);
  const rightBuildNumber = Number(right.buildNumber || 0);
  if (leftBuildNumber > rightBuildNumber) {
    return 1;
  }
  if (leftBuildNumber < rightBuildNumber) {
    return -1;
  }
  return 0;
}

class DesktopUpdateService extends EventEmitter {
  constructor({
    appVersion,
    appBuildNumber = 1,
    softwareSlug,
    apiBaseUrl,
    fetchImpl = global.fetch,
    fsImpl = fs,
    osImpl = os,
    pathImpl = path,
    shellImpl = { openPath: async () => '' },
  }) {
    super();
    this.appVersion = String(appVersion || '').trim();
    this.appBuildNumber = Number(appBuildNumber || 0);
    this.softwareSlug = String(softwareSlug || '').trim();
    this.apiBaseUrl = normalizeBaseUrl(apiBaseUrl);
    this.fetchImpl = fetchImpl;
    this.fsImpl = fsImpl;
    this.osImpl = osImpl;
    this.pathImpl = pathImpl;
    this.shellImpl = shellImpl;
    this.activeDownloadPromise = null;
    this.state = {
      status: 'idle',
      message: '',
      isUpdateAvailable: false,
      checkedAt: null,
      latestRelease: null,
      currentVersion: this.appVersion,
      currentBuildNumber: this.appBuildNumber,
      downloadProgress: 0,
      downloadedFilePath: null,
    };
  }

  getState() {
    return {
      ...this.state,
      latestRelease: this.state.latestRelease
        ? { ...this.state.latestRelease }
        : null,
    };
  }

  async checkForUpdates() {
    this.#setState({
      status: 'checking',
      message: 'Checking for updates',
      isUpdateAvailable: false,
      downloadProgress: 0,
    });

    try {
      const response = await this.fetchImpl(
        `${this.apiBaseUrl}/api/public/softwares/${this.softwareSlug}/releases/latest`
      );
      if (!response || !response.ok) {
        throw new Error(`Update request failed with status ${response?.status ?? 'unknown'}`);
      }

      const payload = await response.json();
      if (!payload || payload.success !== true || !payload.data) {
        throw new Error(payload?.error || 'Update payload is invalid');
      }

      const latestRelease = this.#normalizeRelease(payload.data);
      const currentRelease = {
        version: this.appVersion,
        buildNumber: this.appBuildNumber,
      };
      const isUpdateAvailable =
        compareReleaseVersions(latestRelease, currentRelease) > 0;

      this.#setState({
        status: isUpdateAvailable ? 'available' : 'current',
        message: isUpdateAvailable ? 'Update available' : 'Already up to date',
        isUpdateAvailable,
        checkedAt: Date.now(),
        latestRelease,
      });
    } catch (error) {
      this.#setState({
        status: 'error',
        message: error instanceof Error ? error.message : String(error),
        isUpdateAvailable: false,
        checkedAt: Date.now(),
      });
    }

    return this.getState();
  }

  async downloadUpdate(selectedDownloadUrl) {
    if (this.activeDownloadPromise) {
      throw new Error('A download already in progress');
    }
    if (!this.state.latestRelease || !this.state.isUpdateAvailable) {
      throw new Error('No update is available to download');
    }

    this.activeDownloadPromise = this.#downloadUpdateInternal(selectedDownloadUrl);
    try {
      await this.activeDownloadPromise;
    } finally {
      this.activeDownloadPromise = null;
    }

    return this.getState();
  }

  #normalizeRelease(rawRelease) {
    const version = String(rawRelease.version || '').trim();
    if (!version) {
      throw new Error('Latest release payload is missing version');
    }

    const buildNumber = Number(
      rawRelease.build_number ?? rawRelease.buildNumber ?? 0
    );
    const releaseId = rawRelease.id ?? rawRelease.releaseId ?? null;
    const explicitDownloadUrl =
      rawRelease.download_url ??
      rawRelease.downloadUrl ??
      rawRelease.file_url ??
      rawRelease.fileUrl ??
      null;
    const normalizedPrimaryDownloadUrl =
      resolveDownloadUrl(explicitDownloadUrl, this.apiBaseUrl) ||
      `${this.apiBaseUrl}/api/public/download/${this.softwareSlug}/latest`;

    return {
      id: releaseId,
      version,
      buildNumber: Number.isFinite(buildNumber) ? buildNumber : 0,
      changelog: rawRelease.changelog ?? '',
      downloadUrl: normalizedPrimaryDownloadUrl,
      downloadOptions: normalizeDownloadOptions(
        {
          ...rawRelease,
          download_url: normalizedPrimaryDownloadUrl,
        },
        this.apiBaseUrl
      ),
      raw: rawRelease,
    };
  }

  #setState(patch) {
    this.state = {
      ...this.state,
      ...patch,
    };
    this.emit('state-change', this.getState());
  }

  async #downloadUpdateInternal(selectedDownloadUrl) {
    const latestRelease = this.state.latestRelease;
    const downloadUrl = this.#resolveDownloadRequestUrl(latestRelease, selectedDownloadUrl);
    let targetPath = this.#buildDownloadTargetPath(latestRelease, downloadUrl);

    this.#setState({
      status: 'downloading',
      message: 'Downloading update',
      downloadProgress: 0,
      downloadedFilePath: null,
    });

    try {
      await this.fsImpl.mkdir(this.pathImpl.dirname(targetPath), { recursive: true });

      const response = await this.fetchImpl(downloadUrl);
      if (!response || !response.ok) {
        throw new Error(`Download request failed with status ${response?.status ?? 'unknown'}`);
      }

      targetPath = this.#buildDownloadTargetPath(latestRelease, downloadUrl, response);
      const content = await this.#readResponseContent(response);
      await this.fsImpl.writeFile(targetPath, content);

      const openResult = await this.shellImpl.openPath(targetPath);
      if (openResult) {
        throw new Error(openResult);
      }

      this.#setState({
        status: 'ready',
        message: 'Update downloaded',
        downloadProgress: 100,
        downloadedFilePath: targetPath,
      });
    } catch (error) {
      if (targetPath) {
        await this.fsImpl.rm(targetPath, { force: true }).catch(() => {});
      }
      this.#setState({
        status: 'error',
        message: error instanceof Error ? error.message : String(error),
        downloadProgress: 0,
        downloadedFilePath: null,
      });
    }
  }

  #resolveDownloadRequestUrl(latestRelease, selectedDownloadUrl) {
    const normalizedSelectedUrl = String(selectedDownloadUrl || '').trim();
    if (normalizedSelectedUrl) {
      return normalizedSelectedUrl;
    }
    return latestRelease.downloadUrl;
  }

  #buildDownloadTargetPath(latestRelease, downloadUrl, response) {
    const fileName = this.#buildDownloadFileName(latestRelease, downloadUrl, response);
    return this.pathImpl.join(
      this.osImpl.tmpdir(),
      `${this.softwareSlug}-updates`,
      fileName
    );
  }

  #buildDownloadFileName(latestRelease, downloadUrl, response) {
    const responseFileName = this.#resolveResponseFileName(response);
    if (responseFileName) {
      return responseFileName;
    }

    let extension = '.bin';
    try {
      const parsedUrl = new URL(downloadUrl);
      const extensionFromUrl = this.pathImpl.extname(parsedUrl.pathname);
      if (extensionFromUrl) {
        extension = extensionFromUrl;
      }
    } catch (_) {
      // Keep fallback extension.
    }

    return `${this.softwareSlug}-${latestRelease.version}-build-${latestRelease.buildNumber}${extension}`;
  }

  #resolveResponseFileName(response) {
    const contentDisposition = response?.headers?.get?.('content-disposition');
    const fileNameFromHeader = parseContentDispositionFileName(contentDisposition);
    if (fileNameFromHeader) {
      return fileNameFromHeader;
    }

    const responseUrl = String(response?.url || '').trim();
    if (!responseUrl) {
      return '';
    }

    try {
      const parsedUrl = new URL(responseUrl);
      return sanitizeFileName(this.pathImpl.basename(parsedUrl.pathname));
    } catch (_) {
      return sanitizeFileName(this.pathImpl.basename(responseUrl));
    }
  }

  async #readResponseContent(response) {
    const totalBytes = Number(response.headers?.get?.('content-length') || 0);
    const chunks = [];
    let downloadedBytes = 0;

    if (response.body && response.body[Symbol.asyncIterator]) {
      for await (const chunk of response.body) {
        const buffer = Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk);
        chunks.push(buffer);
        downloadedBytes += buffer.length;
        this.#emitDownloadProgress(downloadedBytes, totalBytes);
      }
      return Buffer.concat(chunks);
    }

    const arrayBuffer = await response.arrayBuffer();
    const content = Buffer.from(arrayBuffer);
    this.#emitDownloadProgress(content.length, totalBytes || content.length);
    return content;
  }

  #emitDownloadProgress(downloadedBytes, totalBytes) {
    if (!totalBytes || totalBytes <= 0) {
      return;
    }
    const progress = Math.max(
      0,
      Math.min(100, Math.round((downloadedBytes / totalBytes) * 100))
    );
    this.#setState({
      downloadProgress: progress,
    });
  }
}

module.exports = {
  DesktopUpdateService,
  compareReleaseVersions,
};
