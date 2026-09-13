(() => {
  "use strict";

  const root = document.documentElement;
  const toggle = document.querySelector("[data-theme-toggle]");
  const systemTheme = window.matchMedia("(prefers-color-scheme: dark)");

  if (!toggle) return;

  const storedTheme = () => {
    try {
      return localStorage.getItem("blog-theme");
    } catch (_) {
      return null;
    }
  };

  const preferredTheme = () => storedTheme() || (systemTheme.matches ? "dark" : "light");

  const applyTheme = (theme) => {
    const isDark = theme === "dark";
    root.dataset.theme = isDark ? "dark" : "light";
    toggle.setAttribute("aria-label", isDark ? "切换为浅色主题" : "切换为深色主题");
  };

  applyTheme(root.dataset.theme || preferredTheme());

  toggle.addEventListener("click", () => {
    const nextTheme = root.dataset.theme === "dark" ? "light" : "dark";
    try {
      localStorage.setItem("blog-theme", nextTheme);
    } catch (_) {}
    applyTheme(nextTheme);
  });

  systemTheme.addEventListener("change", () => {
    if (!storedTheme()) applyTheme(preferredTheme());
  });
})();
