# 本地预览与部署排障

## 一、Pages 页面没有更新

检查：

- `Actions` 里的 `Deploy Jekyll site to Pages` 是否成功
- `Settings -> Pages` 的 Source 是否为 **GitHub Actions**
- 提交是否已经推送到 `main`

## 二、静态资源路径不对

如果仓库不是 `username.github.io` 形式，需要检查 `_config.yml`：

```yml
baseurl: "/你的仓库名"
```

同时检查模板中是否统一使用了 `relative_url`。

## 三、首页没有显示某个专题目录的文章

检查：

- `_config.yml` 里的 `homepage_note_directory`
- 文章是否真实放在 `note/<专题目录>/` 下
- 文章 front matter 是否包含 `date`
- 文章是否误写成 `index.md`

## 四、某篇 Markdown 没有出现在笔记列表里

优先检查是否缺少 front matter。没有 front matter 的 Markdown 可能不会进入 `site.pages`，因此首页和笔记页都不会展示。

## 五、GitHub Actions 中 bundle 失败

如果日志里出现 bundler 相关报错，重点检查：

- `Gemfile.lock` 里的 `BUNDLED WITH` 版本
- `.github/workflows/pages.yml` 和 `.github/workflows/verify.yml` 中是否显式声明了兼容的 bundler 版本
- Ruby 版本与 GitHub Actions 中的 `ruby/setup-ruby` 是否匹配

## 六、本地 Ruby 环境与 CI 不一致

当前仓库可能出现：

- 本地 Ruby / RubyGems / Bundler 较旧
- CI 使用 Ruby 3.2 与较新的 Bundler

如果本地构建失败，但 CI 可以通过，优先判断是不是本机环境问题，而不是直接修改站点模板。

## 七、推荐的排障顺序

1. 先看 Jekyll 构建错误是否能定位到具体文件。
2. 再检查 front matter、路径与 `relative_url`。
3. 然后看 `_data/` 中的结构化数据是否字段缺失。
4. 最后再检查 Bundler 与 GitHub Actions 环境。
