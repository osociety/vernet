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

// Mirrors `releaseAssetLabels` in index.html, and is the check on it: the page
// falls back to the raw CI file name for anything the map misses, so a renamed
// artifact has to fail here instead of quietly making the list unreadable.
const RELEASE_ASSET_LABELS = new Set([
  'Android (arm64)',
  'Android (arm 32-bit)',
  'Android (x86_64)',
  'Linux (x64)',
  'Linux (arm64)',
  'macOS (disk image)',
  'macOS (zip)',
  'Windows (x64)',
  'Windows (arm64)',
  'Windows (MSIX bundle)',
]);

const contentTypeOf = (response) =>
  (response.headers()['content-type'] ?? '').split(';')[0].trim();

const fellBackToIndex = (response) => contentTypeOf(response) === 'text/html';

const IS_LOOPBACK = /^(127\.0\.0\.1|localhost|\[::1\])$/;

/**
 * The `**` rewrite and the Cache-Control policy both come from firebase.json, so
 * only a real Hosting channel can be checked for them; a loopback server run
 * over firebase/public would report the harness instead of the site. Every other
 * test in this file has to pass in both places.
 */
const hostedByFirebase = () => !IS_LOOPBACK.test(new URL(process.env.SITE_URL).hostname);

/**
 * `html { scroll-behavior: smooth }` means an anchor jump is still moving by the
 * time the click resolves, so measure only after four frames of no movement. The
 * timer covers a page that never paints a frame at all.
 */
const scrollIsIdle = (page) =>
  page.evaluate(
    () =>
      Promise.race([
        new Promise((resolve) => {
          let last = window.scrollY;
          let still = 0;
          const frame = () => {
            if (window.scrollY === last) still += 1;
            else {
              still = 0;
              last = window.scrollY;
            }
            if (still >= 4) resolve();
            else requestAnimationFrame(frame);
          };
          requestAnimationFrame(frame);
        }),
        new Promise((resolve) => setTimeout(resolve, 3000)),
      ]),
  );

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
  // CI's job sets this from the preview channel it is about to promote, which is
  // what makes a red suite block the deployment. Locally it points at a loopback
  // server, and that would only be a report on the harness.
  test.skip(!hostedByFirebase(), 'SITE_URL is a loopback server, not a Hosting channel');

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

test('the header keeps one line per label and no collisions at any width', async ({
  page,
}) => {
  const problems = [];
  for (const width of [1280, 900, 760, 641, 640, 560, 414, 360]) {
    await page.setViewportSize({ width, height: 800 });
    await page.goto('/');
    const state = await page.evaluate(() => {
      const nav = document.querySelector('header nav.wrap');
      const cta = nav.querySelector('.btn').getBoundingClientRect();
      const links = [...document.querySelectorAll('.nav-links a')];
      const boxes = links.map((link) => link.getBoundingClientRect());
      const overlaps = (a, b) =>
        a.right > b.left + 1 &&
        b.right > a.left + 1 &&
        a.bottom > b.top + 1 &&
        b.bottom > a.top + 1;
      return {
        // A wrapped label measures a second ~17px line inside its 8px padding.
        wrapped: links
          .filter((_, index) => boxes[index].height > 40)
          .map((link) => link.textContent),
        // `white-space: nowrap` keeps a long word inside its box instead of
        // painting it over whatever sits to the right — the old "Download" bug.
        outsideBox: links
          .filter((link) => link.scrollWidth > link.clientWidth + 1)
          .map((link) => link.textContent),
        underCta: links
          .filter((_, index) => overlaps(boxes[index], cta))
          .map((link) => link.textContent),
        offscreen: boxes.some(
          (box) => box.right > document.documentElement.clientWidth + 1,
        ),
        ctaWrapped: cta.height > 40,
      };
    });
    const at = `header at ${width}px`;
    if (state.wrapped.length)
      problems.push(`${at}: wrapped label(s) ${state.wrapped.join(', ')}`);
    if (state.outsideBox.length)
      problems.push(`${at}: label painted outside its box: ${state.outsideBox.join(', ')}`);
    if (state.underCta.length)
      problems.push(`${at}: under the button: ${state.underCta.join(', ')}`);
    if (state.offscreen) problems.push(`${at}: a link runs past the viewport`);
    if (state.ctaWrapped) problems.push(`${at}: the button label wrapped`);
  }
  expect(problems, problems.join('\n')).toEqual([]);
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
      const label = (await assets.nth(asset).textContent()) ?? '';
      if (!RELEASE_ASSET_LABELS.has(label)) {
        problems.push(`row ${index} asset ${asset} reads "${label}", not a familiar name`);
      }
    }
  }

  // Rows collapse, so the newest build is the one that has to answer without a
  // click and the rest are only reachable through their summary.
  await expect(rows.nth(0), 'newest release starts collapsed').toHaveJSProperty('open', true);
  // A closed <details> hides its list with `content-visibility`, which leaves a
  // bounding box behind, so ask the platform's own visibility answer here.
  const collapsed = await rows
    .nth(1)
    .locator('.release-asset')
    .first()
    .evaluate((link) => link.checkVisibility());
  if (collapsed) problems.push('row 1 shows its artifacts while collapsed');

  const second = rows.nth(1);
  await second.locator('.release-version').click();
  await expect(
    second.locator('.release-asset').first(),
    'opening a release did not reveal its artifacts',
  ).toBeVisible();
  await expect(second, 'summary click did not open the row').toHaveJSProperty('open', true);

  // One artifact per line: every entry sits below the one before it.
  const tops = await second
    .locator('.release-asset-item')
    .evaluateAll((items) => items.map((item) => item.getBoundingClientRect().top));
  for (let line = 1; line < tops.length; line += 1) {
    if (tops[line] <= tops[line - 1]) {
      problems.push(`row 1 artifact ${line} shares a line with ${line - 1}`);
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

  // The band is a top-of-page proof, not a footer decoration: it left the
  // open-source card to sit above the feature list, so a future reshuffle that
  // buries it again has to fail here rather than quietly undo the point of it.
  const placement = await page.evaluate(() => {
    const top = (selector) => {
      const el = document.querySelector(selector);
      return el ? el.getBoundingClientRect().top + window.scrollY : -1;
    };
    return {
      stats: top('#repo-stats'),
      features: top('#features'),
      insideOss: Boolean(document.querySelector('.oss #repo-stats')),
    };
  });
  expect(placement.insideOss, 'the stats band moved back into the open-source card').toBe(
    false,
  );
  expect(
    placement.features,
    'the stats band no longer renders above the feature list',
  ).toBeGreaterThan(placement.stats);
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
  page.on('console', (message) => {
    if (message.type() !== 'error') return;
    // The release-asset lookup and its icons are third-party, and a rate-limited
    // GitHub call reaches this handler as a bare "status of 403" — Chromium puts
    // the URL in the message location, never in the text.
    const where = message.text() + (message.location()?.url ?? '');
    if (/api\.github\.com|cdn\.simpleicons\.org/.test(where)) return;
    errors.push(message.text());
  });

  await page.goto('/');
  await page.waitForLoadState('networkidle');
  expect(errors, 'Console/page errors on load:\n' + errors.join('\n')).toEqual([]);
});

