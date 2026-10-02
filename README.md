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

无需安装额外依赖，使用 Ruby 脚本。先检查文章及资源清单：

```bash
ruby scripts/publish-post.rb "/绝对路径/2026-10-2-文章.md" --slug article-name --dry-run
```

确认后发布（自动导入文章和资源、提交、推送 main，触发 GitHub Pages）：

```bash
ruby scripts/publish-post.rb "/绝对路径/2026-10-2-文章.md" --slug article-name --publish
```

不加 `--publish` 时仅导入到仓库，可检查后手动提交。源 Markdown 和原附件不会修改。普通文章需要 YAML 中的 `title` 和已注册的 `categories`；日期从文件名读取，支持非补零日期，也可用 `--date YYYY-MM-DD` 指定。`--slug` 固定文章 URL，避免中文或空格带来的链接不便。无 YAML front matter 的 Markdown 默认作为 AI 引用资料发布（不进入普通文章列表）；无日期时使用当天日期。

支持 Obsidian `![[图片.png]]` / `[[附件.pdf]]`，普通 Markdown 图片、附件链接、引用式链接，以及 HTML 的 `src` / `href`。脚本在文章同目录与 `attachments` 中寻找资源；找不到时按文件名搜索文章所在目录，也可用 `--vault "/Obsidian库路径"` 搜索整个库。同名文件不唯一、链接缺失或超限会报错，校验全部成功后才写入。代码块中的示例链接不会作为附件导入；外部 URL 不会下载。

### 仅供引用的文章 / AI 资料

正文中的 `[[资料]]`、`[[资料.md|链接文字]]`、`[资料](资料.md)` 及引用式 Markdown 链接会递归导入本地笔记，改写成可点击的博客阅读页。`![[资料]]` 也转换为链接，不把整篇资料直接嵌入正文。文件名省略 `.md` 的写法仅支持 Obsidian 链接。引用文件中的图片、附件按该文件所在目录解析并一起上传。

主文章为第 0 层，允许「主文章 → 引用资料（第 1 层）→ 引用资料（第 2 层）」。第 2 层再引用本地 Markdown、循环引用、文件缺失或同名歧义都会在写入前报错；外部网址不参与层数限制。清单中的 `references` 包含即将上传的引用文章。

所有从正文递归导入的笔记都放在 `_references/`，不加入 `_posts/`：不出现在首页、分类、站内搜索或 RSS，搜索引擎也收到 `noindex` 指令。可以通过文章中的链接或直接 URL 阅读；这不是隐私保护或访问控制，公开仓库仍能查看原文。

无 front matter 的资料自动设置 `ai_generated: true`，标题取文件名。有 YAML 的资料保留标题等元数据；可用 `ai_generated: true` 标明 AI 文，`ai_generated: false` 标明人工资料。引用资料一律强制隐藏于发现入口，不会因 YAML 中的分类、`search_exclude: false` 或自定义 `permalink` 而重新出现。

若单独发布带 YAML 的 AI 文，设置 `ai_generated: true`；人工资料可设置 `reference_only: true`。这两种文章也会进入独立引用目录。引用 Markdown 自身受单附件上限约束，所有引用 Markdown、图片和附件共同计入整次上传的总上限。重复引用不会重复计入大小，正文和资源源文件均不会修改。已有普通文章的再编辑仍需在仓库中操作，本脚本不覆盖已发布的主文章。

默认单张图片上限 10 MiB、单个其它附件 20 MiB、整篇资源合计 100 MiB，可以用 `--image-mb`、`--attachment-mb`、`--total-mb` 调整。资源按内容哈希命名并转换成公开的 `/assets/posts/…` 链接，保留原始文件，不会自动压缩。可执行文件和 HTML/JS 附件会拒绝发布。

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
