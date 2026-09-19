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

## 文章目录与标题链接

正文中的 Markdown 标题会自动生成可分享的 URL，并显示在文章目录中。建议从二级标题开始组织正文：

```markdown
## 二级标题

### 三级标题

#### 四级标题
```

读者可以点击左侧目录快速跳转，也可以点击标题末尾的 `#` 获取定位到该标题的链接。没有任何二级至四级标题的短文不会显示目录。

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