// ---------------------------------------------------------------------------
// Content coverage: the blocks a visitor reads, in the order the page tells them
// ---------------------------------------------------------------------------

test('the sections tell the story in the order they were arranged', async ({ page }) => {
  await page.goto('/');
  // An unnamed section is the open-source card: it has no id, only its `.oss` box.
  const order = await page.evaluate(() =>
    [...document.querySelectorAll('main > section')].map(
      (s) => s.id || (s.querySelector('.oss') ? 'oss' : 'anonymous'),
    ),
  );
  expect(order[0], 'the hero must open the page').toBe('top');
  expect(order.filter((id) => id === 'anonymous'), 'a section lost its identity').toEqual([]);

  const at = (name) => {
    const index = order.indexOf(name);
    expect(index, `no <section> named ${name} — expected ${order.join(', ')}`).toBeGreaterThan(
      -1,
    );
    return index;
  };
  expect(
    at('repo-stats'),
    'the GitHub numbers must sit above the feature list, not in a footer',
  ).toBeLessThan(at('features'));
  expect(at('how'), 'how-it-works follows the feature list').toBeGreaterThan(at('features'));
  expect(at('download'), 'the platform picker follows the walkthrough').toBeGreaterThan(at('how'));
  expect(at('releases'), 'release history follows the picker').toBeGreaterThan(at('download'));
  expect(at('demo'), 'the video was moved to the end of the pitch').toBeGreaterThan(
    at('releases'),
  );
  expect(at('oss'), 'the open-source card must stay the closing block').toBeGreaterThan(at('demo'));
});

test('every in-page anchor resolves and lands clear of the sticky header', async ({ page }) => {
  const problems = [];
  let navIds = [];

  for (const width of [1280, 641, 640, 360]) {
    await page.setViewportSize({ width, height: 800 });
    await page.goto('/');
    const state = await page.evaluate(() => {
      const header = document.querySelector('header');
      const fragments = [...document.querySelectorAll('a[href^="#"]')].map((a) =>
        a.getAttribute('href').slice(1),
      );
      return {
        sticky: getComputedStyle(header).position,
        headerHeight: header.getBoundingClientRect().height,
        navIds: [...new Set(fragments)],
        // A fragment with no element beneath it lands the reader nowhere.
        dangling: [...new Set(fragments)].filter((id) => id && !document.getElementById(id)),
        // `scroll-margin-top` is the only thing keeping a jumped-to section from
        // hiding under the sticky header, and the nav stacks into two rows on a
        // narrow screen, which is the clearance the old single-row value lost.
        clearance: [...document.querySelectorAll('header a[href^="#"]')]
          .map((a) => a.getAttribute('href').slice(1))
          .filter((id) => document.getElementById(id))
          .map((id) => ({
            id,
            margin: parseFloat(getComputedStyle(document.getElementById(id)).scrollMarginTop) || 0,
          })),
      };
    });
    navIds = state.navIds;

    const at = `${width}px`;
    expect(state.sticky, `the header at ${at} is not sticky`).toBe('sticky');
    expect(state.dangling, `dead fragment links at ${at}`).toEqual([]);
    expect(state.clearance.length, `no nav targets at ${at}`).toBeGreaterThan(0);
    for (const entry of state.clearance) {
      if (entry.margin < state.headerHeight) {
        problems.push(
          `${at}: #${entry.id} has ${entry.margin}px of clearance under a ${Math.round(state.headerHeight)}px header`,
        );
      }
    }
  }
  expect(problems, problems.join('\n')).toEqual([]);

  await page.setViewportSize({ width: 1280, height: 800 });
  await page.goto('/');
  for (const id of navIds) {
    const link = page.locator(`header a[href="#${id}"]`);
    if (!(await link.count())) continue;
    await link.first().click();
    await scrollIsIdle(page);
    const landed = await page.evaluate((sectionId) => {
      const box = document.getElementById(sectionId).getBoundingClientRect();
      const header = document.querySelector('header').getBoundingClientRect();
      return {
        top: box.top,
        headerBottom: header.bottom,
        viewportHeight: window.innerHeight,
      };
    }, id);
    // Overshoot is not a defect — `scroll-margin-top` is deliberately a little
    // larger than the header — but landing under it, or past the bottom of the
    // window, hides the heading the reader clicked for.
    if (landed.top < landed.headerBottom - 2)
      problems.push(
        `#${id} scrolled ${Math.abs(landed.top - landed.headerBottom).toFixed(0)}px under the header`,
      );
    if (landed.top > landed.viewportHeight - 8)
      problems.push(`#${id} jumped so far the heading is off the bottom of the window`);
  }
  expect(problems, problems.join('\n')).toEqual([]);
});

