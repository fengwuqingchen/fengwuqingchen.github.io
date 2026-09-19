(() => {
  const container = document.querySelector("[data-page-views]");
  const label = container?.querySelector(".post-views");
  const tracker = document.querySelector("#goatcounter-script");

  if (!container || !label || !tracker) return;

  const showViews = async () => {
    const endpoint = tracker.dataset.goatcounter?.replace(/\/count\/?$/, "");
    const data = window.goatcounter?.get_data?.();
    const path = data?.p;

    if (!endpoint || !path) return;

    try {
      const response = await fetch(`${endpoint}/counter/${encodeURIComponent(path)}.json`);
      if (!response.ok) return;

      const payload = await response.json();
      if (typeof payload.count !== "string" && typeof payload.count !== "number") return;

      label.textContent = `浏览 ${payload.count}`;
      container.hidden = false;
    } catch (_) {
      // Statistics must never interrupt reading when a tracker is unavailable.
    }
  };

  if (window.goatcounter?.get_data) {
    showViews();
  } else {
    tracker.addEventListener("load", showViews, { once: true });
  }
})();
