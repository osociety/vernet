import { expect, test } from '@playwright/test';

// `firebase/firebase.json` rewrites `**` to `/index.html`, so a missing asset
// answers HTTP 200 with the landing page instead of a 404. Every assertion here
// therefore judges a response by its content type, never by its status.

const ALLOWED_HOSTS = /\.web\.app$/;

// Mirrors `releaseAssetSuffixes` in index.html, but is the check on it: a release
// asset that stops matching CI's naming must fail here rather than 404 for users.
const RELEASE_ASSET_SUFFIXES = {
  macos: '-macos.dmg',
  linux_x64: '-linux-x64.zip',
  linux_arm64: '-linux-arm64.zip',
  windows_x64: '-windows-x64.zip',
  windows_arm64: '-windows-arm64.zip',
};

const contentTypeOf = (response) =>
  (response.headers()['content-type'] ?? '').split(';')[0].trim();

const fellBackToIndex = (response) => contentTypeOf(response) === 'text/html';

/** Same-origin URLs the document references, resolved against the page. */
async function sameOriginReferences(page) {
  const raw = await page.evaluate(() => {
    const found = new Set();
    const add = (value) => {
      if (value) found.add(value.trim());
    };

    for (const el of document.querySelectorAll('img[src], script[src], iframe[src]')) {
      add(el.getAttribute('src'));
    }
    for (const el of document.querySelectorAll('source[src], link[href]')) {
      add(el.getAttribute('src') ?? el.getAttribute('href'));
    }
    for (const el of document.querySelectorAll('source[srcset], img[srcset]')) {
      for (const part of (el.getAttribute('srcset') ?? '').split(',')) {
        add(part.trim().split(/\s+/)[0]);
      }
    }
    for (const el of document.querySelectorAll('[style]')) {
      for (const match of (el.getAttribute('style') ?? '').matchAll(/url\(\s*["']?([^"')]+)/g)) {
        add(match[1]);
      }
    }
    return [...found];
  });

  const pageUrl = new URL(page.url());
  const resolved = [];
  for (const reference of raw) {
    if (/^(data:|blob:|mailto:|javascript:|#)/i.test(reference)) continue;
    let url;
    try {
      url = new URL(reference, pageUrl);
    } catch {
      continue;
    }
    if (url.origin !== pageUrl.origin) continue;
    if (url.pathname === '/' || url.pathname.endsWith('.html')) continue;
    if (!resolved.some((existing) => existing.href === url.href)) resolved.push(url);
  }
  return resolved;
}

test('SITE_URL points at a Firebase-hosted site', async () => {
  const url = new URL(process.env.SITE_URL);
  expect(url.protocol, `SITE_URL must be https, got ${url.protocol}`).toBe('https:');
  expect(url.hostname, `${url.hostname} is not a *.web.app host`).toMatch(ALLOWED_HOSTS);
});

test('landing page renders its headline and download section', async ({ page }) => {
  const response = await page.goto('/');
  expect(response.status()).toBe(200);
  await expect(page).toHaveTitle(/Vernet/);
  await expect(page.locator('.brand')).toContainText(/vernet/i);
  await expect(page.getByRole('heading', { level: 1 }).first()).not.toHaveText('');
  await expect(page.locator('[data-release-platform]').first()).toBeVisible();
});

test('every referenced asset is served as itself, not as the SPA fallback', async ({
  page,
}) => {
  await page.goto('/');
  const references = await sameOriginReferences(page);
  expect(references.length, 'no same-origin assets found to verify').toBeGreaterThan(0);

  const broken = [];
  for (const url of references) {
    const response = await page.request.get(url.pathname + url.search, {
      failOnStatusCode: false,
    });
    if (!response.ok()) {
      broken.push(`${url.pathname} -> HTTP ${response.status()}`);
    } else if (fellBackToIndex(response)) {
      broken.push(`${url.pathname} -> 200 but served as text/html (missing file)`);
    }
  }
  expect(broken, 'Assets that do not resolve as themselves:\n' + broken.join('\n')).toEqual(
    [],
  );
});

test('opengraph preview image and its SVG source are real files', async ({ page }) => {
  await page.goto('/');
  const ogImage = page
    .locator('meta[property="og:image"], meta[name="twitter:image"]')
    .first()
    .getAttribute('content');
  const ogUrl = new URL(await ogImage);
  expect(ogUrl.hostname, 'og:image must not be a bare domain').toMatch(ALLOWED_HOSTS);

  const image = await page.request.get(ogUrl.pathname, { failOnStatusCode: false });
  expect(image.ok()).toBeTruthy();
  expect(contentTypeOf(image), `og:image ${ogUrl.pathname} is not an image`).toMatch(
    /^image\//,
  );
  expect((await image.body()).byteLength, 'og:image is suspiciously small').toBeGreaterThan(
    1000,
  );

  // og-preview.png is rendered from og-preview.svg, which pulls its photographs in
  // by relative href. Those masters are not referenced by index.html, so this is
  // the only place a deleted source image shows up as a broken site asset.
  const svgResponse = await page.request.get('/images/og-preview.svg', {
    failOnStatusCode: false,
  });
  if (!svgResponse.ok() || fellBackToIndex(svgResponse)) {
    test.info().annotations.push({
      type: 'note',
      description: '/images/og-preview.svg is not deployed; skipping its hrefs.',
    });
    return;
  }
  const svg = await svgResponse.text();
  const masters = [...svg.matchAll(/href="([^"]+)"/g)].map((m) => m[1]);
  expect(masters.length).toBeGreaterThan(0);

  const broken = [];
  for (const master of masters) {
    const path = new URL(master, ogUrl.origin + '/images/').pathname;
    const response = await page.request.get(path, { failOnStatusCode: false });
    if (!response.ok() || fellBackToIndex(response)) broken.push(path);
  }
  expect(
    broken,
    'og-preview.svg references source images that are not deployed:\n' + broken.join('\n'),
  ).toEqual([]);
});

test('canonical and social tags never use an unregistered bare domain', async ({
  page,
}) => {
  await page.goto('/');
  const html = await page.content();
  const urls = [...html.matchAll(/https?:\/\/[^\s"'<>)]+/g)].map((m) => m[0]);
  expect(urls.length).toBeGreaterThan(0);

  const bare = urls.filter((value) => {
    try {
      return new URL(value).hostname === 'vernet.app';
    } catch {
      return false;
    }
  });
  expect(bare, 'Links to the unregistered vernet.app domain:\n' + bare.join('\n')).toEqual(
    [],
  );

  for (const [label, selector, attribute] of [
    ['canonical', 'link[rel="canonical"]', 'href'],
    ['og:url', 'meta[property="og:url"]', 'content'],
  ]) {
    const href = await page.locator(selector).first().getAttribute(attribute);
    expect(href, `${label} (${selector}) is missing`).toBeTruthy();
    expect(new URL(href).hostname, `${label} is not on *.web.app`).toMatch(ALLOWED_HOSTS);
  }
});

test('platform download links match the CI release asset naming', async ({ page }) => {
  await page.goto('/');
  const links = page.locator('[data-release-platform]');
  const count = await links.count();
  expect(count, 'no platform download links rendered').toBeGreaterThan(0);

  const problems = [];
  for (let index = 0; index < count; index += 1) {
    const link = links.nth(index);
    const platform = await link.getAttribute('data-release-platform');
    const href = await link.getAttribute('href');
    const suffix = RELEASE_ASSET_SUFFIXES[platform];
    if (!suffix) {
      problems.push(`data-release-platform="${platform}" has no expected asset suffix`);
      continue;
    }
    // The page rewrites these to a concrete asset and silently keeps the
    // /releases/latest fallback when the GitHub API call fails, so both shapes
    // are acceptable; an asset URL that stops matching CI's naming is not.
    const isFallback = href === 'https://github.com/osociety/vernet/releases/latest';
    const assetName =
      /github\.com\/[^/]+\/[^/]+\/releases\/download\/[^/]+\/([^?#]+)$/.exec(href)?.[1];
    if (!isFallback && !assetName) {
      problems.push(`${platform}: unexpected download href ${href}`);
    } else if (assetName && !assetName.toLowerCase().endsWith(suffix)) {
      problems.push(`${platform}: asset ${assetName} does not end with ${suffix}`);
    }
  }
  expect(
    problems,
    'Download links that do not resolve to release assets:\n' + problems.join('\n'),
  ).toEqual([]);
});

test('release history lists the newest stable builds with their artifacts', async ({
  page,
}) => {
  // Unauthenticated GitHub calls are rate limited per IP, and runners share one,
  // so a red suite here would otherwise be a quota report rather than a render
  // report. Probe the same endpoint the page reads: only when it answers is the
  // page expected to have filled itself.
  const probe = await page.request.get(
    'https://api.github.com/repos/osociety/vernet/releases?per_page=100',
  );
  if (!probe.ok()) {
    test.info().annotations.push({
      type: 'note',
      description: `GitHub API answered ${probe.status()}; the page keeps its static fallback.`,
    });
    return;
  }

  await page.goto('/');
  const rows = page.locator('.release-row');
  await expect(rows, 'release history did not render').toHaveCount(10, { timeout: 30_000 });

  const problems = [];
  for (let index = 0; index < 10; index += 1) {
    const row = rows.nth(index);
    const version = (await row.locator('.release-version').textContent()) ?? '';
    if (!/^v\d+\.\d+\.\d+\+\d+$/.test(version)) {
      problems.push(`row ${index} version "${version}" is not a CI tag`);
    }

    // Betas are releases too, and only the stable line belongs on this page.
    const notesHref = await row.locator('.release-page').getAttribute('href');
    if (!notesHref?.startsWith('https://github.com/osociety/vernet/releases/tag/')) {
      problems.push(`row ${index} release link ${notesHref}`);
    }

    const assets = row.locator('.release-asset');
    const count = await assets.count();
    if (count === 0) problems.push(`row ${index} lists no artifacts`);
    for (let asset = 0; asset < count; asset += 1) {
      const href = await assets.nth(asset).getAttribute('href');
      if (!/^https:\/\/github\.com\/[^/]+\/[^/]+\/releases\/download\//.test(href ?? '')) {
        problems.push(`row ${index} asset ${asset} href ${href}`);
      }
    }
  }
  expect(
    problems,
    'Release rows that do not name a CI build:\n' + problems.join('\n'),
  ).toEqual([]);

  const stats = page.locator('#repo-stats');
  await expect(stats, 'repo stats band stayed hidden').toBeVisible();
  for (const key of ['stars', 'forks', 'downloads']) {
    await expect(
      stats.locator(`[data-repo-stat="${key}"]`),
      `stat ${key} never filled`,
    ).toHaveText(/^[\d,]+$/);
  }
});

test('SEO and agent endpoints are real files, not the fallback page', async ({
  request,
}) => {
  const checks = [
    ['/robots.txt', /^text\/plain/],
    ['/sitemap.xml', /(application|text)\/xml/],
    ['/llms.txt', /^text\/plain/],
    ['/.well-known/ard.json', /^application\/json/],
    ['/.well-known/ai-catalog.json', /^application\/json/],
  ];

  for (const [path, expectedType] of checks) {
    const response = await request.get(path, { failOnStatusCode: false });
    expect(response.status(), `${path} did not return 200`).toBe(200);
    expect(
      contentTypeOf(response),
      `${path} was served as ${contentTypeOf(response)}, not ${expectedType} — it is ` +
        `either missing from firebase/public/ or swallowed by the ** rewrite`,
    ).toMatch(expectedType);
    expect((await response.body()).byteLength, `${path} is empty`).toBeGreaterThan(10);
  }

  const robots = await (await request.get('/robots.txt')).text();
  const declaredSitemaps = [...robots.matchAll(/^Sitemap:\s*(\S+)/gim)].map((m) => m[1]);
  expect(declaredSitemaps.length, 'robots.txt declares no sitemap').toBeGreaterThan(0);
  for (const declared of declaredSitemaps) {
    const response = await request.get(new URL(declared).pathname, {
      failOnStatusCode: false,
    });
    expect(
      fellBackToIndex(response),
      `robots.txt advertises ${declared}, which is not deployed`,
    ).toBe(false);
  }

  const sitemap = await (await request.get('/sitemap.xml')).text();
  const locations = [...sitemap.matchAll(/<loc>\s*([^<\s]+)\s*<\/loc>/g)].map((m) => m[1]);
  expect(locations.length, 'sitemap.xml lists no URLs').toBeGreaterThan(0);
  for (const location of locations) {
    expect(
      new URL(location).hostname,
      `sitemap.xml advertises the unregistered host in ${location}`,
    ).toMatch(ALLOWED_HOSTS);
  }
});

test('site copy carries no leftover placeholders', async ({ page }) => {
  await page.goto('/');
  const bodyText = await page.locator('body').innerText();
  for (const needle of ['TODO', 'FIXME', 'Lorem ipsum', 'PLACEHOLDER', 'undefined']) {
    expect(bodyText, `Page copy contains "${needle}"`).not.toContain(needle);
  }
});

test('page boots without script errors', async ({ page }) => {
  const errors = [];
  page.on('pageerror', (error) => errors.push(String(error)));
  // The release-asset lookup is a best-effort third-party call with its own
  // .catch(), and its CDN icons are not ours to police.
  page.on('console', (message) => {
    if (message.type() !== 'error') return;
    if (/api\.github\.com|cdn\.simpleicons\.org/.test(message.text())) return;
    errors.push(message.text());
  });

  await page.goto('/');
  await page.waitForLoadState('networkidle');
  expect(errors, 'Console/page errors on load:\n' + errors.join('\n')).toEqual([]);
});