test('the document is one landmark tree with an unbroken heading order', async ({ page }) => {
  await page.goto('/');
  const doc = await page.evaluate(() => {
    const count = (selector) => document.querySelectorAll(selector).length;
    const clean = (text) => (text ?? '').replace(/\s+/g, ' ').trim();
    const headings = [...document.querySelectorAll('h1, h2, h3, h4, h5, h6')].map((heading) => ({
      level: Number(heading.tagName.slice(1)),
      text: clean(heading.textContent).slice(0, 48),
    }));

    const skips = [];
    let previous = 0;
    for (const heading of headings) {
      if (previous && heading.level > previous + 1) {
        skips.push(`h${previous} -> h${heading.level} at "${heading.text}"`);
      }
      previous = heading.level;
    }

    return {
      lang: document.documentElement.getAttribute('lang'),
      charset: document.characterSet,
      title: document.title,
      mains: count('main'),
      headers: count('body > header'),
      footers: count('body > footer'),
      navs: count('header nav'),
      h1: headings.filter((heading) => heading.level === 1).length,
      first: headings[0]?.level ?? 0,
      headings: headings.length,
      skips,
      // An element that is only an icon needs its name from aria-label or title.
      unnamed: [...document.querySelectorAll('a[href], button')]
        .filter(
          (el) =>
            !clean(el.textContent) &&
            !el.getAttribute('aria-label') &&
            !el.getAttribute('title'),
        )
        .map((el) => `${el.tagName.toLowerCase()}[${el.getAttribute('href') ?? el.type}]`),
      labelledWithoutRole: [...document.querySelectorAll('[aria-label]')]
        .filter((el) => {
          if (['SECTION', 'NAV', 'MAIN', 'ASIDE', 'FORM'].includes(el.tagName)) return false;
          const role = el.getAttribute('role');
          if (role) return false;
          return !['A', 'BUTTON', 'INPUT', 'SELECT', 'TEXTAREA', 'IFRAME', 'IMG'].includes(
            el.tagName,
          );
        })
        .map((el) => `${el.tagName.toLowerCase()}.${el.className}`),
    };
  });

  expect(doc.lang, 'the page must declare its language').toBe('en');
  expect(doc.charset, 'the served charset must match <meta charset>').toBe('UTF-8');
  expect(doc.title).toMatch(/Vernet/);
  expect(doc.mains, 'more than one <main> means two documents on one page').toBe(1);
  expect(doc.headers, 'there must be exactly one body header').toBe(1);
  expect(doc.footers, 'there must be exactly one body footer').toBe(1);
  expect(doc.navs, 'the header must carry the nav').toBe(1);
  expect(doc.h1, 'exactly one h1 describes the page').toBe(1);
  expect(doc.first, 'the document must open on its h1').toBe(1);
  expect(doc.headings, 'the page has no headings').toBeGreaterThan(6);
  expect(doc.skips, 'heading levels must not skip a step:\n' + doc.skips.join('\n')).toEqual([]);
  expect(doc.unnamed, 'icon-only controls need an accessible name:\n' + doc.unnamed.join('\n')).toEqual(
    [],
  );
  expect(
    doc.labelledWithoutRole,
    'aria-label on a plain element is dropped by assistive tech:\n' +
      doc.labelledWithoutRole.join('\n'),
  ).toEqual([]);
});

test('the hero names the real packages and flags the ad-supported build', async ({ page }) => {
  await page.goto('/');
  const hero = page.locator('.hero');
  await expect(hero.locator('.eyebrow')).toHaveText(/free .*open source/i);
  await expect(hero.locator('h1')).toContainText('network');
  await expect(hero.locator('.sub')).toContainText(/speed, port, ping, and DNS/i);

  const buttons = await hero
    .locator('.cta-row a')
    .evaluateAll((links) =>
      links.map((link) => ({ text: link.textContent.trim(), href: link.getAttribute('href') })),
    );
  expect(buttons.length, 'the hero lost its call to action').toBeGreaterThan(1);
  const play = buttons.find((b) => /google play/i.test(b.text));
  const fdroid = buttons.find((b) => /f-droid/i.test(b.text));
  expect(play, 'no Google Play button').toBeTruthy();
  expect(fdroid, 'no F-Droid button').toBeTruthy();
  // The store build is the `store` flavor, so its application id differs from the
  // one F-Droid ships. Swapping them would send Play users to the ad-free build.
  expect(new URL(play.href).searchParams.get('id'), 'Play build is not the store flavor')
    .toBe('org.fsociety.vernet.store');
  expect(new URL(fdroid.href).pathname, 'F-Droid package').toContain('/packages/org.fsociety.vernet');
  expect(new URL(fdroid.href).pathname).not.toContain('.store');

  const pills = await hero
    .locator('.store-row .store-pill')
    .evaluateAll((list) =>
      list.map((pill) => ({
        name: pill.textContent.replace(/\s+/g, ' ').trim(),
        href: pill.getAttribute('href'),
        tag: pill.tagName.toLowerCase(),
        soon: pill.classList.contains('soon'),
      })),
    );
  expect(pills.length, 'the hero platform row is empty').toBeGreaterThanOrEqual(4);
  const ios = pills.filter((pill) => /^iOS/.test(pill.name));
  expect(ios.length, 'iOS is missing from the platform row').toBe(1);
  expect(ios[0].soon, 'iOS still claims to ship').toBe(true);
  expect(ios[0].href, 'iOS is coming soon, so it must not be a download link').toBeNull();
  for (const pill of pills.filter((p) => !p.soon)) {
    expect(pill.tag, `${pill.name} is not clickable`).toBe('a');
    expect(new URL(pill.href).protocol, `${pill.name} is not https`).toBe('https:');
  }

  await expect(
    hero.locator('p').filter({ hasText: /ads/i }).first(),
    'the page must disclose that the Play build carries ads',
  ).toContainText(/ad-free/i);
  await expect(hero.locator('.screens img')).not.toHaveCount(0);
});

