const repository = 'omerlefaruk/mise-releases';
const button = document.getElementById('download');
const status = document.getElementById('release-status');
const sourceLink = document.getElementById('media-source');

async function latestRelease() {
  try {
    const response = await fetch(`https://api.github.com/repos/${repository}/releases/latest`, {
      headers: { Accept: 'application/vnd.github+json' },
      credentials: 'omit',
      signal: AbortSignal.timeout(10_000),
    });
    if (response.status === 404) {
      status.textContent =
        'The first public release is being prepared. No public installer is available yet.';
      return;
    }
    if (!response.ok) throw new Error('Release information unavailable');
    const release = await response.json();
    const asset = release.assets.find((candidate) =>
      /^Mise-Setup-\d+\.\d+\.\d+-x64\.exe$/u.test(candidate.name),
    );
    const source = release.assets.find((candidate) =>
      /^FFmpeg-\d+\.\d+\.\d+-mise-source\.tar\.gz$/u.test(candidate.name),
    );
    if (!asset || !source || release.draft || release.prerelease)
      throw new Error('No complete stable installer release');
    const url = new URL(asset.browser_download_url);
    const sourceUrl = new URL(source.browser_download_url);
    for (const target of [url, sourceUrl])
      if (
        target.origin !== 'https://github.com' ||
        !target.pathname.startsWith(`/${repository}/releases/download/`)
      )
        throw new Error('Unexpected download location');
    button.href = url.href;
    sourceLink.href = sourceUrl.href;
    button.textContent = 'Download Mise for Windows';
    status.textContent = `${release.tag_name} · ${Math.ceil(asset.size / 1024 / 1024)} MiB · Release notes and checksums are under All releases.`;
  } catch {
    status.textContent =
      'Release information is temporarily unavailable. Use All releases to check downloads directly.';
  }
}

latestRelease();
