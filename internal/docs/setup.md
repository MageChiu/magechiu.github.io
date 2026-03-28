# GitHub Pages 与 Workflow 配置

本文档说明如何把当前仓库配置成可自动发布的 GitHub Pages 技术博客。

## 一、首次配置 GitHub 仓库

1. 打开仓库主页。
2. 进入 **Settings**。
3. 打开左侧 **Pages**。
4. 在 **Build and deployment** 中，把 **Source** 选择为 **GitHub Actions**。

> 当前仓库不是依赖 GitHub Pages 自带的旧版 Jekyll，而是通过 Actions 构建后发布。

## 二、仓库已包含的 workflow

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

## 三、首次发布步骤

1. 把当前仓库代码推送到 GitHub。
2. 确保默认分支是 `main`。
3. 在仓库 **Actions** 页面确认以下 workflow 会运行：
   - `Verify Jekyll site`
   - `Deploy Jekyll site to Pages`
4. 等待 `Deploy Jekyll site to Pages` 成功。
5. 回到 **Settings -> Pages**，确认页面地址已经生成。

如果仓库名是：

- `magechiu.github.io`：默认地址通常是 `https://magechiu.github.io/`
- 其他仓库名：默认地址通常是 `https://<用户名>.github.io/<仓库名>/`

## 四、站点个性化配置

主要修改 `_config.yml`：

```yml
title: Peng Zhao Tech Notes
description: 面向 GitHub Pages 的技术博客，聚焦云原生、工程实践与个人技术笔记。
url: "https://magechiu.github.io"
baseurl: ""
homepage_note_directory: kubernetes

email: charles.r.chiu@outlook.com

author:
  name: Peng Zhao
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

## 五、本地预览方法

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

## 六、推荐发布流程

1. 本地新增或修改 `note/` 下文章、图片或论文数据。
2. 本地运行 `bundle exec jekyll build`。
3. 提交并推送到 GitHub。
4. 等待 `verify.yml` 校验通过。
5. 等待 `pages.yml` 自动发布完成。