test('the feature carousel documents each tool once and pages one card per step', async ({
  page,
}) => {
  // Reduced motion keeps the carousel from auto-advancing underneath the clicks
  // and makes each step land in one frame instead of an animation.
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await page.goto('/');

  const carousel = page.locator('#feature-carousel');
  await expect(carousel).toHaveAttribute('role', 'region');
  await expect(carousel).toHaveAttribute('aria-roledescription', 'carousel');
  await expect(carousel).toHaveAttribute('aria-label', /feature/i);
  await expect(carousel).toHaveAttribute('tabindex', '0');

  const titles = await carousel.locator('.card h3').allTextContents();
  expect(titles.length, 'the feature carousel has no cards').toBeGreaterThanOrEqual(10);
  expect(new Set(titles.map((t) => t.trim())).size, 'duplicate feature titles').toBe(titles.length);
  const thin = await carousel
    .locator('.card')
    .evaluateAll((cards) => cards.filter((card) => !card.querySelector('h3') || !card.querySelector('p')).length);
  expect(thin, 'a feature card has a heading but no description').toBe(0);
  const unlabelledIcons = await carousel
    .locator('.card .icon svg')
    .evaluateAll((icons) => icons.filter((icon) => icon.getAttribute('aria-hidden') !== 'true').length);
  expect(unlabelledIcons, 'a card icon is not marked decorative').toBe(0);

  const prev = page.locator('[data-carousel-step="-1"]');
  const next = page.locator('[data-carousel-step="1"]');
  for (const button of [prev, next]) {
    await expect(button).toHaveAttribute('aria-controls', 'feature-carousel');
    await expect(button).toHaveAttribute('aria-label', /feature/i);
  }
  await expect(prev, 'the previous arrow must start dead').toBeDisabled();
  await expect(next).toBeEnabled();

  const geometry = await carousel.evaluate((el) => ({
    paged: el.scrollWidth > el.clientWidth + 1,
    start: el.scrollLeft,
    step: (() => {
      const card = el.querySelector('.card');
      const gap = parseFloat(getComputedStyle(el).columnGap) || 0;
      return card.getBoundingClientRect().width + gap;
    })(),
  }));
  expect(geometry.paged, 'the carousel has nothing to page through').toBe(true);
  expect(geometry.start, 'the carousel did not start at the first card').toBe(0);

  await next.click();
  const after = await carousel.evaluate((el) => el.scrollLeft);
  expect(after, 'the next arrow did not move the carousel').toBeGreaterThan(0);
  expect(after, `one step moved ${Math.round(after)}px, a card is ${Math.round(geometry.step)}px`)
    .toBeLessThanOrEqual(geometry.step + 8);
  await expect(prev, 'the previous arrow stayed dead after paging forward').toBeEnabled();

  await prev.click();
  await expect
    .poll(() => carousel.evaluate((el) => el.scrollLeft), { timeout: 5000 })
    .toBe(0);
  await expect(prev, 'the previous arrow revived at the start').toBeDisabled();

  // The 1500ms rotation timer must not run when the reader asked for stillness.
  const still = await carousel.evaluate((el) => el.scrollLeft);
  await page.waitForTimeout(2400);
  expect(await carousel.evaluate((el) => el.scrollLeft), 'the carousel auto-rotated anyway').toBe(
    still,
  );
});

test('each walkthrough block pairs a heading, a screenshot and a checklist', async ({ page }) => {
  await page.goto('/');
  const blocks = page.locator('#how .showcase');
  const count = await blocks.count();
  expect(count, 'the walkthrough lost a block').toBeGreaterThanOrEqual(3);

  const problems = [];
  for (let index = 0; index < count; index += 1) {
    const block = blocks.nth(index);
    const heading = await block.locator('h2').count();
    if (heading !== 1) problems.push(`block ${index} has ${heading} headings`);
    if (!(await block.locator('.eyebrow').count())) problems.push(`block ${index} has no eyebrow`);

    const shots = await block.locator('img').count();
    if (shots !== 1) {
      problems.push(`block ${index} shows ${shots} screenshots`);
    } else {
      const meta = await block.locator('img').first().evaluate((img) => ({
        alt: img.getAttribute('alt') ?? '',
        width: img.getAttribute('width') ?? '',
        height: img.getAttribute('height') ?? '',
        loading: img.getAttribute('loading') ?? '',
        decoding: img.getAttribute('decoding') ?? '',
      }));
      if (!meta.alt) problems.push(`block ${index}: a screenshot has no alt text`);
      for (const [name, value] of Object.entries(meta)) {
        if (name === 'alt') continue;
        if (!value) problems.push(`block ${index}: the screenshot has no ${name} attribute`);
      }
      if (meta.loading !== 'lazy')
        problems.push(`block ${index}: a below-the-fold image is not lazy-loaded`);
    }

    const bullets = await block.locator('.checklist li').count();
    if (bullets < 2) problems.push(`block ${index} lists ${bullets} bullet(s)`);
    const empty = await block.locator('.checklist li').evaluateAll((items) =>
      items.filter((item) => !item.textContent.trim()).length,
    );
    if (empty) problems.push(`block ${index} has ${empty} empty bullet(s)`);
  }
  expect(problems, 'Walkthrough blocks that do not explain themselves:\n' + problems.join('\n')).toEqual(
    [],
  );
});

