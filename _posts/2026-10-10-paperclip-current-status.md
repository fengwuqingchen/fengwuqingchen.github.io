---
title: paperclip 当前的一些情况
date: '2026-10-10'
categories:
- tech
tags:
- Paperclip
- 多智能体
ai_generated: false
render_with_liquid: false
---


# 关于项目的 git 历史分析发展情况

比如说我这三天主要看的 watchdog 这块的内容，这块在以前是存在过很多的 issue、pr 的，我自己看着也提了两个 issue、6 个 pr，但是都是小修复。我想着现在大概率其实也不会被合并，因为我觉得维护者应该也觉得现在的 issue、pr 确实太多了，某一部分的内容总是在重复的提交 issue、pr，但现在在这里可能一定程度上还是需要重构部分的内容。

下面是我让 AI 找到的部分 pr，一部分是不同模块之间边界的问题，一部分是 watchdog 本身的问题
![Pasted image 20261004222551.png](/assets/posts/2026-10-10-paperclip-current-status/962c881dc580e7f22cafb3cdae4e0f09a65d200625719618cde19f33dc33c6b4.png)

# 尝试探索项目存在的一些问题
## 部分的数据结构承担了过多的责任

另外我目前看起来觉得一些结构体承担的责任好像也挺多的
比如：

`stopFingerprint`
本来作用应该是：标识一次停止状态的业务内容，表达所选取的停止状态事实有没有变化
```ts
const fingerprintPayload = {
  version: 2,                  // 指纹算法版本
  companyId: "company-1",       // 公司范围
  watchedIssueId: "task-A",     // 被监督的业务根

  // 业务树中尚未结束的结构叶，只保留关键字段
  materialLeaves: [
    {
      issueId: "task-B",
      status: "blocked",
      assigneeAgentId: "agent-deploy",
      assigneeUserId: null,

      blockerIssueIds: ["task-C"],       // B 被 C 阻塞
      pendingInteractionIds: [],        // B 的待处理交互 ID
      pendingApprovalIds: ["approval-1"] // B 的待处理审批 ID
    }
  ],

  // 树中所有非终态任务的待处理交互/审批；
  // 不仅限于叶节点，只保留存在等待项的任务
  waitsByIssueId: {
    "task-B": {
      pendingInteractionIds: [],
      pendingApprovalIds: ["approval-1"]
    }
  }
};

// ...
// 后续通过这个方法生成
const payload = JSON.stringify(fingerprintPayload);

const stopFingerprint =
  `task_watchdog_stop:${
    createHash("sha256").update(payload).digest("hex")
  }`;
```



新的作用：审查已完成”“执行已成功”或“现在仍然有修改权限“ 
例如：
```
agent 开始审查时看到：B 被 C 阻塞 → F1
agent 准备修改时重新读取：B 被 D 阻塞 → F2
       ↓
F2 !== F1，拒绝沿用旧观察执行修改
```

```
审查任务 W 正在处理 F1
当前停止状态也是 F1
       ↓ 再结合 W 的状态
认为已有审查仍然打开，暂不重新安排
```

```
上次记录：F1 已经审查
当前观察：仍然是 F1
       ↓
分类为 already_reviewed
```

这里的逻辑直接看的话其实也说的通，但是同样的问题在于这段代码是通过限制外部业务的逻辑来确保自身有效的，而外部业务应该是能足够灵活的。最好的方式应该是数据结构本身就能够说明业务信息



又比如这里，
本来的作用：表示任务状态、人工分配、等待和检查安排的字段
```ts
// issue_watchdogs：监督配置与最近一次结果摘要
{
  issueId,                  // 被监督的业务根
  watchdogAgentId,
  instructions,
  watchdogIssueId,          // 可反复复用的审查 Issue
  lastObservedFingerprint,
  lastReviewedFingerprint,
  lastObservedStopSnapshot,
  lastReviewedStopSnapshot,
}

// issues：同一张表也存普通业务任务
{
  id,
  parentId,                 // 审查任务挂在业务根下面
  originKind: "task_watchdog",
  originFingerprint,        // 本次关联的停止指纹
  status,					// 主要是这里的问题
  executionState,
  assigneeUserId,
  monitorNextCheckAt,
}
```

