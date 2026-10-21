---
title: ctfer 的前端学习
date: '2026-10-21'
categories:
- tech
tags:
- 前端
- 界面设计
- 学习笔记
ai_generated: false
render_with_liquid: false
---


学习这些内容主要是希望后续我能够准确的和 AI 表达我的想法，以及在合适的时机使用我需要的 skill。
同时由于我的主要方向不是这块的，所以只粗浅的学一下，另外就是当字典用了。

# 平面设计的美感

这里主要是提供参考方便我参照着进行自己界面的设计吧，在我能够对项目有个大致把握的前提下，尽可能的减少我自己的认知负荷
## 单个页面的参考
https://curated.design/inspiration/animated/
![Pasted image 20261021221904.png](/assets/posts/media/d00b99ab96beaf47727a326ebc9a64dc9dd2012cf7b148641e492de0ea8b021e.webp)

## 整体交互的参考

https://refero.design/
![Pasted image 20261021221936.png](/assets/posts/media/9a2b49da955aceb31f72ca1b7f7a20ce4f144325b8a2e9d2e5b9caf34d0a1c67.webp)







# 界面设计

## 排版
https://ant.design/components/tour-cn

配套有比较详细的文档方便表达清楚自己的想法意图。另外看了博客的质量也不错。
![Pasted image 20261021212919.png](/assets/posts/media/840ed26585e0a862b1cbef1f47043bf3fef675019f5e02db09e36347abc34528.webp)

## 动态效果

https://reactbits.dev/get-started/index
其实也有配套的中文网站，但是我看了一下中文的只有部分内容做了翻译，并且翻译的还是挺生硬的，所以我这里就只留下了一个原版的
![Pasted image 20261021215247.png](/assets/posts/media/c5df047b52fb57f78c815fe2ccdb55afdcf4fb5fb24decb446f3415a1e13932e.webp)

主要是五类
- [Text Animations｜文字动画](https://reactbits.dev/c/text-animations) **：打字、文字渐显、乱码解密、文字粒子化等。你现在打开的就是这一类。
- [Animations｜动画效果](https://reactbits.dev/c/animations) **：鼠标跟随、点击反馈、元素入场、悬停与转场等。
- [Components｜交互组件](https://reactbits.dev/c/components) **：带动效的卡片、导航、画廊、轮播等完整组件。
- [Backgrounds｜动态背景](https://reactbits.dev/c/backgrounds) **：粒子、极光、流体、光束、动态网格等背景效果。
- **[Micro Interactions｜微交互](https://reactbits.dev/c/micro)**：围绕一次小操作设计的局部反馈，例如点赞时爱心跳动、长按按钮逐渐填满、开关切换时弹性变形。重点是“操作时的手感和反馈”


# 可能能用到的 skill 

主要是每一份 skill 在内容上的边界。

对我来说，我并不喜欢对我的工作流程做出太大的限制。我一般可能就是建立并确定整体的一个风格，然后对于每个界面我会给出具体的接口以及能够提供的数据，以及大致的一个想法，而后前端根据这些数据自行设计页面的细节。如果存在不满的地方，我会用合适的语言指出然后调整。

同时关于相关的约束、规范，都应该直接通过 agents.md 进行。

最后我重新对比了几份 skill，并且也重新审视了一下以前游玩使用过的系统，觉得这些还不错

## 比较综合的 skill

https://github.com/anthropics/skills/tree/main/skills/frontend-design
对用户的约束极小，提供了一些通用的约束防止 agent 过分的发散。

https://github.com/nextlevelbuilder/ui-ux-pro-max-skill
提供的约束相对较强，但是对于普通的用户几乎没有影响。这个项目思考的角度相对来说比如深。也有一个官方网站： https://uupm.cc/ ，我觉得里面的示例确实太过简单的风格也很 AI，但是阅读了 skill 的部分具体内容后我觉得它还是很适合用户自定义的，没有说明为了去掉 AI 味一定要怎么怎么样。
![Pasted image 20261021234821.png](/assets/posts/media/c57e8e5874fc938b54fbad19671a93e96d1a42352328fb78a383bb4d649420a9.webp)

## 实现特定风格的 skill

这种就是别人已经把风格基调给订好了的 skill。我之前在写 ppt 的时候用过，这种场景也更适合使用已有的风格，毕竟主要目的也仅仅是完整表达自己的想法。另外如果只是需要草率的做些什么东西，我觉得也很适合直接找这种。

这里只举 1 个例子，苹果味的设计风格：
https://github.com/emilkowalski/skills/blob/main/skills/apple-design/SKILL.md


其实 reactbits 也有一些动画风格上的 skill，但是大部分都需要付费
![Pasted image 20261021234236.png](/assets/posts/media/60e141972f911092d5c35d153014da54fe6b0caea5ecdbb81831aa243828cbd6.webp)
