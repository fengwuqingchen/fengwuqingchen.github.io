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
   tags: [分类]
   ---
   ```

4. 在下方写正文，提交到 `main` 分支。
5. GitHub Pages 会自动构建，通常一两分钟后线上博客就会更新。

可以复制 `_drafts/article-template.md` 作为模板。草稿放在 `_drafts` 中不会公开；写完后移动到 `_posts` 并按日期重命名即可发布。

## 修改博客信息

- 博客名称、简介和作者：编辑 `_config.yml`
- 关于页面：编辑 `about.md`
- 样式：编辑 `assets/css/style.css`

## 本地预览（可选）

安装 Ruby 与 Bundler 后运行：

```bash
bundle exec jekyll serve
```

