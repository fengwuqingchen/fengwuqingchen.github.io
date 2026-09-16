(() => {
  const toc = document.querySelector("[data-article-toc]");
  const tocList = document.querySelector("[data-article-toc-list]");
  const headings = [...document.querySelectorAll(".prose h2, .prose h3, .prose h4")];

  if (!toc || !tocList || headings.length === 0) return;

  const usedIds = new Set([...document.querySelectorAll("[id]")].map((element) => element.id));
  const linksById = new Map();

  const createId = (text) => {
    const base = text
      .normalize("NFKC")
      .toLocaleLowerCase()
      .trim()
      .replace(/[^\p{L}\p{N}\s-]/gu, "")
      .replace(/[\s-]+/gu, "-")
      .replace(/^-+|-+$/g, "") || "section";

    let id = base;
    let index = 2;
    while (usedIds.has(id)) {
      id = `${base}-${index}`;
      index += 1;
    }
    usedIds.add(id);
    return id;
  };

  const setActive = (id) => {
    linksById.forEach((link, linkId) => {
      const active = linkId === id;
      link.classList.toggle("is-active", active);
      if (active) link.setAttribute("aria-current", "location");
      else link.removeAttribute("aria-current");
    });
  };

  headings.forEach((heading) => {
    const text = heading.textContent.trim();
    if (!text) return;

    if (!heading.id) heading.id = createId(text);

    const anchor = document.createElement("a");
    anchor.className = "heading-anchor";
    anchor.href = `#${heading.id}`;
    anchor.setAttribute("aria-label", `链接到「${text}」`);
    anchor.textContent = "#";
    heading.append(anchor);

    const item = document.createElement("li");
    item.className = `toc-level-${heading.tagName.slice(1)}`;

    const link = document.createElement("a");
    link.href = `#${heading.id}`;
    link.textContent = text;
    item.append(link);
    tocList.append(item);
    linksById.set(heading.id, link);
  });

  toc.hidden = tocList.children.length === 0;
  if (toc.hidden) return;

  const activateHashTarget = () => {
    const id = decodeURIComponent(window.location.hash.slice(1));
    if (linksById.has(id)) setActive(id);
  };

  activateHashTarget();
  window.addEventListener("hashchange", activateHashTarget);

  const observer = new IntersectionObserver(
    (entries) => {
      const visible = entries
        .filter((entry) => entry.isIntersecting)
        .sort((a, b) => a.boundingClientRect.top - b.boundingClientRect.top)[0];
      if (visible) setActive(visible.target.id);
    },
    { rootMargin: "-110px 0px -68% 0px", threshold: 0 }
  );

  headings.forEach((heading) => observer.observe(heading));
})();
