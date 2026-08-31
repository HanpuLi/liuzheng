# 安装与配置

## 依赖

| 依赖 | 用途 | 装法 |
|---|---|---|
| `openssl` | RFC3161 时间戳（盖 + 验） | macOS 自带；Linux 发行版自带 |
| `python3` | `gmail-eml`、`webarchive` 的账本写入 | 系统自带 |
| `ots`（opentimestamps-client） | OpenTimestamps 盖戳与 upgrade | `pip3 install --user opentimestamps-client` |
| Gmail MCP（可选） | 只有 `gmail-eml` 需要，用来复用它的 OAuth token | 见下 |
| SingleFile Chrome 扩展（可选） | 存登录态网页 | Chrome 应用商店 |

## `ots` 路径

`stamp` 和 `ots-upgrade-sweep.sh` 里写死了 macOS 的 pip user 安装路径：

```bash
OTS="$HOME/Library/Python/3.9/bin/ots"
```

装在别处就改这一行（`which ots` 看实际路径）。找不到时脚本会跳过 OTS 那一重，
输出 3/4 而不是 4/4 —— **不会静默成功**。

## `gmail-eml` 的凭证

它不自己走 OAuth，而是**复用 Gmail MCP 服务器已经授权好的 token**：

```
~/.gmail-mcp/gcp-oauth.keys.json          # OAuth 客户端
~/.gmail-mcp/credentials.json             # 主账号 → --account default
~/.gmail-mcp/credentials-<账号名>.json     # 其他账号 → --account <账号名>
```

**多账号是关键用法**，不是可选项：DKIM 只存在于收件方副本里，
所以你要从「**收到你那封信的那个账号**」导出，而不是发信的那个。

没装 Gmail MCP 的话，`gmail-eml` 用不了，但 `stamp` / `webarchive` /
`ots-upgrade-sweep.sh` 都不依赖它。

## 定时跑 OTS upgrade

OTS 盖完是「日历收据」，要等几小时后 `ots upgrade` 才嵌入比特币区块证明。
**不定时跑就等于没锚定**（踩过：279 个证明从建立起从没 upgrade）。

macOS launchd，每天 09:20：

```xml
<!-- ~/Library/LaunchAgents/com.you.ots-sweep.plist -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>com.you.ots-sweep</string>
  <key>ProgramArguments</key>
  <array><string>/bin/bash</string><string>REPLACE_WITH_HOME/bin/ots-upgrade-sweep.sh</string></array>
  <key>StartCalendarInterval</key><dict><key>Hour</key><integer>9</integer><key>Minute</key><integer>20</integer></dict>
</dict></plist>
```

```bash
launchctl load ~/Library/LaunchAgents/com.you.ots-sweep.plist
```

Linux 用 cron：`20 9 * * * ~/bin/ots-upgrade-sweep.sh`

日志在 `~/.ots_sweep.log`，每次一行：扫了多少、已确认多少、超 72h 未确认多少。

### 扫描范围

默认扫 `~/Desktop`、`~/Documents`、`~/.git-repos`。要改就建 `~/.ots_sweep_roots`，
每行一个目录（支持 `~`，`#` 开头是注释）：

```
~/Desktop
~/cases
/Volumes/Archive/证据冷库
```

🔴 **别维护「当前在办案卷」的白名单** —— 踩过：硬编码三个目录，新建的案卷整个漏掉，
那批 .ots 40+ 小时未锚定**而且没有任何报错**。宁可多扫。

⚠️ **网络挂载（SMB/NFS）不要纳入** —— 掉线时 `find` 会卡住，把整个定时任务拖死。
让持有文件的那台机器自己跑一份。

## 可选：通知与仪表盘

`ots-upgrade-sweep.sh` 末尾会调两个**可选**脚本，不存在就静默跳过：

- `~/bin/rnotify "<标题>" "<正文>" <优先级> <类型>` —— 你自己的推送通知
- `~/bin/evidence-status.sh` —— 你自己的仪表盘刷新

想要报警就自己实现 `rnotify`（一个 curl 到 ntfy/Pushover 的壳就够）。

## 验证一次，确认装对了

```bash
echo "hello" > /tmp/t.txt
stamp /tmp/t.txt          # 期望 4/4（没装 ots 则 3/4）
```

### 验 FreeTSA（任何平台都一样）

```bash
openssl ts -verify -data /tmp/t.txt -in /tmp/t.txt.freetsa.tsr \
  -CAfile <(curl -s https://freetsa.org/files/cacert.pem) \
  -untrusted <(curl -s https://freetsa.org/files/tsa.crt)
# 期望最后一行: Verification: OK
# （中间那句 "is not a CA cert" 的 Warning 是正常的，不影响结果）
```

### 验 DigiCert

**Linux**：根在发行版信任库里，直接验：

```bash
openssl ts -verify -data /tmp/t.txt -in /tmp/t.txt.digicert.tsr -CApath /etc/ssl/certs
```

🔴 **macOS 上这条会 FAILED**，报 `unable to get local issuer certificate`。
**不是戳坏了** —— 是 openssl（尤其 Homebrew 装的那个）**不读 macOS 钥匙串**，
而 `/etc/ssl/certs` 在 macOS 上根本不是系统证书目录。
这是最容易把人吓一跳的假失败：戳是好的，验的命令是错的。

✅ macOS 的正确写法 —— 先把系统根证书导成 pem：

```bash
security find-certificate -a -p /System/Library/Keychains/SystemRootCertificates.keychain \
  > /tmp/macroots.pem                       # 实测导出约 158 张
openssl ts -verify -data /tmp/t.txt -in /tmp/t.txt.digicert.tsr -CAfile /tmp/macroots.pem
# 期望最后一行: Verification: OK
```

> ⚠️ 别把这条跟 `security find-generic-password -w` 搞混。
> **读系统根钥匙串不弹窗**；读密码项那个会弹授权窗，在无人值守的脚本里会卡到超时被杀。

### ai.moda 那枚验不了，是预期行为

```bash
openssl ts -verify -data /tmp/t.txt -in /tmp/t.txt.aimoda.tsr -CAfile /tmp/macroots.pem
# 预期 FAILED —— 它链到 Adobe AATL 的根，不在通用 CA 库里
```

盖它是为了多一个 AATL 级商业 CA 的时间源，不是为了好验。
`stamp` 会把它的证书链存成 `.aimoda.chain.pem`（含按 AIA 自动抓的上级证书），
将来要手动建立信任时用得上。

### 🔴 只看 `Status: Granted` 不算验过

那只说明 TSA 受理了请求，**没说明它盖的是哪份数据**。
一定要跑 `-verify` 并看到 `Verification: OK`。

一句话记住哪层是承重的：
**可独立验证的是 DigiCert + FreeTSA 两家**，OTS 要 `upgrade` 之后才算数，ai.moda 是加分不是承重。
