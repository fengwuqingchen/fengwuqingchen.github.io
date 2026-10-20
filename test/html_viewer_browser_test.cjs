// Optional real-browser regression: NODE_PATH=<playwright packages> node test/html_viewer_browser_test.cjs
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const http = require('node:http');
const os = require('node:os');
const { execFileSync } = require('node:child_process');
const { chromium } = require('playwright');

(async () => {
  const viewer = fs.readFileSync(path.join(__dirname, '../assets/js/html-viewer.js'), 'utf8');
  const payloadPath = '/assets/html-data/' + 'a'.repeat(64) + '.json';
  const input = `<button id="count">0</button><script>
    document.querySelector('#count').onclick = () => document.querySelector('#count').textContent = '1';
    try { parent.document.body.dataset.compromised = 'yes'; document.body.dataset.parent = 'allowed'; } catch (_) { document.body.dataset.parent = 'blocked'; }
    try { localStorage.setItem('escape', 'yes'); document.body.dataset.storage = 'allowed'; } catch (_) { document.body.dataset.storage = 'blocked'; }
    try { top.location.href = '/escaped'; document.body.dataset.navigation = 'allowed'; } catch (_) { document.body.dataset.navigation = 'blocked'; }
    fetch('/exfiltrate').then(() => document.body.dataset.network = 'allowed').catch(() => document.body.dataset.network = 'blocked');
    document.body.dataset.popup = window.open('/popup') === null ? 'blocked' : 'allowed';
  </script>`;
  const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'html-viewer-browser-'));
  const inputPath = path.join(temporary, 'demo.html');
  fs.writeFileSync(inputPath, input);
  const compiled = execFileSync('ruby', ['-r', path.join(__dirname, '../scripts/publish-post.rb'), '-e',
    'bundle = HtmlBundle.new(limit: 20*1024*1024, total_limit: 100*1024*1024, image_limit: 10*1024*1024, compress_images: false); puts JSON.generate(version: 1, html: bundle.compile(ARGV.fetch(0)))', inputPath], { encoding: 'utf8' });
  const payload = JSON.parse(compiled);
  const requests = [];
  const server = http.createServer((req, res) => {
    requests.push(req.url);
    if (req.url === payloadPath) { res.setHeader('Content-Type', 'application/json'); return res.end(JSON.stringify(payload)); }
    if (req.url === '/viewer.js') { res.setHeader('Content-Type', 'application/javascript'); return res.end(viewer); }
    res.setHeader('Content-Type', 'text/html');
    res.end(`<a data-html-back href="/">back</a><p data-html-status></p><button data-html-load>load</button><button data-html-stop hidden>stop</button><div data-html-container data-html-payload="${payloadPath}"></div><script src="/viewer.js"></script>`);
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  let browser;
  try {
    browser = await chromium.launch({ headless: true });
    const page = await browser.newPage();
    const base = `http://127.0.0.1:${server.address().port}`;
    await page.goto(base);
    assert.equal(await page.locator('iframe').count(), 0, 'does not autorun an attachment');
    await page.locator('[data-html-load]').click();
    const frame = page.frameLocator('iframe');
    await frame.locator('#count').click();
    assert.equal(await frame.locator('#count').textContent(), '1', 'local JS interaction works');
    await frame.locator('body[data-network="blocked"]').waitFor();
    const permissions = await frame.locator('body').evaluate(el => ({ ...el.dataset }));
    assert.equal(permissions.parent, 'blocked');
    assert.equal(permissions.storage, 'blocked');
    assert.equal(permissions.navigation, 'blocked');
    assert.equal(permissions.popup, 'blocked');
    assert.equal(await page.locator('body').getAttribute('data-compromised'), null);
    assert.equal(page.url(), base + '/');
    assert(!requests.includes('/exfiltrate'));
    await page.screenshot({ path: path.join(os.tmpdir(), 'blog-html-sandbox-test.png'), fullPage: true });
    await page.locator('[data-html-stop]').click();
    assert.equal(await page.locator('iframe').count(), 0, 'stop destroys the execution context');
    console.log('PASS: local interaction; parent/storage/network/navigation/popups blocked; stop destroys iframe');
  } finally {
    if (browser) await browser.close();
    await new Promise(resolve => server.close(resolve));
    fs.rmSync(temporary, { recursive: true, force: true });
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
