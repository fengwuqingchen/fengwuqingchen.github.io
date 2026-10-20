(() => {
  const container = document.querySelector('[data-html-container]');
  const load = document.querySelector('[data-html-load]');
  const stop = document.querySelector('[data-html-stop]');
  const status = document.querySelector('[data-html-status]');
  if (!container || !load || !stop || !status) return;
  const policy = "default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; img-src data:; font-src data:; connect-src 'none'; frame-src 'none'; object-src 'none'; base-uri 'none'; form-action 'none'";
  const back = document.querySelector('[data-html-back]');
  try {
    const referrer = new URL(document.referrer);
    if (referrer.origin === location.origin && /^\/(?:posts|ai\/posts|references)\//.test(referrer.pathname)) back.href = referrer.href;
  } catch (_) {}
  let generation = 0;
  stop.addEventListener('click', () => {
    generation += 1;
    container.replaceChildren();
    stop.hidden = true;
    load.hidden = false;
    load.disabled = false;
    status.textContent = '已停止运行，可重新加载。';
  });
  load.addEventListener('click', async () => {
    const current = ++generation;
    load.disabled = true;
    status.textContent = '正在加载隔离内容…';
    try {
      const url = new URL(container.dataset.htmlPayload, location.href);
      if (url.origin !== location.origin || !/\/assets\/html-data\/[a-f0-9]{64}\.json$/.test(url.pathname)) throw new Error('invalid payload URL');
      const response = await fetch(url, { credentials: 'omit', redirect: 'error' });
      if (!response.ok) throw new Error('payload unavailable');
      const payload = await response.json();
      if (payload.version !== 1 || typeof payload.html !== 'string') throw new Error('invalid payload');
      if (current !== generation) return;
      const frame = document.createElement('iframe');
      frame.title = '隔离的 HTML 交互资料';
      // Never add allow-same-origin: scripts must not access the parent or storage.
      frame.setAttribute('sandbox', 'allow-scripts');
      frame.setAttribute('referrerpolicy', 'no-referrer');
      frame.setAttribute('allow', "camera 'none'; microphone 'none'; geolocation 'none'; clipboard-read 'none'; clipboard-write 'none'; payment 'none'; usb 'none'");
      frame.srcdoc = '<!doctype html><html><head><meta charset="utf-8"><meta http-equiv="Content-Security-Policy" content="' + policy + '"><meta name="referrer" content="no-referrer"></head><body>' + payload.html + '</body></html>';
      container.replaceChildren(frame);
      load.hidden = true;
      stop.hidden = false;
      status.textContent = '交互已加载。若内容异常或耗资源，可停止运行。';
    } catch (_) {
      if (current !== generation) return;
      load.disabled = false;
      status.textContent = '内容加载失败，请稍后重试。';
    }
  });
})();
