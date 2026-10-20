# 风清的个人博客

这是一个由 GitHub Pages 自动发布的 Jekyll 博客。

## 发布新文章

1. 在 `_posts` 文件夹中新建 Markdown 文件。
2. 文件名使用 `YYYY-MM-DD-英文标题.md`，例如 `2026-09-14-my-first-note.md`。
3. 文件开头填写：

   ```yaml
   ---
   title: "文章标题"
   description: "一句话摘要"
   categories: [tech]
   tags: [关键词]
   ---
   ```

4. 在下方写正文，提交到 `main` 分支。
5. GitHub Pages 会自动构建，通常一两分钟后线上博客就会更新。

可以复制 `_drafts/article-template.md` 作为模板。草稿放在 `_drafts` 中不会公开；写完后移动到 `_posts` 并按日期重命名即可发布。

## 从本地 Markdown / Obsidian 发布

普通 Markdown／附件发布使用 Ruby 脚本。HTML 打包另外需要 Nokogiri（`gem install nokogiri`）；图片无损优化使用可选的 `cwebp`（macOS 可通过 `brew install webp` 安装），缺少它时保留原图。先检查文章及资源清单：

```bash
ruby scripts/publish-post.rb "/绝对路径/2026-10-2-文章.md" --slug article-name --dry-run
```

确认后发布（自动导入文章和资源、提交、推送 main，触发 GitHub Pages）：

```bash
ruby scripts/publish-post.rb "/绝对路径/2026-10-2-文章.md" --slug article-name --publish
```

不加 `--publish` 时仅导入到仓库，可检查后手动提交。源 Markdown 和原附件不会修改。普通文章需要 YAML 中的已注册 `categories`，缺少 `title` 时取文件名；日期从文件名／YAML 读取，均缺失时使用源文件修改日期，也可用 `--date YYYY-MM-DD` 指定。`--slug` 固定主文章 URL，避免中文或空格带来的链接不便。AI 文的默认日期在独立上传和引用上传时一致；无 YAML front matter 的 Markdown 默认作为 AI 文发布。

支持 Obsidian `![[图片.png]]` / `[[附件.pdf]]`，普通 Markdown 图片、附件链接、引用式链接，以及 HTML 的 `src` / `href`。脚本在文章同目录与 `attachments` 中寻找资源；找不到时按文件名搜索文章所在目录，也可用 `--vault "/Obsidian库路径"` 搜索整个库。同名文件不唯一、链接缺失或超限会报错，校验全部成功后才写入。代码块中的示例链接不会作为附件导入；外部 URL 不会下载。

### AI 文、人工引用资料与分类

Obsidian 图片的 `![[图片.png|712]]` 宽度设置会保留为网页图片的 `width`，窄屏上自动缩小、保持原图纵横比，不裁剪或拉伸。`|300x200` 也会保留 HTML 尺寸属性，但网站仍优先保持原图纵横比。不指定尺寸则沿用默认展示。此规则对新发布的文章及递归引用资料生效，已发布的旧文章不会自动重写。

正文中的 `[[资料]]`、`[[资料.md|链接文字]]`、`[资料](资料.md)` 及引用式 Markdown 链接会递归导入本地笔记，改写成可点击的博客阅读页。`![[资料]]` 也转换为链接，不把整篇资料直接嵌入正文。文件名省略 `.md` 的写法仅支持 Obsidian 链接。引用文件中的图片、附件按该文件所在目录解析并一起上传。

主文章为第 0 层，允许「主文章 → 引用资料（第 1 层）→ 引用资料（第 2 层）」。第 2 层再引用本地 Markdown、循环引用、文件缺失或同名歧义都会在写入前报错；外部网址不参与层数限制。清单中的 `references` 包含即将上传的引用文章。

AI 文放在 `_ai_articles/`：通过顶部“AI 文”入口 `/ai/` 浏览，在 `/ai/categories/<主题>/` 查看对应主题。不会混入普通首页、普通分类、站内搜索或普通 RSS，也设置 `noindex`。AI 文复用正文目录、代码高亮、阅读信息及图片样式，主题标签只指向 AI 专区的主题分类。

以下方式均识别为 AI：`ai_generated: true`、`categories: [ai, tech]`、`tags: [ai]`，以及完全没有 front matter。`ai` 不必加入主题 YAML；它表示身份，`tech` 等仍是主题分类。AI 标记与 `ai_generated: false` 同时出现会报冲突。**有 front matter 但没有 AI 字段的旧文章仍是普通文章**，不会被误隐藏。示例：

```yaml
---
title: 一份技术分析
categories: [ai, tech]
slug: architecture-analysis
---
```

单独上传与被普通文章引用时使用相同的身份、主题和资源规则。默认按规范化内容生成 URL；相同内容可复用，内容改变会生成新版本。若需固定 URL，在源文件 YAML 中设置 `slug`（独立上传时也可用 `--slug` 指定）。相同 slug 内容不同会报错，避免静默覆盖；要更新固定 URL 的内容请编辑仓库文件。若希望后续引用沿用独立上传的自定义 slug，也应将该 slug 写入源 YAML。

有 YAML 且未标为 AI 的人工引用笔记仍进入 `_references/`，仅供正文引用，不进入任何文章列表。人工资料单独发布可设置 `reference_only: true`。引用 Markdown 自身受单附件上限约束，所有引用 Markdown、图片和附件共同计入整次上传的总上限。重复引用不会重复计入大小，正文和资源源文件均不会修改。可通过 URL 或公开仓库直接访问这些内容，“不列出”不是身份鉴权。

