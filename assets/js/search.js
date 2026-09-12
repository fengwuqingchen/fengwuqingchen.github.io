(() => {
  "use strict";

  const script = document.currentScript;
  const pagefindBase = script?.dataset.pagefindBase || "/pagefind/";
  const layer = document.querySelector("#search-dialog");
  const panel = layer?.querySelector(".search-panel");
  const input = document.querySelector("#search-input");
  const results = document.querySelector("#search-results");
  const status = document.querySelector("#search-status");
  const filters = [...document.querySelectorAll("[data-search-category]")];
  const openButtons = [...document.querySelectorAll("[data-search-open]")];
  const closeButtons = [...document.querySelectorAll("[data-search-close]")];

  if (!layer || !panel || !input || !results || !status) return;

  let pagefind;
  let pagefindPromise;
  let previousFocus;
  let selectedCategory = "";
  let searchTimer;
  let requestSequence = 0;

  const isEditable = (element) =>
    element instanceof HTMLInputElement ||
    element instanceof HTMLTextAreaElement ||
    element instanceof HTMLSelectElement ||
    element?.isContentEditable;

  const loadPagefind = async () => {
    if (pagefind) return pagefind;
    pagefindPromise ||= import(`${pagefindBase}pagefind.js`).then(async (module) => {
      await module.init();
      pagefind = module;
      return module;
    });
    return pagefindPromise;
  };

  const setStatus = (message) => {
    status.textContent = message;
  };

  const appendHighlightedText = (element, html) => {
    const parsed = new DOMParser().parseFromString(String(html || ""), "text/html");

    const appendNode = (node, target) => {
      if (node.nodeType === Node.TEXT_NODE) {
        target.append(document.createTextNode(node.textContent || ""));
        return;
      }

      const nextTarget = node.nodeName === "MARK" ? document.createElement("mark") : target;
      if (nextTarget !== target) target.append(nextTarget);
      [...node.childNodes].forEach((child) => appendNode(child, nextTarget));
    };

    [...parsed.body.childNodes].forEach((node) => appendNode(node, element));
  };

  const renderResult = (data) => {
    const item = document.createElement("li");
    const link = document.createElement("a");
    const meta = document.createElement("p");
    const title = document.createElement("h3");
    const excerpt = document.createElement("p");
    const category = data.meta?.category ? ` · #${data.meta.category}` : "";

    link.className = "search-result-link";
    link.href = data.url;
    meta.className = "search-result-meta";
    meta.textContent = `${data.meta?.date || "文章"}${category}`;
    title.textContent = data.meta?.title || "未命名文章";
    excerpt.className = "search-result-excerpt";
    appendHighlightedText(excerpt, data.excerpt);
    link.append(meta, title, excerpt);
    item.append(link);
    return item;
  };

  const runSearch = async () => {
    const query = input.value.trim();
    const currentRequest = ++requestSequence;
    results.replaceChildren();

    if (!query && !selectedCategory) {
      setStatus("请输入标题、正文或分类关键词");
      return;
    }

    setStatus("正在月光下寻找…");

    try {
      const engine = await loadPagefind();
      const options = selectedCategory ? { filters: { category: selectedCategory } } : {};
      const search = await engine.search(query || null, options);
      if (currentRequest !== requestSequence) return;

      if (search.results.length === 0) {
        setStatus("没有找到相关内容，试试更短的关键词");
        return;
      }

      const resultData = await Promise.all(search.results.slice(0, 12).map((result) => result.data()));
      if (currentRequest !== requestSequence) return;
      results.append(...resultData.map(renderResult));
      setStatus(`找到 ${search.results.length} 条相关内容`);
    } catch (error) {
      console.error("Search failed to load", error);
      setStatus("搜索暂时无法使用，请稍后再试");
    }
  };

  const scheduleSearch = () => {
    window.clearTimeout(searchTimer);
    searchTimer = window.setTimeout(runSearch, 140);
  };

  const openSearch = () => {
    if (!layer.hidden) return;
    previousFocus = document.activeElement;
    layer.hidden = false;
    document.body.classList.add("search-is-open");
    window.requestAnimationFrame(() => {
      layer.classList.add("is-visible");
      input.focus();
    });
  };

  const closeSearch = () => {
    if (layer.hidden) return;
    layer.classList.remove("is-visible");
    document.body.classList.remove("search-is-open");
    window.setTimeout(() => {
      layer.hidden = true;
      previousFocus?.focus();
    }, 180);
  };

  const moveThroughResults = (direction) => {
    const links = [...results.querySelectorAll("a")];
    if (links.length === 0) return;
    const activeIndex = links.indexOf(document.activeElement);
    const nextIndex = activeIndex < 0
      ? direction > 0 ? 0 : links.length - 1
      : (activeIndex + direction + links.length) % links.length;
    links[nextIndex].focus();
  };

  openButtons.forEach((button) => button.addEventListener("click", openSearch));
  closeButtons.forEach((button) => button.addEventListener("click", closeSearch));
  input.addEventListener("input", scheduleSearch);

  filters.forEach((filter) => {
    filter.addEventListener("click", () => {
      selectedCategory = filter.dataset.searchCategory || "";
      filters.forEach((item) => {
        const isActive = item === filter;
        item.classList.toggle("is-active", isActive);
        item.setAttribute("aria-pressed", String(isActive));
      });
      runSearch();
    });
  });

  document.addEventListener("keydown", (event) => {
    if (event.key === "/" && !isEditable(event.target) && layer.hidden) {
      event.preventDefault();
      openSearch();
    } else if (event.key === "Escape" && !layer.hidden) {
      closeSearch();
    } else if (event.key === "ArrowDown" && !layer.hidden) {
      event.preventDefault();
      moveThroughResults(1);
    } else if (event.key === "ArrowUp" && !layer.hidden) {
      event.preventDefault();
      moveThroughResults(-1);
    } else if (event.key === "Tab" && !layer.hidden) {
      const focusable = [...panel.querySelectorAll("button, input, a[href]")].filter((item) => !item.hidden);
      if (focusable.length === 0) return;
      const first = focusable[0];
      const last = focusable[focusable.length - 1];
      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault();
        last.focus();
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault();
        first.focus();
      }
    }
  });
})();
