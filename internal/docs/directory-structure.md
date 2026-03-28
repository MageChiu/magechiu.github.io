# 仓库目录结构说明

本文件用于说明当前博客仓库中各目录的职责边界，方便后续继续扩展而不破坏公开展示逻辑。

## 一、公开内容目录

```text
note/                  技术笔记 Markdown
resources/images/      笔记引用图片
resources/papers/      论文资源页面及相关静态资源
_data/                 站点结构化数据
_layouts/              页面布局模板
_includes/             可复用模板片段
assets/css/            站点样式
```

### 关键公开文件

- `index.md`：站点首页
- `notes.md`：全部笔记页
- `resources/papers/index.md`：公开论文资源页
- `_data/note_categories.yml`：笔记分类配置
- `_publications/`：论文元数据 collection

## 二、隐藏维护目录

```text
internal/docs/
```

该目录用于保存维护手册、写作规范与排障说明，并通过 `_config.yml` 中的 `exclude` 排除发布。

## 三、当前公开展示链路

### 技术笔记

1. `note/` 下的 Markdown 页面被 Jekyll 识别。
2. `_layouts/note.html` 负责单篇笔记展示。
3. `_layouts/home.html` 负责首页的当前专题与主题概览。
4. `_layouts/notes.html` 负责所有笔记的分组展示。
5. `_includes/note_card.html` 负责笔记卡片渲染。

### 论文资源

1. `_publications/` 保存公开展示的论文元数据。
2. `resources/papers/` 保存本地 PDF 等论文资源文件。
3. `resources/papers/index.md` 提供公开入口页。
4. `_layouts/papers.html` 负责论文资源页布局。
5. `_includes/paper_card.html` 负责论文卡片渲染。
6. `_layouts/home.html` 首页展示精选论文预览。

## 四、后续扩展建议

- 新增公开专题时，优先沿用 `_data/*.yml` 存放元信息，不要把说明写成公开页面。
- 新增静态资源时，先判断是否属于公开内容；只有公开内容才进入 `resources/`。
- 新增内部说明时，统一放在 `internal/docs/`。
