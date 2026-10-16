#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
/usr/bin/time -p bash -c 'test -n "${CAPTURE_URL:-}" || { echo "CAPTURE_URL must be set" >&2; exit 1; }'
/usr/bin/time -p bash -c 'test -n "${CAPTURE_DIR:-}" || { echo "CAPTURE_DIR must be set" >&2; exit 1; }'
/usr/bin/time -p mkdir -p "${CAPTURE_DIR:?CAPTURE_DIR must be set}"
/usr/bin/time -p echo "capturing CAPTURE_URL=$CAPTURE_URL into $CAPTURE_DIR"
/usr/bin/time -p node --input-type=module <<'NODEJS'
import { mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';

const url = process.env.CAPTURE_URL;
const output = process.env.CAPTURE_DIR;
if (!url || !output) { console.error('Set CAPTURE_URL and CAPTURE_DIR.'); process.exit(1); }
mkdirSync(output, { recursive: true });

const runtime = join(process.env.HOME, '.local/share/omgithub-playwright');
const require = createRequire(join(runtime, 'package.json'));
const { chromium } = require('playwright');
let config;
try {
  config = JSON.parse(readFileSync(join(runtime, process.platform === 'darwin' ? 'metal.json' : 'linux.json'), 'utf8'));
} catch (e) { console.error('Failed to read playwright config: ' + e.message); process.exit(1); }
if (process.platform === 'linux') {
  try { process.env.DISPLAY ||= ':' + readFileSync(join(runtime, 'display'), 'utf8').trim(); }
  catch (e) { console.error('Failed to read display: ' + e.message); process.exit(75); }
}
const transient = (error) => { throw Object.assign(error instanceof Error ? error : new Error(String(error)), { exitCode: 75 }); };
let browser;
try {
  browser = await chromium.launch({ ...config.browser.launchOptions, timeout: 30000 }).catch(transient);
  for (const [name, width, height] of [['desktop', 1440, 900], ['mobile', 390, 844]]) {
    const page = await browser.newPage({ viewport: { width, height } }).catch(transient);
    page.setDefaultTimeout(30000);
    page.on('pageerror', (error) => console.error(error.message));
    const response = await page.goto(url, { waitUntil: 'load', timeout: 45000 }).catch(transient);
    if (!response?.ok()) {
      const status = response?.status();
      const code = (!response || [408, 429, 500, 502, 503, 504].includes(status)) ? 75 : 1;
      throw Object.assign(new Error(`HTTP ${status} loading preview`), { exitCode: code });
    }
    await page.locator(process.env.CAPTURE_READY_SELECTOR || 'body').waitFor({ state: 'visible' });
    await page.waitForFunction(() => document.fonts.status === 'loaded');
    await page.waitForTimeout(1000);
    await page.screenshot({ path: join(output, `final-${name}.png`), timeout: 30000 }).catch((error) => {
      if (error.name === 'TimeoutError' || !browser.isConnected()) transient(error);
      throw error;
    });
    console.log(`captured final-${name}.png`);
    await page.close();
  }
} catch (error) {
  console.error(error);
  process.exit(error.exitCode || 1);
} finally {
  await browser?.close().catch((error) => { console.error(error); process.exitCode ||= 75; });
}
NODEJS
/usr/bin/time -p test -f "$CAPTURE_DIR/final-desktop.png"
/usr/bin/time -p test -f "$CAPTURE_DIR/final-mobile.png"
/usr/bin/time -p ls -lh "$CAPTURE_DIR"