在这里的status本来只是告诉这个任务当前进行到哪里了
```
W.status = "todo";       // 审查任务待处理
W.status = "in_review";  // 审查任务进入审核阶段
W.status = "blocked";    // 审查任务被阻塞
W.status = "done";       // 审查任务完成
```

在这里的 watchdog 会通过这个尝试用这个状态来推导原因，并且这个是在第一版的时候就出现的，也就是和后续的 git 提交无关

| 通用字段本来的含义                               | watchdog 给它增加的解释 |
| --------------------------------------- | ---------------- |
| `status = blocked`：这个任务被阻塞              | 对应的停止状态可被记录为已审查  |
| `in_review + assigneeUserId`：进入审核且有人接手  | 可以认定已有审查处置       |
| `in_review + monitorNextCheckAt`：安排后续检查 | 可以认定已有审查处置       |

这个推导逻辑可能就有点限制业务逻辑在这个规则上的感受了，但是这里的业务逻辑我想着应该还是变化比较多的。问题也就是和上面的那个是一样的。

也许对一个数据结构来说有明确的业务限制会好一些？


## 某些模块在方法上的设计存在多个出口

比如现在关于 issue 的任务管理与取消协议这里的内容，现在的结构是
![mermaid-diagram (5) 1.png](/assets/posts/2026-10-10-paperclip-current-status/71cc700544e46d3dbe320ab66349944d52a96206aafa0f78f6261d6bf69d9e42.png)
我个人觉得比较好的结构是
![mermaid-diagram (6).png](/assets/posts/2026-10-10-paperclip-current-status/39f18cd679456329a711b73e68d8382176e2b61dd788c57d8aa05b52b7b3a6cf.png)
这样在方法上的一些内容就也不至于太过分散


# 给我自己的教训
我还是觉得这个东西主要是耦合性相对来说比较偏高，多个模块共同解释和修改同一组业务状态，业务上做的抽象不太够

然后我就试着看能不能探索一下这个原因，项目的维护者也是比较厉害的人，大概率不会犯我直接就能想到的错误

