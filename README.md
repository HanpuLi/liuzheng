# 留证 · liuzheng

[![CI](https://github.com/HanpuLi/liuzheng/actions/workflows/ci.yml/badge.svg)](https://github.com/HanpuLi/liuzheng/actions/workflows/ci.yml)
[![Security](https://github.com/HanpuLi/liuzheng/actions/workflows/security.yml/badge.svg)](https://github.com/HanpuLi/liuzheng/actions/workflows/security.yml)

**代个人跟机构打交道，并把每一次往来固定成经得起查的证据。**

两个 Claude/Codex Agent Skill + 四个命令行工具。给的是**操作纪律**，不是文风模板：
怎么发、发完怎么固定、哪一层是承重的、哪一层只是看起来像承重的。

> A pair of agent skills + CLI tools for **dealing with institutions as an individual**
> and turning that correspondence into evidence that survives scrutiny:
> RFC3161 timestamps, OpenTimestamps, DKIM-bearing `.eml` export, and web archiving —
> with the failure modes documented. Chinese-first; the tools are language-neutral.

现成的 skill 生态里，法务类几乎全是**律所/企业**视角（合同审查、NDA、demand letter 模板），
客服类全是**企业接工单**那一侧。这个 repo 是另一侧：**你一个人，对着一家机构，需要留下痕迹。**

## 谁会用得上

- 自己处理投诉、争议、索赔的人（消费者、租户、自行诉讼当事人）
- 需要证明「某份内容在某时刻确实存在过」的人：记者、研究者、独立开发者
- 任何被平台/机构口头承诺过、然后对方改口的人

## 不是什么

- **不是法律意见。** 涉及程序的部分（证人陈述、exhibit 编号）以英格兰及威尔士 CPR 为例，
  其他法域自行对应。关键判断请自己核实或咨询执业律师。
- 不是自动取证机器人。刻意**不做**全量自动存档——理由写在 `skills/luodang` 里，
  简单说：全量存档本身是风险资产，且在披露程序里对你不利。

## 两个 skill

| skill | 管什么 | 一句话 |
|---|---|---|
| [`duiwai-goutong`](skills/duiwai-goutong/SKILL.md)（对外沟通） | **怎么发** | 载体决定格式 · 一次问清 · 已发出的小瑕疵一律不补救 · 只认书面答复 · 对方含糊就钉住 |
| [`luodang`](skills/luodang/SKILL.md)（落档） | **发完怎么固定** | 八层清单 · git 不是防篡改层 · 十五个踩过的坑 |

两份都是纯 Markdown，任何支持 skill 的 harness 都能用（Claude Code、Codex、Cursor…）。

### 几条能直接拿走的结论

- **git 不是防篡改层。** `git push --force` 能覆盖远程，页面上的提交日期也可以伪造。
  承重的永远是 **RFC3161 TSA + OpenTimestamps + 第三方持有的副本**。
- **盖了 ≠ 可验证。** OTS 盖完只是「日历收据」，不 `upgrade` 就不是比特币证明；
  ai.moda 那家 TSA 链到 Adobe AATL 的根，`openssl ts -verify` **开箱验不了**。
  真正可独立验证的是 **DigiCert 与 FreeTSA** 两家。
- **DKIM 只在收件方副本里。** 发件人的「已发送」原件里 DKIM/Received 全空——
  但只要 Bcc 到**另一个你能用 API 读的账号**，DKIM 就拿得到。
  「Bcc 到一个你读不出原件的邮箱」在证据意义上等于零。
- **平台界面是易失证据。** 争议一解决界面就变，只记文字等于没有。当场存页面。

## 四个工具

| 命令 | 干什么 |
|---|---|
| `gmail-eml` | 走 Gmail API `format=raw` 导出**带 DKIM 的 .eml 原件**，逐封打印 `dkim=`/`spf=`/Received 条数/附件数 |
| `stamp` | 四重盖戳：FreeTSA + DigiCert + ai.moda（RFC3161）+ OpenTimestamps；自动抓存 ai.moda 的证书链 |
| `webarchive` | 网页存档归入案卷 → SHA-256 → 盖戳 → 追加 append-only 账本（`anchors.jsonl`） |
| `ots-upgrade-sweep.sh` | 定时把 OTS 日历收据升级成自包含的比特币证明，超 72h 未锚定报警 |

这些工具现在默认按证据软件的方式 **fail closed**：`gmail-eml` 的账号/message-id/输出文件名不能逃出预期路径，导出的 `.eml` 是 `0600` 且不覆盖已有文件；`webarchive` 用 UTC 时间 + 内容哈希命名并拒绝碰撞；`stamp` 只有在响应能被 OpenSSL 解析为 RFC3161 时间戳时才计入层数。完整信任链验证仍按 [安装与验证文档](docs/install.md) 单独完成。

## 安装

当前稳定版本是 **v0.1.2**。需要可复现安装时固定到 release tag：

```bash
git clone --branch v0.1.2 --depth 1 https://github.com/HanpuLi/liuzheng.git
cd liuzheng

# 只安装四个 CLI 到 ~/bin；不会覆盖不同的已有文件
./scripts/install.sh

# 也安装两份 Claude Code skill
./scripts/install.sh --with-claude-skills
```

installer 会先完整预检再写入：任何目标文件/skill 与当前版本不同都会整次拒绝，避免半安装；确实要替换时显式加 `--force`，旧文件会先留 UTC 时间戳备份。也可用 `--bin-dir` / `--skills-dir` 指定其他目录。

开发/审计最新代码再使用 `main`。依赖、Gmail MCP、OTS 与定时任务配置见 [docs/install.md](docs/install.md)，版本变化见 [CHANGELOG.md](CHANGELOG.md)。

## 出处

这些规则不是设计出来的，是**踩出来的**——每一条后面都跟着一次实际的失败：
少盖一重戳、Bcc 到读不出来的邮箱、用 4KB 窗口判断 DKIM 存在性、
279 个 OTS 证明从没 upgrade 过、案卷里一枚从未验证通过的时间戳。
所有涉及具体案件、当事人、账号的内容都已移除，教训本身原样保留。

MIT License.
