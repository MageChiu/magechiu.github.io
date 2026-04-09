# Debug Session

- Status: OPEN
- Symptom: 目标页面 `https://magechiu.github.io/note/scheduler/Optimization_of_Cloud_Computing_Resource_Utilization_Based_on_Hotspot_Scheduling_and_Resource_Oversubscription.md/` 返回 404
- Expected: 对应笔记页面应正常渲染

## Hypotheses

- H1: 外部访问 URL 多带了 `.md` 后缀，而站点实际 permalink 会移除 `.md`
- H2: `note/scheduler/...` 页面没有被 Jekyll 识别成 page，因此未生成目标 HTML
- H3: 链接生成逻辑在某处直接拼接了文件名，未去掉 `.md`
- H4: 该文档 front matter 或目录结构异常，导致构建时被跳过
- H5: 站点已生成正确路径，但线上访问的是错误地址