耦合性过高问题比较大，但是耦合性过低应该是没问题的吧，可能性能上会差点，但是对我来说无所谓，后面我可能就用类似部署在一个服务器上的微服务来设计我的下一个比较复杂程序了，不然以我的架构思维可能也把握不太住 :(








# 做一个个人的小记录，这里有个树的数据结构与业务进行结合的示例
关于 watchdog 的 worktree 这块的处理我觉得还是有点意思。这里只存着做个记录，就不细写了

数据库候选任务：
```
A
├── B
│   ├── E
│   └── F
├── C
└── W [originKind=task_watchdog]
    └── Q
```

EXT（另一棵树）：
```
如果监督根为 A，过滤后的业务子树：

A
├── B
│   ├── E
│   └── F
└── C

如果监督根改为 B，业务子树只剩：

B
├── E
└── F
```

另外这是 AI 给我的一个输入输出示例，对应这个方法
```
classifyTaskWatchdogSubtree(
  input: TaskWatchdogClassifierInput
): TaskWatchdogClassifierResult
```

示例树
```
    A 交付接口 [in_progress，但无可见业务 run/wake]
    ├── B 实现接口 [blocked，等待 INT-1，被树外 EXT 阻塞]
    ├── D 编写测试 [done]
    └── W watchdog 审查 [run 正在执行，但审查分支排除]

下面使用短 ID 演示纯函数
```


示例输入
```json
{
  "watchdog": {
    "companyId": "C1",
    "issueId": "A",
    "lastReviewedFingerprint": null,
    "lastReviewedStopSnapshot": null
  },
  "issues": [
    {
      "id": "A",
      "companyId": "C1",
      "identifier": "DEMO-A",
      "title": "交付接口",
      "status": "in_progress",
      "parentId": null,
      "assigneeAgentId": "agent-owner",
      "assigneeUserId": null,
      "originKind": null,
      "createdAt": "2026-10-03T00:00:00.000Z",
      "updatedAt": "2026-10-04T00:00:00.000Z",
      "latestCommentAt": null,
      "latestDocumentAt": null,
      "latestWorkProductAt": null
    },
    {
      "id": "B",
      "companyId": "C1",
      "identifier": "DEMO-B",
      "title": "实现接口",
      "status": "blocked",
      "parentId": "A",
      "assigneeAgentId": "agent-owner",
      "assigneeUserId": null,
      "originKind": null,
      "createdAt": "2026-10-03T00:00:00.000Z",
      "updatedAt": "2026-10-04T00:00:00.000Z",
      "latestCommentAt": null,
      "latestDocumentAt": null,
      "latestWorkProductAt": null
    },
    {
      "id": "D",
      "companyId": "C1",
      "identifier": "DEMO-D",
      "title": "编写测试",
      "status": "done",
      "parentId": "A",
      "assigneeAgentId": "agent-owner",
      "assigneeUserId": null,
      "originKind": null,
      "createdAt": "2026-10-03T00:00:00.000Z",
      "updatedAt": "2026-10-04T00:00:00.000Z",
      "latestCommentAt": null,
      "latestDocumentAt": null,
      "latestWorkProductAt": null
    },
    {
      "id": "W",
      "companyId": "C1",
      "identifier": "DEMO-W",
      "title": "watchdog 审查",
      "status": "in_progress",
      "parentId": "A",
      "assigneeAgentId": "agent-owner",
      "assigneeUserId": null,
      "originKind": "task_watchdog",
      "createdAt": "2026-10-03T00:00:00.000Z",
      "updatedAt": "2026-10-04T00:00:00.000Z",
      "latestCommentAt": null,
      "latestDocumentAt": null,
      "latestWorkProductAt": null
    }
  ],
  "activeRuns": [
    {
      "companyId": "C1",
      "issueId": "W",
      "agentId": "agent-reviewer",
      "status": "running"
    }
  ],
  "queuedWakeRequests": [],
  "blockers": [
    {
      "companyId": "C1",
      "blockerIssueId": "EXT",
      "blockedIssueId": "B"
    }
  ],
  "pendingInteractions": [
    {
      "companyId": "C1",
      "issueId": "B",
      "id": "INT-1",
      "kind": "request_confirmation",
      "status": "pending"
    }
  ],
  "pendingApprovals": [],
  "evaluatedAt": "2026-10-04T00:01:00.000Z",
  "firstRunGraceMs": 15000,
  "completedRunIssueIds": [
    "B"
  ]
}
```


示例输出
```json
{
  "state": "stopped",
  "reason": "No issue in the watched subtree has a live execution path.",
  "includedIssueIds": [
    "A",
    "B",
    "D"
  ],
  "stopFingerprint": "task_watchdog_stop:9b3f390c27da3d0a4ca8f9b61128c6d6705a146e43d856eba4a7450296977724",
  "stoppedLeaves": [
    {
      "issueId": "B",
      "identifier": "DEMO-B",
      "title": "实现接口",
      "status": "blocked",
      "assigneeAgentId": "agent-owner",
      "assigneeUserId": null,
      "blockerIssueIds": [
        "EXT"
      ],
      "pendingInteractionIds": [
        "INT-1"
      ],
      "pendingApprovalIds": [],
      "updatedAt": "2026-10-04T00:00:00.000Z",
      "latestCommentAt": null,
      "latestDocumentAt": null,
      "latestWorkProductAt": null
    }
  ],
  "stopSnapshot": {
    "version": 2,
    "fingerprint": "task_watchdog_stop:9b3f390c27da3d0a4ca8f9b61128c6d6705a146e43d856eba4a7450296977724",
    "materialLeaves": [
      {
        "issueId": "B",
        "status": "blocked",
        "assigneeAgentId": "agent-owner",
        "assigneeUserId": null,
        "blockerIssueIds": [
          "EXT"
        ],
        "pendingInteractionIds": [
          "INT-1"
        ],
        "pendingApprovalIds": []
      }
    ],
    "waitsByIssueId": {
      "B": {
        "pendingInteractionIds": [
          "INT-1"
        ],
        "pendingApprovalIds": []
      }
    }
  },
  "pendingInteractionsByIssueId": {
    "B": [
      {
        "id": "INT-1",
        "kind": "request_confirmation"
      }
    ]
  }
}
```

![mermaid-diagram (4).png](/assets/posts/2026-10-10-paperclip-current-status/dbe16b6a9bc7590b78a6ab6f611b009221e1689327dd99d19d7e5220f2b64c5f.png)
