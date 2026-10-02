(() => {
  const labels = { ts: 'TypeScript', typescript: 'TypeScript', js: 'JavaScript', javascript: 'JavaScript', json: 'JSON', http: 'HTTP', bash: 'Shell', sh: 'Shell', shell: 'Shell', yaml: 'YAML', yml: 'YAML', python: 'Python', ruby: 'Ruby', text: 'Plain text' };

  document.querySelectorAll('.prose pre').forEach((pre) => {
    if (pre.closest('.code-window')) return;
    const code = pre.querySelector('code');
    const root = pre.closest('.highlighter-rouge') || pre.closest('figure.highlight') || pre;
    const classes = `${root.className} ${pre.className} ${code?.className || ''}`;
    const language = classes.match(/language-([\w+-]+)/)?.[1] || 'text';
    const frame = document.createElement('div');
    frame.className = 'code-window';
    const toolbar = document.createElement('div');
    toolbar.className = 'code-toolbar';
    toolbar.setAttribute('data-pagefind-ignore', 'all');
    const dots = document.createElement('span');
    dots.className = 'code-window-dots';
    dots.setAttribute('aria-hidden', 'true');
    for (let i = 0; i < 3; i++) dots.append(document.createElement('i'));
    const label = document.createElement('span');
    label.className = 'code-language';
    label.textContent = labels[language] || language;
    toolbar.append(dots, label);
    root.before(frame);
    frame.append(toolbar, root);

    // Rouge expects a full HTTP request line; also color abbreviated API examples.
    if (language === 'http' && code) {
      const source = code.textContent;
      const fragment = document.createDocumentFragment();
      source.split(/(\n)/).forEach((line) => {
        const tokens = /^(GET|POST|PUT|PATCH|DELETE|HEAD|OPTIONS|CONNECT|TRACE)\b|^[\w-]+(?=:)|\$[A-Za-z_][A-Za-z0-9_]*/g;
        let offset = 0;
        for (const match of line.matchAll(tokens)) {
          fragment.append(document.createTextNode(line.slice(offset, match.index)));
          const span = document.createElement('span');
          span.className = match[1] ? 'k' : match[0].startsWith('$') ? 'nv' : 'na';
          span.textContent = match[0];
          fragment.append(span);
          offset = match.index + match[0].length;
        }
        fragment.append(document.createTextNode(line.slice(offset)));
      });
      code.replaceChildren(fragment);
    }
  });
})();
