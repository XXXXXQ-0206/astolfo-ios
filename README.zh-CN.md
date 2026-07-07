# Astolfo

[![English README](https://img.shields.io/badge/README-English-blue)](README.md)

**Astolfo** 是面向 Apple 平台的 local-first 文档智能应用，目标是逐步演进为强大的 Document RAG Agent 和 AI Knowledge Workspace。

**ASTOLFO** 是 **Agent for Semantic Text Operations on Large Filebases & Ontologies** 的缩写。

Astolfo 当前是一个原生 iOS 离线文本集合阅读器。项目使用 SQLite/FTS5 做本地目录和搜索，并将阅读状态保存在设备本地。

## 项目定位

- Local-first：文档和阅读状态以保存在本机为核心设计。
- Privacy-first：公开版本不包含分析、跟踪、同步服务或内置文档内容。
- Apple Native：当前应用是使用 Swift 和 UIKit 构建的原生 iOS 工程。
- Semantic Retrieval：当前搜索层基于本地 SQLite/FTS5，为未来语义检索打基础。
- Document Intelligence：项目围绕大型本地文档集合、元数据、搜索和阅读工作流组织。
- AI Knowledge Workspace：未来能力会建立在本地文档库之上，而不是替换成本质上的云端优先流程。

## 当前能力

- 原生 iOS 源码。
- UIKit/Swift 阅读界面。
- 本地 SQLite 目录和全文搜索逻辑。
- 收藏、最近阅读、最近删除和阅读状态持久化逻辑。
- 本地标签和简介元数据解析。
- 可用 Xcode 打开的工程结构。

## 不包含内容

公开仓库刻意不包含：

- 书库数据库或文本文件。
- 用户阅读状态、收藏、搜索历史、最近删除记录或偏好设置。
- 私有运行时数据。
- 签名凭据或本机环境元数据。
- 任何私有内容。

## 书库数据库

应用运行时需要本地数据库 `Books.sqlite`。本仓库不分发数据库。使用时请在自己的设备上创建或导入自己的本地数据库。

应用也支持通过 `Books.sqlite.part-0000`、`Books.sqlite.part-0001` 等分片文件和 manifest 文件在运行时组装数据库。这些运行时数据文件已被 Git 忽略。

## 标签和简介格式

文本文件可以在开头嵌入标签和简介。为了同时兼容导入工具和 app 运行时解析器，推荐使用下面的格式：

```text
【标签】#经典 #短篇 #离线
【简介】这里是一行简短的作品简介。

正文从这里开始……
```

格式要求：

- 标签行放在简介行之前。
- 第一行应以 `【标签】` 开头。
- 第二行应以 `【简介】` 开头。
- 多个标签用空白字符分隔。
- 希望在 app 中展示的标签应以 `#` 开头。
- 为兼容导入工具，简介请保持为单行。
- 建议使用 UTF-8 文本编码。

app 运行时有兜底解析：会在正文前 1,200 个字符和前 8 行内寻找以 `【标签】` 或 `【简介】` 开头的行。但导入工具按前两行解析，因此最稳妥的格式仍是上面的示例。

## 构建

1. 用 Xcode 打开 `App.xcodeproj`。
2. 设置你自己的 bundle identifier 和签名团队。
3. 在 iOS 设备或模拟器上构建运行。

默认 bundle identifier 是占位值：`com.example.astolfo`。

## Vision and Roadmap

Astolfo 的长期方向是从本地文本阅读器演进为 local-first 文档智能工作空间。

规划方向包括：

- 面向本地文件库的 Document RAG。
- Agent 辅助阅读、检索和标注工作流。
- 语义分块和 embedding 索引。
- 知识图谱和 ontology-aware 文档组织。
- MCP 兼容集成。
- 通过用户自定义 provider 实现多模型支持。
- 在保护隐私的前提下扩展 Apple 原生跨设备工作流。

除非源码中已经明确实现，上述路线图内容均属于未来规划，不代表当前版本已具备这些能力。

## 隐私

Astolfo 当前公开版本面向本地阅读，不包含分析、跟踪、网络同步、云端上传或任何内置阅读内容。

## 仓库卫生

发布前会检查仓库，确保数据库文件、压缩包、本地路径、签名数据和私有阅读内容没有进入公开版本。