test('every platform card routes its OS to a source that exists', async ({ page }) => {
  await page.goto('/');
  const cards = await page
    .locator('#download .platform-card')
    .evaluateAll((list) =>
      list.map((card) => ({
        name: (card.querySelector('.name')?.textContent ?? '').replace(/\s+/g, ' ').trim(),
        category: (card.querySelector('.platform-category')?.textContent ?? '').trim(),
        meta: (card.querySelector('.platform-meta')?.textContent ?? '').trim(),
        hrefs: [...card.querySelectorAll('a')].map((a) => a.getAttribute('href')),
        releaseKeys: [...card.querySelectorAll('[data-release-platform]')].map(
          (a) => a.dataset.releasePlatform,
        ),
        soon: card.classList.contains('soon'),
        links: [...card.querySelectorAll('a')].map((a) => a.textContent.trim()),
        text: (card.textContent ?? '').replace(/\s+/g, ' ').trim(),
      })),
    );
  expect(cards.length, 'the platform picker is empty').toBeGreaterThanOrEqual(4);

  // Where each build is actually obtainable. A card that stops matching has to be
  // fixed here rather than left to send readers to a store that never carried it.
  const EXPECTED_STORE = {
    Android: 'play.google.com',
    'Android (FOSS)': 'f-droid.org',
    macOS: 'github.com',
    Windows: 'apps.microsoft.com',
    Linux: 'snapcraft.io',
  };

  const problems = [];
  for (const card of cards) {
    if (!card.name) problems.push('a platform card has no operating system named');
    if (!['Mobile', 'Desktop'].includes(card.category)) {
      problems.push(`${card.name}: category "${card.category}" is not Mobile or Desktop`);
    }
    if (!card.meta) problems.push(`${card.name}: no note saying which builds it covers`);
    for (const href of card.hrefs) {
      if (/^http:\/\//i.test(href)) problems.push(`${card.name}: plain http link ${href}`);
    }
    for (const key of card.releaseKeys) {
      if (!RELEASE_ASSET_SUFFIXES[key]) {
        problems.push(`${card.name}: data-release-platform="${key}" is not a CI artifact`);
      }
    }
    if (card.soon) {
      if (card.hrefs.length) problems.push(`${card.name}: coming soon but still links out`);
      if (!/coming soon/i.test(card.text)) {
        problems.push(`${card.name}: marked unavailable without saying so`);
      }
      continue;
    }
    const store = EXPECTED_STORE[card.name];
    if (!store) {
      problems.push(`${card.name}: no expected download source is defined for it`);
    } else if (
      !card.hrefs.some(
        (href) => new URL(href, 'https://example.invalid').hostname === store,
      )
    ) {
      problems.push(`${card.name} does not link to ${store} (${card.hrefs.join(', ')})`);
    }
    if (!card.hrefs.length) problems.push(`${card.name} offers nothing to download`);
  }

  const unavailable = cards.filter((card) => card.soon);
  expect(
    unavailable.map((card) => card.name),
    'exactly one platform may be marked unavailable',
  ).toEqual(['iOS']);
  expect(
    problems,
    'Platform cards that do not route a build:\n' + problems.join('\n'),
  ).toEqual([]);

  // The picker also promises the archive list below, so that anchor has to exist.
  await expect(page.locator('#download a[href="#releases"]')).toHaveCount(1);
});

test('the demo embeds a player rather than a bare video link', async ({ page }) => {
  await page.goto('/');
  const frame = page.locator('#demo iframe');
  await expect(frame, 'the demo section has no player').toHaveCount(1);

  const attrs = await frame.evaluate((el) => ({
    src: el.getAttribute('src') ?? '',
    title: el.getAttribute('title') ?? '',
    allow: el.getAttribute('allow') ?? '',
    referrer: el.getAttribute('referrerpolicy') ?? '',
    fullscreen: el.hasAttribute('allowfullscreen'),
    width: el.getAttribute('width') ?? '',
    height: el.getAttribute('height') ?? '',
  }));
  const url = new URL(attrs.src);
  expect(url.hostname, 'the demo is not a YouTube embed').toMatch(/(^|\.)youtube(-nocookie)?\.com$/);
  expect(url.pathname, 'embed the player path, /watch will not frame inside a page')
    .toMatch(/^\/embed\/[\w-]+$/);
  expect(url.searchParams.get('si'), 'the embed lost its tracking parameter').toBeTruthy();
  expect(attrs.title, 'an iframe with no name is invisible to a screen reader').toBeTruthy();
  expect(attrs.referrer, 'the embed must not leak the full URL to Google').toBe(
    'strict-origin-when-cross-origin',
  );
  expect(attrs.fullscreen, 'the demo cannot go fullscreen').toBe(true);
  expect(Number(attrs.width), 'the embed has no declared width').toBeGreaterThan(0);
  expect(Number(attrs.height), 'the embed has no declared height').toBeGreaterThan(0);
  expect(attrs.allow, 'autoplay is promised in the permissions policy').toMatch(/autoplay/);
});

test('the open-source card and footer point at the live project home', async ({ page }) => {
  await page.goto('/');
  const repo = 'https://github.com/osociety/vernet';

  const oss = page.locator('.oss');
  await expect(oss.locator('h2')).toContainText(/open source/i);
  const ossHrefs = await oss.locator('a').evaluateAll((links) =>
    links.map((link) => link.getAttribute('href')),
  );
  const missing = [repo, `${repo}/discussions`, `${repo}/issues`].filter(
    (href) => !ossHrefs.includes(href),
  );
  expect(missing, 'the open-source card lost its way to GitHub:\n' + missing.join('\n')).toEqual([]);
  expect(
    ossHrefs.filter((href) => /ko-fi\.com|liberapay\.com/.test(href)).length,
    'the funding links are not both there',
  ).toBe(2);
  await expect(oss.locator('p').first()).toContainText(/Apache License/i);

  const footHrefs = await page
    .locator('footer a')
    .evaluateAll((links) => links.map((link) => link.getAttribute('href')));
  expect(footHrefs, 'the footer does not link the repository').toContain(repo);
  expect(footHrefs.filter((href) => href.startsWith('mailto:')).length, 'no contact address').toBe(
    1,
  );
  expect(
    footHrefs.some((href) => /privacy[-_]policy/i.test(href)),
    'the footer must carry a privacy policy',
  ).toBe(true);
  await expect(page.locator('footer')).toContainText(/not affiliated/i);
  await expect(page.locator('footer .trademark-note')).toContainText(/trademark/i);
  // The store names in the trademark note are the same ones the page shows logos for.
  const note = await page.locator('footer .trademark-note').innerText();
  for (const brand of ['Apple', 'Android', 'Google Play', 'F-Droid', 'Microsoft', 'Windows', 'Linux']) {
    expect(note, `the trademark note omits ${brand}`).toContain(brand);
  }
});

test('no link is plain http, empty, or aimed at the unregistered domain', async ({ page }) => {
  await page.goto('/');
  const links = await page.locator('a[href]').evaluateAll((anchors) =>
    anchors.map((anchor) => ({
      raw: anchor.getAttribute('href'),
      resolved: anchor.href,
      text: (anchor.textContent ?? '').replace(/\s+/g, ' ').trim().slice(0, 40),
      target: anchor.getAttribute('target'),
      rel: anchor.getAttribute('rel') ?? '',
    })),
  );
  expect(links.length, 'the page has no links').toBeGreaterThan(20);

  const problems = [];
  for (const link of links) {
    const label = `"${link.text}" -> ${link.raw}`;
    if (link.raw === null || link.raw.trim() === '') problems.push(`empty href in ${label}`);
    if (/^\s*javascript:/i.test(link.raw)) problems.push(`script URL in ${label}`);
    if (/^http:\/\//i.test(link.raw)) problems.push(`insecure link ${label}`);
    if (link.target === '_blank' && !/noopener/.test(link.rel)) {
      problems.push(`${label} opens a tab without rel=noopener`);
    }
    if (/^mailto:/i.test(link.raw)) {
      if (!/^mailto:[^@\s]+@[^@\s.]+\.[^@\s]+$/i.test(link.raw)) {
        problems.push(`malformed address ${label}`);
      }
      continue;
    }
    let url;
    try {
      url = new URL(link.resolved);
    } catch {
      problems.push(`unparseable ${label}`);
      continue;
    }
    // vernet.app was never registered, so a link to it goes nowhere at all.
    if (url.hostname === 'vernet.app') problems.push(`unregistered domain in ${label}`);
    if (url.hostname === 'api.github.com') problems.push(`a reader-facing link to the API: ${label}`);
    if (url.hostname === 'github.com' && url.pathname === '/') {
      problems.push(`github.com link with no repository in ${label}`);
    }
  }
  expect(problems, problems.join('\n')).toEqual([]);
});

test('content images declare alt text and an intrinsic size', async ({ page }) => {
  await page.goto('/');
  const images = await page.locator('main img').evaluateAll((list) =>
    list.map((img) => ({
      src: (img.getAttribute('src') ?? '').replace(/^https?:\/\/[^/]+/, ''),
      alt: img.getAttribute('alt'),
      width: img.getAttribute('width') ?? '',
      height: img.getAttribute('height') ?? '',
      loading: img.getAttribute('loading') ?? '',
      decoding: img.getAttribute('decoding') ?? '',
      complete: img.complete,
      natural: img.naturalWidth,
    })),
  );
  expect(images.length, 'the page shows no images').toBeGreaterThan(5);

  const problems = [];
  for (const image of images) {
    const label = image.src || 'an inline image';
    if (image.alt === null) problems.push(`${label} has no alt attribute at all`);
    // A screenshot carries meaning; a logo next to its own text does not.
    if (Number(image.width) > 100 && !image.alt) problems.push(`${label} is content with no alt text`);
    if (!/^\d+$/.test(image.width) || !/^\d+$/.test(image.height)) {
      problems.push(`${label} has no intrinsic size, so the layout jumps as it loads`);
    }
    if (!image.loading) problems.push(`${label} does not declare a loading strategy`);
    if (!image.decoding) problems.push(`${label} does not declare a decoding strategy`);
    if (/^(images|favicon)/.test(label) && image.complete && image.natural === 0) {
      problems.push(`${label} failed to decode`);
    }
  }
  expect(problems, problems.join('\n')).toEqual([]);
});

// ---------------------------------------------------------------------------
// Metadata, files and headers: what crawlers and stores are handed
// ---------------------------------------------------------------------------

test('social metadata agrees with the title, description and preview', async ({ page }) => {
  await page.goto('/');
  const meta = await page.evaluate(() => {
    const read = (selector) => document.querySelector(selector)?.getAttribute('content') ?? null;
    return {
      title: document.title,
      description: read('meta[name="description"]'),
      ogTitle: read('meta[property="og:title"]'),
      ogDescription: read('meta[property="og:description"]'),
      ogType: read('meta[property="og:type"]'),
      ogSiteName: read('meta[property="og:site_name"]'),
      ogImage: read('meta[property="og:image"]'),
      ogImageSecure: read('meta[property="og:image:secure_url"]'),
      ogImageAlt: read('meta[property="og:image:alt"]'),
      ogImageWidth: read('meta[property="og:image:width"]'),
      ogImageHeight: read('meta[property="og:image:height"]'),
      twitterCard: read('meta[name="twitter:card"]'),
      twitterTitle: read('meta[name="twitter:title"]'),
      twitterDescription: read('meta[name="twitter:description"]'),
      twitterImage: read('meta[name="twitter:image"]'),
      twitterImageAlt: read('meta[name="twitter:image:alt"]'),
      themeColor: read('meta[name="theme-color"]'),
      viewport: read('meta[name="viewport"]'),
    };
  });

  expect(meta.title, 'the title tag must name the product').toMatch(/^Vernet\b/);
  // Every crawler reads a different tag; a preview that drifts from the title is
  // how a site ends up advertising an old slogan.
  expect(meta.ogTitle, 'og:title drifts from <title>').toBe(meta.title);
  expect(meta.twitterTitle, 'twitter:title drifts from <title>').toBe(meta.title);
  expect(meta.ogDescription, 'og:description drifts from the meta description').toBe(
    meta.description,
  );
  expect(meta.twitterDescription, 'twitter:description drifts').toBe(meta.description);
  expect(meta.ogImage, 'twitter:image and og:image must be the same file').toBe(meta.twitterImage);
  expect(meta.ogImageSecure, 'the secure preview must match').toBe(meta.ogImage);
  expect(meta.ogImageAlt, 'twitter:image:alt drifts from og:image:alt').toBe(meta.twitterImageAlt);
  expect(meta.description.length, 'the description is too short to say anything').toBeGreaterThan(80);
  expect(meta.ogType, 'the page is not an Article').toBe('website');
  expect(meta.ogSiteName).toBe('Vernet');
  expect(meta.twitterCard, 'a large image card is what the preview needs').toBe(
    'summary_large_image',
  );
  // Facebook and Slack crop a 1.91:1 card; the declared size is the file's own.
  expect(Number(meta.ogImageWidth), 'og:image:width').toBeGreaterThanOrEqual(1200);
  expect(Number(meta.ogImageHeight), 'og:image:height').toBeGreaterThanOrEqual(630);
  expect(meta.themeColor, 'theme-color must be a colour').toMatch(/^#[0-9a-f]{3,8}$/i);
  expect(meta.viewport, 'the page must size to the device').toContain('width=device-width');
  expect(
    meta.viewport,
    'pinch zoom is an accessibility feature and cannot be disabled',
  ).not.toMatch(/user-scalable=no|maximum-scale/);
});

test('llms.txt and the agent manifests describe this app', async ({ request }) => {
  const llms = await request.get('/llms.txt', { failOnStatusCode: false });
  expect(llms.ok(), 'llms.txt is not deployed').toBe(true);
  expect(fellBackToIndex(llms), 'llms.txt was served as the landing page').toBe(false);
  const llmsText = await llms.text();
  expect(llmsText, 'llms.txt must open with its title').toMatch(/^# Vernet$/m);
  expect(llmsText, 'llms.txt must say what the app is').toMatch(/^> .{40,}/m);
  for (const need of ['device', 'port', 'ping', 'subnet', 'speed']) {
    expect(llmsText.toLowerCase(), `llms.txt never mentions ${need}`).toContain(need);
  }

  const catalogResponse = await request.get('/.well-known/ai-catalog.json', {
    failOnStatusCode: false,
  });
  expect(fellBackToIndex(catalogResponse), 'ai-catalog.json was served as the landing page').toBe(
    false,
  );
  const catalog = await catalogResponse.json();
  expect(catalog.specVersion, 'the agent catalog has no spec version').toBeTruthy();
  expect(catalog.host?.displayName, 'the agent catalog does not name the app').toBe('Vernet');
  expect(Array.isArray(catalog.entries), 'ai-catalog.json entries must be a list').toBe(true);

  const ardResponse = await request.get('/.well-known/ard.json', { failOnStatusCode: false });
  expect(fellBackToIndex(ardResponse), 'ard.json was served as the landing page').toBe(false);
  const ard = await ardResponse.json();
  expect(Array.isArray(ard.entries), 'ard.json entries must be a list').toBe(true);

  // The <link rel> hints have to agree with the files, or an agent crawler is
  // sent to a path that answers with HTML.
  const home = await (await request.get('/')).text();
  for (const [rel, path] of [
    ['ard', '/.well-known/ard.json'],
    ['ai-catalog', '/.well-known/ai-catalog.json'],
  ]) {
    const tag = new RegExp(`<link[^>]+rel=["']${rel}["'][^>]+href=["']([^"']+)["']`, 'i').exec(
      home,
    )?.[1];
    expect(tag, `index.html advertises no <link rel="${rel}">`).toBeTruthy();
    expect(new URL(tag, 'https://example.invalid').pathname, `rel="${rel}" points elsewhere`).toBe(
      path,
    );
  }
});

test('app-ads.txt and the Google verification files are served as themselves', async ({
  page,
  request,
}) => {
  await page.goto('/');

  // AdMob refuses to serve ads to an app whose developer site has no parseable
  // app-ads.txt, and the `**` rewrite would hand it HTML.
  const ads = await request.get('/app-ads.txt', { failOnStatusCode: false });
  expect(ads.ok(), 'app-ads.txt is not deployed').toBe(true);
  expect(contentTypeOf(ads), 'app-ads.txt must be text/plain').toMatch(/^text\/plain/);
  expect(await ads.text()).toMatch(/^google\.com,\s*pub-\d+,\s*DIRECT,\s*[0-9a-f]{16}\s*$/im);

  // Which verification files ship is a fact about firebase/public/, not something
  // to hardcode: a rotated token must be covered without editing this test.
  const { readdirSync } = await import('node:fs');
  const tokens = readdirSync(new URL('../public/', import.meta.url)).filter((name) =>
    /^google[0-9a-z]{6,}\.html$/i.test(name),
  );
  expect(tokens.length, 'firebase/public holds no Google site-verification file').toBeGreaterThan(
    0,
  );
  for (const token of tokens) {
    const response = await request.get(`/${token}`, { failOnStatusCode: false });
    expect(response.ok(), `/${token} is not deployed`).toBe(true);
    const body = await response.text();
    // Content is the only tell here: a rewrite would also answer 200 as HTML.
    expect(
      body,
      `/${token} answered with the landing page, not the token`,
    ).toContain(`google-site-verification: ${token}`);
    expect(body, `/${token} is the landing page`).not.toContain('name="description"');
  }

  for (const [label, selector] of [
    ['favicon', 'link[rel="icon"]'],
    ['apple-touch-icon', 'link[rel="apple-touch-icon"]'],
  ]) {
    const href = await page.locator(selector).first().getAttribute('href');
    expect(href, `no <link rel="${label}"> is declared`).toBeTruthy();
    const icon = await request.get(new URL(href, 'https://example.invalid').pathname, {
      failOnStatusCode: false,
    });
    expect(icon.ok(), `${label} ${href} is not deployed`).toBe(true);
    expect(contentTypeOf(icon), `${label} must be an image`).toMatch(/^image\//);
    expect((await icon.body()).byteLength, `${label} is empty`).toBeGreaterThan(500);
  }
});

test('Hosting applies the cache policy firebase.json declares', async ({ request }) => {
  test.skip(
    !hostedByFirebase(),
    'Cache-Control comes from Firebase Hosting, which a loopback server does not apply',
  );

  const checks = [
    // The document is rewritten for `**`, so it must revalidate: this page carries
    // release numbers that change on every publish.
    ['/index.html', 'no-cache'],
    ['/favicon-64.png', 'public, max-age=2592000'],
    ['/favicon.png', 'public, max-age=2592000'],
    ['/images/desktop-home.webp', 'public, max-age=2592000'],
  ];
  const problems = [];
  for (const [path, expected] of checks) {
    const response = await request.get(path, fresh);
    const actual = response.headers()['cache-control'] ?? '(absent)';
    if (actual !== expected) problems.push(`${path}: Cache-Control is "${actual}", not "${expected}"`);
  }
  expect(
    problems,
    'firebase.json declares these policies; a mismatch means the config stopped ' +
      'matching what Hosting sends:\n' + problems.join('\n'),
  ).toEqual([]);
});

// ---------------------------------------------------------------------------
// Resilience: the page without its third-party calls, and without motion
// ---------------------------------------------------------------------------

test('the page still offers downloads when the GitHub API is unreachable', async ({ page }) => {
  const errors = [];
  page.on('pageerror', (error) => errors.push(String(error)));
  page.on('console', (message) => {
    if (message.type() !== 'error') return;
    // Chromium logs an aborted request as `Failed to load resource: ERR_FAILED`
    // and puts the URL in the message location, not the text.
    if (/api\.github\.com/.test(message.text() + (message.location()?.url ?? ''))) return;
    errors.push(message.text());
  });
  await page.route('**api.github.com/**', (route) => route.abort());

  await page.goto('/');
  await page.waitForLoadState('networkidle');

  // The band is reveal-on-data. Showing `–` placeholders for numbers nobody asked
  // a server for would advertise a broken site, so the whole strip collapses.
  const band = page.locator('#repo-stats');
  await expect(band, 'the stats band revealed itself without its numbers').toBeHidden();
  expect(
    await band.evaluate((el) => el.getBoundingClientRect().height),
    'a collapsed band still takes up room',
  ).toBe(0);
  const slots = await page.locator('[data-repo-stat]').evaluateAll((els) =>
    els.map((el) => el.textContent.trim()),
  );
  expect(slots.length, 'the band lost its slots').toBe(3);
  expect(slots, 'a slot kept a number it cannot have fetched').toEqual(['–', '–', '–']);

  // Downloads are the job of this page, and they never depended on the API: the
  // static /releases/latest links are the fallback, so they must still be there.
  const latest = 'https://github.com/osociety/vernet/releases/latest';
  const hrefs = await page.locator('[data-release-platform]').evaluateAll((links) =>
    links.map((link) => link.getAttribute('href')),
  );
  expect(hrefs.length, 'no platform download links rendered').toBeGreaterThan(4);
  expect(hrefs, `every key must keep its ${latest} fallback`).toEqual(hrefs.map(() => latest));
  await expect(page.locator('#release-list .release-row'), 'a phantom release row').toHaveCount(0);
  await expect(page.locator('.release-note a')).toHaveAttribute('href', latest.replace('/latest', ''));
  await expect(page.locator('.hero .cta-row a').first()).toBeVisible();

  expect(errors, 'the failed lookups raised uncaught errors:\n' + errors.join('\n')).toEqual([]);
});

test('the stats band is wired for exactly the three numbers it publishes', async ({ page }) => {
  await page.goto('/');
  const band = await page.evaluate(() => {
    const section = document.getElementById('repo-stats');
    return {
      hidden: section.hidden,
      name: section.getAttribute('aria-label'),
      keys: [...section.querySelectorAll('[data-repo-stat]')].map((el) => el.dataset.repoStat),
      labels: [...section.querySelectorAll('.stat-label')].map((el) => el.textContent.trim()),
      numbers: [...section.querySelectorAll('.stat-number')].length,
      iconsHidden: [...section.querySelectorAll('.stat-icon')].every(
        (icon) => icon.getAttribute('aria-hidden') === 'true',
      ),
      strayIcons: [...section.querySelectorAll('svg')].filter(
        (svg) => !svg.closest('.stat-icon'),
      ).length,
      insideOss: Boolean(document.querySelector('.oss #repo-stats')),
    };
  });

  expect(band.insideOss, 'the band moved back inside the open-source card').toBe(false);
  // These keys are what the script fills: `setRepoStat('stars'|'forks'|'downloads')`.
  expect(band.keys, 'the band must carry stars, forks and downloads').toEqual([
    'stars',
    'forks',
    'downloads',
  ]);
  expect(band.numbers, 'a stat has a label but no number slot').toBe(band.keys.length);
  expect(band.labels, 'a stat has no label').toHaveLength(band.keys.length);
  expect(new Set(band.labels).size, 'stat labels repeat each other').toBe(band.labels.length);
  expect(band.iconsHidden, 'a decorative icon is not hidden from assistive tech').toBe(true);
  expect(band.strayIcons, 'an svg in the band is not inside an icon chip').toBe(0);
  expect(band.name, 'the band needs an accessible name; it has no heading').toBeTruthy();
  expect(band.hidden, 'the band starts open, so placeholders flash at first paint').toBe(true);
});

test('reduced motion switches off the decorative animation', async ({ page }) => {
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await page.goto('/');
  // The band only unhides once the API answers; measure its CSS regardless so the
  // motion rules are checked without spending a rate-limited GitHub call.
  const motion = await page.evaluate(() => {
    document.getElementById('repo-stats').hidden = false;
    const stat = document.querySelector('.stat');
    return {
      rise: getComputedStyle(stat).animationName,
      duration: getComputedStyle(stat).transitionDuration,
      sheen: getComputedStyle(document.querySelector('.stats'), '::before').animationName,
      carousel: getComputedStyle(document.getElementById('feature-carousel')).scrollBehavior,
      htmlSmooth: getComputedStyle(document.documentElement).scrollBehavior,
    };
  });

  expect(motion.rise, 'the stat cards still rise into place').toBe('none');
  expect(motion.sheen, 'the light sweep still crosses the band').toBe('none');
  expect(
    parseFloat(motion.duration) || 0,
    `the hover lift still animates over ${motion.duration}`,
  ).toBe(0);
  expect(motion.carousel, 'the carousel still smooth-scrolls').toBe('auto');
});

test('the layout never overflows sideways at any width', async ({ page }) => {
  const problems = [];
  for (const width of [1440, 1280, 1024, 820, 760, 641, 640, 560, 430, 390, 360, 320]) {
    await page.setViewportSize({ width, height: 900 });
    await page.goto('/');
    const state = await page.evaluate(() => {
      document.getElementById('repo-stats').hidden = false;
      const doc = document.documentElement;
      const limit = doc.clientWidth;
      // A child that runs past the edge inside its own scroll container is the
      // design (the feature carousel); one that does it inside the document is a
      // layout bug that puts the whole page on a horizontal scroll.
      const scrolled = (node) => {
        for (let parent = node.parentElement; parent; parent = parent.parentElement) {
          if (/(auto|scroll|hidden)/.test(getComputedStyle(parent).overflowX)) return parent;
        }
        return null;
      };
      const offenders = [];
      for (const el of document.querySelectorAll('body *')) {
        if (!(el instanceof HTMLElement) || scrolled(el)) continue;
        const box = el.getBoundingClientRect();
        if (!box.width) continue;
        if (box.right > limit + 1 || box.left < -1) {
          const name = `${el.tagName.toLowerCase()}${
            el.className && typeof el.className === 'string' ? `.${el.className.split(' ')[0]}` : ''
          }`;
          offenders.push(`${name} ${Math.round(box.left)}..${Math.round(box.right)}`);
        }
      }
      const tops = [...new Set([...document.querySelectorAll('.stat')].map((s) => Math.round(s.getBoundingClientRect().top)))];
      const widths = [...document.querySelectorAll('.stat')].map((s) =>
        Math.round(s.getBoundingClientRect().width),
      );
      return {
        clientWidth: doc.clientWidth,
        scrollWidth: doc.scrollWidth,
        bodyScrollWidth: document.body.scrollWidth,
        offenders: offenders.slice(0, 6),
        columns: getComputedStyle(document.querySelector('.stats')).gridTemplateColumns
          .split(' ')
          .filter(Boolean).length,
        rows: tops.length,
        widest: Math.max(...widths),
        narrowest: Math.min(...widths),
      };
    });

    const at = `${width}px`;
    if (state.scrollWidth > state.clientWidth + 1) {
      problems.push(`${at}: the document scrolls sideways (${state.scrollWidth} > ${state.clientWidth})`);
    }
    if (state.bodyScrollWidth > state.clientWidth + 1) {
      problems.push(`${at}: the body is wider than the viewport (${state.bodyScrollWidth})`);
    }
    if (state.offenders.length) {
      problems.push(`${at}: past the viewport edge: ${state.offenders.join(', ')}`);
    }
    // Three numbers side by side until the row is too tight for that, then two
    // columns with the download count spanning the full width beneath them.
    if (width > 640) {
      if (state.columns !== 3) problems.push(`${at}: the band has ${state.columns} columns, not 3`);
      if (state.rows !== 1) problems.push(`${at}: the stats wrapped onto ${state.rows} rows`);
    } else {
      if (state.columns !== 2) problems.push(`${at}: the band has ${state.columns} columns, not 2`);
      if (state.rows !== 2) problems.push(`${at}: the third stat does not span its own row`);
      if (state.widest <= state.narrowest)
        problems.push(`${at}: the spanning stat is no wider than the others`);
    }
  }
  expect(problems, problems.join('\n')).toEqual([]);
});
