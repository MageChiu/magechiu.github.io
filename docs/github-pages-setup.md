# GitHub Pages 配置与发布说明

本文档说明如何把当前仓库配置成可自动发布的 GitHub Pages 技术博客。

## 一、仓库内容约定

- 技术笔记目录：`note/`
- 笔记图片目录：`resources/images/`
- 首页当前专题目录：由 `_config.yml` 中的 `homepage_note_directory` 控制

例如：

```text
note/
  kubernetes/
    operator.md
resources/
  images/
    operator-cover.jpg
```

## 二、首次配置 GitHub 仓库

1. 打开仓库主页。
2. 进入 **Settings**。
3. 打开左侧 **Pages**。
4. 在 **Build and deployment** 中，把 **Source** 选择为 **GitHub Actions**。

> 这一步非常关键。当前仓库不是依赖 GitHub Pages 自带的旧版 Jekyll，而是通过 Actions 构建后发布。

## 三、当前仓库已经包含的 workflow

### 1. 发布 workflow

文件：`.github/workflows/pages.yml`

作用：

- 当 `main` 分支有新提交时自动构建站点
- 把 `_site` 目录作为产物上传
- 自动部署到 GitHub Pages

### 2. 校验 workflow

文件：`.github/workflows/verify.yml`

作用：

- 在 `pull_request` 和 `main` 分支 push 时执行
- 用 `bundle exec jekyll build --trace` 验证站点是否能正常构建

## 四、首次发布步骤

1. 把当前仓库代码推送到 GitHub。
2. 确保默认分支是 `main`。
3. 在仓库 **Actions** 页面确认以下 workflow 会运行：
   - `Verify Jekyll site`
   - `Deploy Jekyll site to Pages`
4. 等待 `Deploy Jekyll site to Pages` 成功。
5. 回到 **Settings -> Pages**，确认页面地址已经生成。

如果你的仓库名是：

- `magechiu.github.io`：默认地址通常是 `https://magechiu.github.io/`
- 其他仓库名：默认地址通常是 `https://<用户名>.github.io/<仓库名>/`

## 五、站点个性化配置

主要修改 `_config.yml`：

```yml
title: Charles Zhao Tech Notes
description: 面向 GitHub Pages 的技术博客，聚焦云原生、工程实践与个人技术笔记。
url: "https://magechiu.github.io"
baseurl: ""
homepage_note_directory: kubernetes

email: zhaopeng.charles@gmail.com

author:
  name: Charles Zhao
  github: MageChiu

profile:
  subtitle: 平台工程 / 云原生 / AI 工程化
  avatar: /resources/images/operator-cover.jpg
  intro: 持续记录 Kubernetes、工程效率、平台能力建设与个人技术实践。
  location: Shanghai, China
```

### 需要重点调整的字段

- `url`：线上域名
- `baseurl`：如果不是用户主页仓库，通常需要写成 `/<仓库名>`
- `homepage_note_directory`：首页展示哪个专题目录
- `author.name`：站点头部名称
- `profile.avatar`：首页左侧头像图

## 六、如何新增文章

1. 在 `note/` 下创建 Markdown 文件，例如：

```text
note/golang/context.md
```

2. 在文件头部写 front matter：

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

3. 如果文章有图片，把图片放到：

```text
resources/images/
```

4. 在正文中这样引用：

```md
![示例图片](/resources/images/go-context-cover.png)
```

## 七、本地预览方法

```bash
bundle config set --local path "vendor/bundle"
bundle install
bundle exec jekyll clean
bundle exec jekyll build
bundle exec jekyll serve
```

默认访问：

```text
http://127.0.0.1:4000
```

## 八、常见问题

### 1. Pages 页面没有更新

检查：

- `Actions` 里的 `Deploy Jekyll site to Pages` 是否成功
- `Settings -> Pages` 的 Source 是否为 **GitHub Actions**
- 提交是否已经推送到 `main`

### 2. 静态资源路径不对

如果你的仓库不是 `username.github.io` 形式，需要检查：

```yml
baseurl: "/你的仓库名"
```

### 3. 首页没有显示某个专题目录的文章

检查：

- `_config.yml` 里的 `homepage_note_directory`
- 文章是否真实放在 `note/<专题目录>/` 下
- 文章 front matter 是否包含 `date`

## 九、推荐发布流程

推荐使用下面这个流程维护站点：

1. 本地新增或修改 `note/` 下文章
2. 本地运行 `bundle exec jekyll build`
3. 提交并推送到 GitHub
4. 等待 `verify.yml` 校验通过
5. 等待 `pages.yml` 自动发布完成

这样可以最大程度避免“本地能看、线上失败”的问题。
