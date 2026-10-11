---
title: deepseek 文档的规范情况
date: '2026-10-12'
categories:
- tech
tags:
- DeepSeek
- 文档规范
- 软件工程
ai_generated: false
render_with_liquid: false
---


在我自己这里的话，基本上就是写文档，写 plan，工作的时候大部分也是审阅 ai 的文档觉得没问题就甩给同事。Deepseek harness 刚出来的时候看了一下整个项目，除了设计上很牛，文档的组织也很好的融合了 AI。这里简单探究一下 。

这是 deepseek 的文档结构
# 动态的 、需要决策执行相关的文档
```
my-deepseek-harness/
└── .agents/notes/                    # 按生命周期管理决策与提案；各记录包含英文、中文和配对记录三件套。
    ├── proposed/                    # 未完成提案，可包含计划、验收条件和风险。
    │   └── <class>/
        ├── yyyy-mm-dd-topic.md             
        ├── yyyy-mm-dd-topic.zh.md          
        └── yyyy-mm-dd-topic.i18n.yaml      
    ├── implemented/                 # 已发布决策；仍有指导价值的保持活跃，事实随实现更新。
    │   ├── AGENTS.md
    │   └── <class>/…
    ├── rejected/                    # 被否决提案；仅在仍能防止合理错误时保留。
    │   └── <class>/…
    └── archived/                    # 仅归档符合条件的已实现记录；封存后永久冻结，不作为当前行为权威。
        ├── AGENTS.md
        └── <class>/…
```

这里分为 skills 和 agent.md 这两种，每一个文件夹下的 agents.md 都有自己这一部分的信息、约束，skill 就是负责某些流程，并且差不多是覆盖了比较完整的软件开发流程内容。包括提案提出问题、精简文本、输出对人类友好文档、代码 review、推送代码前检查的这些步骤。
也就是这些 skill，并且这里的内容实际上也是代替了 github 的 issue 功能（个人感觉）。
```
dsh-find-simplifications 
dsh-pre-push-checks
dsh-prose-standard
dsh-doc
dsh-code-review
```
并在这里和项目的架构、设计理念结合的很密切，很🐮，我尝试看了一下里面的信息密度还是挺高的。

这些 skill 个人觉得也是根据 deepseek 团队内部曾出现过的一些问题迭代过。询问 ai 后发现确实是迭代过很多次的，把一些经验也沉淀到里面了
<img src="/assets/posts/2026-10-12-deepseek-documentation/2493e260f5a96f660341d8e296e8217e7bcc7d9be41ca3561c9a5a7d6ca75478.png" alt="Pasted image 20261011234312.png" width="712">
> 当然，在这里的 skill 节省了一些提案、执行、review 的时间，但是在整体架构上并没有直接的帮助。这部分内容几乎是纯粹的靠人的决策的，甚至我在阅读这个 skill 的时候还觉得 skill 的部分内容是建立在当前项目架构的基础上的。


