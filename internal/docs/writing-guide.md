# 内容写作与资源维护规范

本文档只给维护者看，用于约束公开内容如何放置，避免把维护说明暴露在博客页面上。

## 一、技术笔记的放置方式

技术内容统一放在 `note/` 下，建议使用按主题分目录的结构：

```text
note/
  kubernetes/
  scheduler/
  golang/
```

文章文件建议为 Markdown，并在文件头部写 front matter：

```md
---
title: Go context 使用笔记
date: 2026-03-28
summary: 记录 context 的取消、超时与传值使用方式。
tags:
  - golang
  - context
hero_image: /resources/images/go-context-cover.png
---
```

最少建议包含：

- `title`
- `date`
- `summary`

如果缺少 front matter，Jekyll 可能不会把该 Markdown 当作公开页面处理。

## 二、图片资源规范

笔记引用图片统一放在：

```text
resources/images/
```

正文中使用绝对路径引用：

```md
![示例图片](/resources/images/go-context-cover.png)
```

## 三、论文资源规范

公开展示的论文列表优先由目录自动识别：

- `_publications/`：维护带完整元数据的论文条目
- `resources/papers/`：自动识别本地 PDF，并在没有对应 `_publications/*.md` 时自动出现在 `/papers/`

如果你希望某篇论文拥有更完整的信息（例如作者、摘要、引用、详情页、featured 展示），建议继续创建 `_publications/*.md` 元数据文件，并包含：

- `title`
- `collection: publications`
- `category`
- `date`
- `venue`
- `paperurl`
- `authors`
- `excerpt`
- `citation`
- `tags`
- `featured`

如果后续需要补充论文 PDF、截图、阅读笔记或配套图片，可以放到：

```text
resources/papers/
```

如果 `resources/papers/` 里只是新增了本地 PDF，现在**不再需要**同步补 `_publications/*.md` 才能被识别；构建时会自动生成基础条目。

只有在你需要以下能力时，才建议补 `_publications/*.md`：

- 自定义标题
- 自定义分类 `category`
- 自定义摘要、作者、引用
- 独立详情页 `/publication/.../`
- 首页 featured 展示

## 四、分类元信息规范

`note/` 下新增主题目录后，系统会在构建时自动识别主题，并在缺少物理 `index.md` 时自动生成专题页。

如果你只需要基础展示，可以直接新增：

```text
note/<topic>/<article>.md
```

如果你想自定义专题标题和描述，仍然推荐维护：

```text
_data/note_categories.yml
```

例如：

```yml
- key: kubernetes
  title: Kubernetes
  description: 记录 Kubernetes、Operator、GPU 调度与云原生基础设施相关的长期技术笔记。
```

如果某个目录没有配置分类元信息，公开页面仍可展示文章，只是标题与描述会回退到自动生成值。

## 五、不要公开的内容

以下内容统一放在 `internal/` 下：

- 写作约束
- 维护手册
- GitHub Pages 操作说明
- 排障记录

这些内容保留在仓库中，但不应通过博客页面对外展示。
