# GitHub Pages 配置与发布说明

这里保留站点维护总览，面向仓库维护者使用，不对博客访客公开展示。

## 维护文档索引

- `internal/docs/setup.md`：GitHub Pages 与 workflow 配置步骤
- `internal/docs/writing-guide.md`：新增笔记与论文资源时的写作规范
- `internal/docs/directory-structure.md`：仓库目录职责与公开/隐藏边界
- `internal/docs/troubleshooting.md`：本地预览、CI 与部署常见问题

## 当前站点的核心约定

- 技术笔记主目录：`note/`
- 笔记图片目录：`resources/images/`
- 公开论文资源页源码：`resources/papers/index.md`
- 论文结构化数据：`_data/papers.yml`
- 笔记分类元信息：`_data/note_categories.yml`
- 首页专题目录：由 `_config.yml` 中的 `homepage_note_directory` 控制
- 内部维护文档：统一放在 `internal/` 下，并通过 `_config.yml` 排除发布

## 推荐维护顺序

1. 先在 `note/` 或 `_data/papers.yml` 中更新内容。
2. 如需新增目录或展示逻辑，同时更新 `internal/docs/directory-structure.md`。
3. 本地执行构建验证。
4. 检查 GitHub Actions 的 `verify.yml` 与 `pages.yml` 是否通过。

如果后续站点结构再次调整，优先更新以上拆分后的四份文档，而不是把所有说明重新堆回一个文件。