我这里思考一下如何能够让其它的项目也能够做出这种开发的文档规范和执行。所以暂时从这里的思考角度剖离了点东西，然后做了一个 skill，当然我这里暂时就没有考虑翻译这类的东西了，这块对前沿企业来说相对重要些不过我暂时也就个人用一下。
[项目开发流程 Skill 生成器](https://github.com/fengwuqingchen/agent-skills/blob/main/skills/dev-flows-skills-create/SKILL.md)
> 暂时没有做太多的约束，关于文档的目录结构优先级：用户明确指定 > 项目已有结构与规范 > agent 根据项目确定
> 特殊、边界情况暂未考虑。比如 agent 是否可能会在项目中自主的添加规划新的目录。这块比如 claude 我觉得会，gpt 应该不会。关于后面怎么加怎么考虑，还是等我先尝试使用一段时间吧。

后续如果想到什么点可能还会修改一下。整体上还是会保持足够的通用。
另外是我觉得这里的许多 agents.md 也不错，对于一个文件夹的这个文件来说，应该是只需要有重要约束就可以了。没有必要加入普通的能够从代码中获取到的信息。这样也可以尽可能的减少需要维护的工程量。

后面的内容其实也是由同样的 skill 来进行的维护。但我觉得还是挺有意思，就在这里记录下来了。
# 相对来说需要长期维护的 、关于项目本身信息的文档
```
my-deepseek-harness/
├── AGENTS.md
├── .agents/
│   ├── skills/                      # 文档管理工作流及其详细规则、校准案例和模板。
│   │   ├── dsh-doc/
│   │   │   ├── SKILL.md
│   │   │   ├── references/
│   │   │   └── templates/
│   │   ├── dsh-prose-standard/
│   │   ├── dsh-trim-cot-leakage/
│   │   ├── dsh-translate-docs/
│   │   ├── dsh-create-upgrade-guide/
│   │   ├── dsh-archive-agent-notes/
│   │   └── dsh-pre-push-checks/
├── docs/                            # 文档总规范及当前架构、开发流程、测试和术语参考。
│   ├── AGENTS.md
│   ├── development.md
│   ├── architecture.md
│   ├── testing.md
│   ├── glossary.md
│   ├── …
│   ├── i18n/                        # 双语配对、翻译规则、术语、文体及自动翻译提示词。
│   │   ├── README.md
│   │   ├── translation-rules.md
│   │   ├── terminology.md
│   │   ├── style-samples.md
│   │   └── translation-prompt.md
│   ├── cookbook/                    # 贡献者操作教程。
│   ├── subsystems/                  # 子系统类型、语义及生成 API 参考。
│   ├── cordis-api/
│   ├── cordis-tutorial/
│   ├── persistence-changes/         # 持久化变更确认与历史证据，区别于当前运行时契约。
│   │   ├── finalized/
│   │   ├── releases/
│   │   └── historical-formats/
│   ├── postmortem/                  # 故障经过、证据、因果及预防。
│   ├── *-catalog.md
│   └── module-graph.md
├── packages/                        # 各包长期维护的配置、行为、限制与扩展契约。
│   └── <group>/<package>/README.md
├── scripts/                         # 文档校验、配对、预算、生成及归档封存的实现和配置。
│   └── …
└── website/                         # 公开页面映射；网站正文从仓库源文档投影生成。
    └── docs.ts
```

# 指导用户使用的文档
```
my-deepseek-harness/
├── README.md
├── README.zh.md
├── SAFETY.zh.md
├── docs/
│   ├── user/                         # 用户文档主体，包含功能使用与面向扩展开发者的教程。
│   │   ├── index.md
│   │   ├── guide/                    # 功能使用、配置与集成指南。
│   │   │   ├── index.md
│   │   │   ├── providers.md
│   │   │   ├── network-proxy.md
│   │   │   ├── python-sdk.md
│   │   │   ├── github-review.md
│   │   │   ├── mcp-memory.md
│   │   │   └── schedule.md
│   │   └── develop/                  # 使用项目开发扩展的基础、框架机制与实践教程。
│   │       ├── basic/
│   │       │   ├── index.md
│   │       │   ├── config.md
│   │       │   ├── tool.md
│   │       │   └── publish.md
│   │       ├── framework/
│   │       │   ├── index.md
│   │       │   ├── service.md
│   │       │   └── events.md
│   │       └── practice/
│   │           ├── index.md
│   │           ├── dynamic-cordis.md
│   │           └── llm-adapter.md
│   └── upgrade-guide/                # 按起始发布版本组织破坏性变更及迁移步骤。
│       └── v0.1.7-rc.2/
│           ├── schedule-optional-bundle/
│           │   ├── guide.md
│           │   ├── guide.zh.md
│           │   └── guide.i18n.yaml
│           └── transcript-view-legacy-normal/
│               └── …
├── apps/cli/                         # CLI 应用说明与命令参考。
│   ├── README.md
│   └── reference/
│       ├── README.md
│       └── README.zh.md
├── python/sdk/                       # Python SDK 使用说明与示例。
│   ├── README.md
│   ├── README.zh.md
│   └── examples/
│       ├── README.md
│       └── README.zh.md
└── website/                          # 公开页面映射；网站正文由仓库源文档投影生成。
    └── docs.ts
```



# Ps
和 agent 聊天的时候还是用通用的事实聊好一些啊，知识有时候自己也一时没有理解哪些是通用的事实就是在 agent 反应和预期不一样的时候才注意到 😭😭😭

以及，重新回顾了一下与 ai 的聊天，觉得我聊的时候整体方向调整的次数还是很多的，还是应该对整体有把握后在细分的探索。不然 ai 还是重复的生成了一些我不需要的内容，导致找来照去的很麻烦。或者说应该先把一个探索的方向和整体思路确定下来。

现在的很多 skill 其实并没有关注到人本身。如果 skill 能够有个文件把使用的方法、相关的约束这类信息告诉人，并且告诉人可以使用哪些术语更好的表达自己的想法，我觉得也许会方便不少？