### 图片无损优化与资源限制

默认对静态 PNG 尝试无损 WebP 编码：不改变像素尺寸、透明度或进行有损量化，并保留可用元数据。只接受比原文件小的结果；动图、JPEG、SVG 等保持原样，避免丢失动画、方向或重复有损压缩。原文件不会改动。工具缺失、失败、超时或压缩无收益时保留原图，`--dry-run` 的 `compression`、`original_size`、`size` 显示实际处理结果；可用 `--no-compress-images` 关闭优化。

默认源单图上限 10 MiB、单个其它附件 20 MiB、整次发布输出资源合计 100 MiB，可用 `--image-mb`、`--attachment-mb`、`--total-mb` 调整。先检查源文件大小，避免大文件绕过校验；总量按优化后的普通资源、引用文档以及 HTML 数据包大小计算。HTML 各源依赖还受各自及包内总量限制。新资源按内容哈希存放在 `/assets/posts/media/`，同轮去重；旧文章与旧资源 URL 不会自动改写。

### 引用 HTML 交互资料

正文使用 `[查看交互演示](demo.html)` 或 `[[demo.html]]`。本地 HTML 一并打包到 JSON 数据包，文章链接指向 `/html/<内容哈希>/`。它不进入普通／AI 列表、分类、站内搜索或 RSS，也不发布可直接执行的同源原始 `.html` 附件。

读者点击“加载交互内容”后，在 `sandbox="allow-scripts"`、不含 `allow-same-origin` 的 iframe 内运行。允许页面自身的按钮、图表、本地计算；不能读取博客 DOM／同源存储，默认不允许弹窗、顶层跳转、表单提交、自动下载。CSP 限制外部脚本、资源和网络接口。提供“停止运行”，移除 iframe；这不是 CPU／内存配额或绝对的网络隔离，读者不应输入敏感信息。

支持本地普通 JS、CSS、图片和字体：HTML 的相对路径按 HTML 所在目录解析；CSS 内 `url(...)` 按 CSS 所在目录解析，图片可无损优化后内嵌。文件缺失、超限、外部资源、ES module、CSS `@import`、`srcset` 等暂不支持的静态依赖会在写入前报错。请把 HTML 先打包成自包含演示；运行时动态加载、`eval`、远程 API 不在本期支持范围，可能被 CSP 拦截。普通 `.js`／可执行文件仍不能作为公开独立附件上传，只能作为 HTML 包内数据处理。不需要增加服务器、数据库或密钥。

`--dry-run` 的 `kind`、`references` 和 `html_documents` 分别列出主文章身份、引用文档身份、HTML 查看页及包内依赖。源 HTML／JS 只解析、打包，不会在上传或构建时执行。

`--publish` 要求 main 分支且工作区干净，先同步远端，随后仅提交本篇文章与引用资源。重复导入会拒绝覆盖已有文章；修改已发布文章请编辑仓库中的文件。发布的图片与附件会成为公开资源。验证脚本可运行 `ruby -Itest test/publish_post_test.rb`。

## 文章目录与标题链接

正文中的一至六级 Markdown 标题会自动生成可分享的 URL，并按层级缩进显示在文章目录中。文章自身的标题不会重复纳入目录。建议从二级标题开始组织正文，也支持以一级标题组织文章：

```markdown
## 二级标题

### 三级标题

#### 四级标题
```

读者可以点击左侧目录快速跳转，也可以点击标题末尾的 `#` 获取定位到该标题的链接。较长目录在桌面端可以独立滚动。没有正文标题的短文不会显示目录。

## 阅读统计

站点使用 GoatCounter 记录页面浏览；统计端点配置在 `_config.yml` 的 `analytics.goatcounter_endpoint`。文章页会在日期与标签旁显示“浏览 N”，统计服务不可用或尚未开放公开计数时会静默隐藏该项，不影响阅读。不要将 GoatCounter 的密码或管理令牌提交到仓库。

字数与预计阅读时间会由正文自动计算，无需在文章 YAML 中填写。字数按渲染后正文去除标记和空白的字符数计算；预计阅读时间按每分钟 400 字向上取整。

## 管理文章分类

所有分类统一配置在 `_data/categories.yml`。每个分类包含：

```yaml
- slug: tech
  name: 技术
  description: 编程、工具与技术实践。
```

文章通过 `categories` 引用分类的 `slug`，支持一个或多个分类：

```yaml
categories: [tech, projects]
```

新增分类时，先在 `_data/categories.yml` 中添加配置，再在文章中使用对应的 `slug`。博客的分类导航、分类页和文章标签会自动更新。

分类名称和文章分类标签均可点击，进入 `/categories/<slug>/` 查看该分类下的全部普通文章（按日期倒序）。空分类会显示空状态；引用资料不进入分类列表。部署时自动根据 YAML 生成独立分类页，新增分类不需要手写页面。本地构建 Jekyll 前先运行 `ruby scripts/generate-category-pages.rb`，生成目录 `generated-categories/` 不提交到 Git。

## 修改博客信息

- 博客名称、简介和作者：编辑 `_config.yml`
- 关于页面：编辑 `about.md`
- 样式：编辑 `assets/css/style.css`

## 本地预览（可选）

安装 Ruby 与 Bundler 后运行：

```bash
bundle exec jekyll serve
```

需要同时验证全文搜索时，在 Jekyll 构建完成后运行：

```bash
npm ci
npm run search:index
```

推送到 `main` 后，GitHub Actions 会依次构建 Jekyll、生成中文全文索引并发布到 GitHub Pages。
