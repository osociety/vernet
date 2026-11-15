import { defineConfig, devices } from '@playwright/test';

const siteUrl = process.env.SITE_URL;

if (!siteUrl) {
  throw new Error(
    'SITE_URL is required. Point it at a deployed site, normally a Firebase ' +
      'preview channel: SITE_URL=https://vernet-app--<channel>-<hash>.web.app npm test',
  );
}

export default defineConfig({
  testDir: '.',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 1 : 0,
  reporter: process.env.CI ? [['github'], ['html', { open: 'never' }]] : 'list',
  use: {
    baseURL: siteUrl,
    trace: 'retain-on-failure',
  },
  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }],
});
