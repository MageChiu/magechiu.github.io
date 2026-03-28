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

公开展示的论文列表使用 `_data/papers.yml` 维护。建议每篇论文包含：

- `title`
- `authors`
- `venue`
- `year`
- `url`
- `summary`
- `tags`
- `featured`

如果后续需要补充论文截图、阅读笔记或配套图片，可以放到：

```text
resources/papers/
```

## 四、分类元信息规范

不要再使用 `note/<目录>/index.md` 这种公开页面承载说明。分类标题与描述统一写在：

```text
_data/note_categories.yml
```

例如：

```yml
- key: kubernetes
  title: Kubernetes
  description: 记录 Kubernetes、Operator、GPU 调度与云原生基础设施相关的长期技术笔记。
```

如果某个目录没有配置分类元信息，公开页面仍可展示文章，只是目录名称会回退到原始文件夹名。

## 五、不要公开的内容

以下内容统一放在 `internal/` 下：

- 写作约束
- 维护手册
- GitHub Pages 操作说明
- 排障记录

这些内容保留在仓库中，但不应通过博客页面对外展示。
