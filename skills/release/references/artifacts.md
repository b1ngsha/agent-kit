# Release Deliverables: Release Notes & Feishu Announcement

Always draft both deliverables in Chinese during Step 2. Keep them grounded in the actual diff—never copy raw commit subjects verbatim, and never invent capabilities absent from the diff.

## 1. Release Notes / Changelog（偏技术与升级）

Audience: engineers reviewing the GitHub Release or `CHANGELOG.md`, and downstream consumers upgrading.

Structure (adapt section names to fit the release; omit empty sections):

```markdown
## vX.Y.Z (YYYY-MM-DD)

<1–2 句总览：本次版本的核心定位或主线改动>

### Breaking Changes（仅在存在破坏性变更时置顶）
- **变更点**：受影响范围与明确迁移动作

### Highlights / 新增
- 按模块或用户可见能力分组，说明“带来了什么变化”，而非内部实现细节

### 修复与优化
- 面向使用者描述修复的问题或可感知的性能/体验提升

### 升级 / 安装方式（适用时保留，如 SDK / CLI）
<可直接执行的安装或升级命令，锁定本次 tag>
```

When the repository already maintains a `CHANGELOG.md`, match its heading level and grouping conventions so the new entry blends seamlessly at the top.

## 2. Feishu Release Announcement（飞书群发布公告）

Audience: teammates and downstream product developers in Feishu group chats.

### Tone

自然、克制、带一点轻松感，像研发同学在群里同步好消息：

- 开场一句直接点出版本和可用状态，可略带一点轻松感，避免僵硬的公文腔（如“兹定于”“特此通知”），也避免过度感叹号或刻意玩梗。
- 亮点用短句讲清楚能力与带来的便利，简洁好读。
- 结尾自然给出接入/反馈入口即可。

### Feishu Copy-Paste Formatting Rules

Feishu IM chat inputs render pasted text as plain text rather than Markdown. Format the announcement so the user can copy-paste it directly into a Feishu group with zero broken syntax:

- **Plain text layout**: use `【...】`, emoji section markers (`🚀` / `✨` / `🔧` / `📦` / `👉`), blank lines, and `1.` / `•` lists for visual hierarchy.
- **Zero raw Markdown syntax**: omit `#` headings, `**bold**`, inline `` `backticks` ``, triple-backtick fences, `>` blockquotes, and pipe tables—they display as raw punctuation in Feishu chat.
- **Standalone links and commands**: put URLs and install commands on their own clean lines (indented by 2 spaces if helpful) so Feishu auto-links URLs and recipients can triple-click to copy commands cleanly.
- **Scannable length**: aim for 10–20 lines so it reads comfortably on both desktop and mobile without folding into a wall of text.

### Template Shape

```text
🎉 <产品名> vX.Y.Z 正式发布！<一句俏皮开场白>

✨ 本次亮点
1. <能力/变化一>：<一句说清爽点或价值>
2. <能力/变化二>：<一句说清爽点或价值>
3. <修复/优化>：<一句带过关键修复或体验提升>

⚠️ 升级注意（仅在有破坏性变更或配置动作时保留）
• <需要下游/用户做的一句话动作>

🚀 快速上手 / 升级
  <单行安装或升级命令，锁定 @vX.Y.Z>

📖 完整文档 / Release Notes
https://...

<一句轻松的收尾，欢迎试用或丢反馈>
```
