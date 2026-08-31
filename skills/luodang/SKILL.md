---
name: luodang
description: 对外发出正式往来之后做证据落档（保全）。八层：Bcc 副本→对方来信逐字存→发送记录→网页存档→SHA-256 清单→RFC3161 多 TSA→OpenTimestamps→git+hash-only anchor。开头有工具速查（gmail-eml 导 DKIM 原件 / stamp 四重盖戳，别手工重造）。含「git 不是防篡改层」的关键更正、易失证据教训、十五个踩过的坑。触发词：落档、存档、保全、打时间戳、盖戳、上链、归档案卷、取证、发完了、发出去了。
---

# 落档（证据保全）

**发出去之后立刻做**，不要攒。攒着就会漏——踩过一次连发五封才想起补锚定。

配套：[duiwai-goutong](../duiwai-goutong/SKILL.md) 管「怎么发」，这份管「发完怎么固定」。

> ⚠️ 适用范围：这份 skill 讲的是**技术层面的证据固定**，不是法律意见。
> 末尾「上得了法庭」那节以**英格兰及威尔士**民事程序为例（CPR），其他法域自行对应。

## When to use

- 刚代用户发出正式邮件／站内信／投诉／申诉
- 收到对方的实质性答复
- 案卷阶段性收口（如投诉升级、法定期限届至前）
- 用户说「落档」「存档」「保全」「打个戳」

**不要用在**：日常闲聊邮件、订阅确认、无争议的订单确认。只对**可能被争议、被引用、被追责**的往来做。

## 工具速查（都是现成的，别手工重造）

| 命令 | 干什么 |
|---|---|
| `gmail-eml --account <acct> --query "<搜索式>" --dest <目录>` | **把邮件导出成带 DKIM 的 .eml 原件**，并逐封打印 dkim=/spf=/附件数 |
| `gmail-eml --account <acct> --id <ID> --check` | 只核验证据力，不落盘 |
| `stamp <文件>` | **四重**盖戳：FreeTSA + DigiCert + ai.moda + OTS，期望输出 **4/4**（见坑 ⑮：ai.moda 那枚验不了，别当可验证层） |
| `stamp --dir <目录>` | 先生成逐文件清单再盖戳 |
| `ots-upgrade-sweep.sh` | 定时（建议每日一次）把 OTS 的日历收据升级为比特币证明 |
| `webarchive <html> <案卷> "说明"` | 网页存档归档 → SHA-256 → 盖戳 → 记入 append-only 账本 |

🔴 **先读这张表再动手。** 踩过：没读表，手工写 `openssl ts -query` + curl 打了
FreeTSA 和 DigiCert，做完才发现 `stamp` 早就在做同样的事**而且还带 OTS**——
手工那次少了一重戳，且 nonce 处理与既有约定不一致，只好重做一遍。

## 🔴 先记住一件事：git 不是防篡改层

这是本 skill 最重要的一条更正。原先的写法是「推到 GitHub 就锚定了」——**错的**，
因为 `git push --force` 能覆盖远程。

| 层 | 抗篡改 | 谁能改 |
|---|---|---|
| 本地 git | **无** | `rebase`/`amend` 随便改；日期用 `GIT_COMMITTER_DATE` 任意指定 |
| 推到 GitHub / 自建 Git 服务 | **弱** | **`--force` 可覆盖**；页面显示的 "committed on X" 是 committer date，同样可伪造 |
| GitHub Events API | 中 | 改不了，但**只留 90 天**，且 force push 后指向的 commit 可能已不存在 |
| **RFC3161 TSA（DigiCert）** | **强** | 无人——TSA 用自己私钥签「此哈希于此刻存在」 |
| **OTS / 比特币** | **强** | 无人 |
| **第三方持有的副本**（Bcc 到别人邮箱、对方系统记录） | **强** | 在别人手里 |

→ **承重的永远是 TSA + OTS + 第三方副本。git 只是分发与冗余。**
→ 对策见「八层」第 8 条与坑 ⑩。

## 八层清单

逐条做，缺哪层就明说缺哪层，**不要假装做全了**。

- [ ] **1. Bcc 副本** —— 发信时就要 Bcc 到「**我能读得到**」的邮箱
- [ ] **2. 对方来信逐字存档** —— 原文照抄进案卷 md，含发件人、时间、Message-ID
- [ ] **3. 发送记录** —— 我方每封的 Message-ID + 时间 + 主题，列成表
- [ ] **4. 🔴 网页存档** —— 平台界面是**易失证据**，当场存，别只记文字（见坑 ⑪）
- [ ] **5. MANIFEST** —— 逐文件 SHA-256
- [ ] **6. RFC3161 多家 TSA** —— FreeTSA + DigiCert + ai.moda（⚠️ 见坑 ⑮：只有前两家能开箱验证）
- [ ] **7. OpenTimestamps** —— 并记得它**要 upgrade** 才算完成
- [ ] **8. git + hash-only anchor** —— `.git` 必须在云同步目录范围外；
      **并把 commit hash 本身打一次 TSA 戳**（防 force push，见坑 ⑩）

## 逐步做法

### 1–3：拉副本、存原文、记发送记录

Bcc/CC 目标的选择是**这份 skill 最容易错的一步**，见坑 ①②。

**🔴 光用 MCP 搜到还不算落档。** `search_emails` / `read_email` 给的是解析后的文本，
**没有邮件头、没有 DKIM 签名**。要拿到能进卷宗的原件，用：

```bash
# 从收件方账号导出——DKIM 只在收件方副本里（坑 ①）
gmail-eml --account second --query "from:you@example.com newer_than:1d" \
          --dest <案卷>/证据/邮件原件 --prefix 我方发出_对方名_2026-08-30_入站副本

# 单封 + 自定名
gmail-eml --account default --id 1a05283e5f732c27 \
          --dest <案卷>/证据/邮件原件 --name 对方来信_2026-08-30.eml
```

它走 Gmail API `messages.get(format=raw)`，拿的是真正的 RFC822 字节，
**完整 Received 链 + DKIM-Signature + Authentication-Results + ARC 全在**，附件也在。
凭证直接复用 Gmail MCP 已授权的 OAuth token（`~/.gmail-mcp/`），不需要另外授权。

> 这取代了「用 Chrome AppleScript 同源 XHR 调 `view=om`、正则抓 `ik` token」那套——
> 那个依赖 Gmail 网页版内部实现，又脆又绕。

每封落盘后脚本会打印 `dkim=` / `spf=` / `Received` 条数 / 附件数，**当场就能看出这份有没有证据力**。

把 Message-ID、发出时间、主题记进 `_证据/发送记录_*.md`。
对方来信逐字抄进 `确认邮件/`（不要只写摘要——日后要引用原话）。

### 5–7：清单 + 多重时间戳

```bash
cd <案卷目录>
M=_证据/MANIFEST_案卷_$(date +%F).txt
{
  echo "MANIFEST — <案卷名>"
  echo "Compiled : $(date -u '+%Y-%m-%dT%H:%M:%SZ') UTC"
  echo "Git commit: $(git rev-parse HEAD)"
  echo "Algorithm : SHA-256"; echo
  git ls-files -z | LC_ALL=C sort -z | while IFS= read -r -d '' f; do
    printf "%s  %s\n" "$(shasum -a 256 "$f" | cut -d' ' -f1)" "$f"
  done
} > "$M"

stamp "$M"        # FreeTSA + DigiCert + ai.moda + OTS，期望输出 4/4
```

`stamp` 也支持 `--dir <目录>`（自动先生成清单再盖戳）。
产出：`.tsq` `.freetsa.tsr` `.digicert.tsr` `.aimoda.tsr` `.aimoda.chain.pem` `.ots`。

**盖完当场验一次**（别只看 `Status: Granted`——那只说明 TSA 受理了，没说明盖的是哪份数据）：

```bash
# FreeTSA（任何平台）
openssl ts -verify -data "$M" -in "$M.freetsa.tsr" \
  -CAfile <(curl -s https://freetsa.org/files/cacert.pem) \
  -untrusted <(curl -s https://freetsa.org/files/tsa.crt)
# 期望最后一行: Verification: OK

# DigiCert —— 🔴 macOS 上必须先导系统根，否则报 unable to get local issuer certificate
# 那是**假失败**（戳是好的，命令错了），别据此以为盖坏了
security find-certificate -a -p /System/Library/Keychains/SystemRootCertificates.keychain > /tmp/macroots.pem
openssl ts -verify -data "$M" -in "$M.digicert.tsr" -CAfile /tmp/macroots.pem
# Linux 上直接 -CApath /etc/ssl/certs 即可
```

看两枚戳的时间：`openssl ts -reply -in "$M.freetsa.tsr" -text | grep '^Time stamp'`

### 4：网页存档（易失证据，优先做）

平台界面**会变**，而且往往在争议解决的那一刻就变。

真实教训：某短租平台上记下「某日期显示 not available」用以证明预订锁住了库存；
房东次日取消后库存放回市场，**该状态当天即不可复现，证据灭失**——当时只写了文字描述，
没有存页面。文字描述在争议里几乎没有分量。

**登录态页面只能从浏览器里存**（`monolith`/`wget`/`curl` 自己发请求，拿不到会话）：
- ✅ 推荐 **SingleFile** Chrome 扩展。一键存单文件 HTML，资源全内联，
  支持登录态，落到 `~/Downloads`。头部自带取证信息：
  `<!-- Page saved with SingleFile / url: … / saved date: … -->`
- 无扩展时的兜底：从已渲染 DOM 导出（丢外链图片，但文本/结构/价格/状态都在）

**存完一条命令归档**（`webarchive` 两种格式都认，自动提取 url 与保存时间）：

```bash
webarchive --latest <案卷目录> "说明"      # 取 ~/Downloads 最新 .html，SingleFile 刚存的就用这个
webarchive <html文件> <案卷目录> "说明"     # 指定文件
# 自动：移入 _证据/webarchive/(UTC 时间戳命名) → SHA-256 → stamp → 追加 anchors.jsonl
```

DOM 导出的兜底写法（在浏览器控制台或 MCP 的 javascript_tool 里跑）：

```js
// 剥 script/style 缩体积，写入带取证头的 HTML 并触发下载
const clone = document.documentElement.cloneNode(true);
clone.querySelectorAll('script, style, noscript, svg').forEach(e=>e.remove());
const header = `<!-- ARCHIVED FOR EVIDENCE
url: ${location.href}
observedAt(UTC): ${new Date().toISOString()}
title: ${document.title}
note: scripts/styles stripped; external images not inlined -->\n`;
const blob = new Blob([header+'<!doctype html>\n'+clone.outerHTML], {type:'text/html'});
const a = document.createElement('a');
a.href = URL.createObjectURL(blob); a.download = '<名字>.html';
document.body.appendChild(a); a.click(); a.remove();
```

**⚠️ 有些页面会拦脚本发起的下载**（实测 Gmail 会）。兜底：让页面把 HTML **POST 到本地接收端**——
起一个带 CORS 的 Python 服务器监听 `127.0.0.1:8899`，页面里
`fetch('http://127.0.0.1:8899/save',{method:'POST',body:html})`，服务器落盘后自退。
（Chrome 把 localhost 视为 secure context，https 页面允许请求它。）

🔴 **但 Gmail 连这条也不通**：其 CSP 的 `connect-src` 只允许 Google 域名，fetch 同样被拦。
→ **Gmail 页面只能靠 SingleFile 扩展存**（扩展权限不受页面 CSP 约束）。
→ 而扩展快捷键是浏览器级（`chrome.commands`），**自动化发的页面级键盘事件按不到**——
  Gmail 页面的存档必须由**人手动**按快捷键。
→ 好在**邮件不易失**（原件永久留在信箱），这层可以等，优先抢会变的平台界面。

⚠️ **不要做全量自动存档**（每访问一页就存）。理由不是技术：
① 会存下银行/医疗/私密页面的登录态内容，**本身成为风险资产**；
② GB/月 的存储；
③ **法庭上反而更弱**——「我存了所有网页」不如「我因为这个原因、在这个时刻做了这份存档」，
   而且全量存档会把对自己不利的东西一并存入，**对方在披露程序中可以要求交出**。

同理，**自动截屏要设案件门槛**。踩过：去掉门槛后一天 442 张、绝大多数无关，
且全部落进法务案卷目录——等于把私人内容堆进将来可能要披露的卷宗，另有跨案污染。

### 8：git（`.git` 必须搬出云同步目录）

```bash
D=<案卷目录>; G=~/.git-repos/<项目名>.git-wt
git -C "$D" init
mv "$D/.git" "$G" && printf 'gitdir: %s\n' "$G" > "$D/.git"   # 工作区只留指针
cd "$D" && git add -A
git commit -m "…"
```

推到自建 Git 服务（Forgejo/Gitea）时：

```bash
# 取凭据：走 git 自己的 helper，别用 security -w（见坑 ④）
HOST=<你的 git 主机>
CRED=$(printf 'protocol=https\nhost=%s\n\n' "$HOST" | git credential fill)
USER=$(printf '%s\n' "$CRED" | sed -n 's/^username=//p')
PASS=$(printf '%s\n' "$CRED" | sed -n 's/^password=//p')

# Forgejo 默认未开 push-to-create，先建库（见坑 ⑤）
curl -s -X POST -u "$USER:$PASS" -H "Content-Type: application/json" \
  -d '{"name":"<repo>","description":"…","private":true,"auto_init":false}' \
  "https://$HOST/api/v1/user/repos"

git remote add forgejo "https://$HOST/<user>/<repo>.git"
git config --local credential.helper osxkeychain
GIT_TERMINAL_PROMPT=0 git push -u forgejo main
```

## 🔴 踩过的坑（十五条）

**① 发件人的「已发送」副本没有 DKIM——但收件方那份拿得到，别放弃。**
Gmail 对已发送邮件的「下载原始邮件」给的是**撰写时那份**，DKIM／Authentication-Results／
Received 全为空。DKIM 只存在于**收件方**副本里。
🔴 **这里更正一个常见的过度悲观结论**：网上（和本 skill 的旧版）常写成「发件人永远拿不到，
别指望 DKIM」。**前半句对，后半句错**——只要 CC/Bcc 到一个自己能读的**另一个**账号，
再用 `gmail-eml --account <那个账号>` 导出，DKIM 就在。实测十二封每封都
`dkim=pass` + `spf=pass` + 4 条 Received。时间戳仍是承重层，但 DKIM 这层不该白白放弃。

**② Bcc 自己的 Gmail 会被去重，等于没发。**
同一账号发信 Bcc 自己 → Gmail 认出自投，收件箱一份都不到。
**且 Bcc 到读不了的邮箱同样等于没有**——判据不是「有没有副本」，
而是「**将来能不能把带 DKIM 的原件导出来**」。Bcc 到一个你只能在手机上看、
没有 API/导出工具的邮箱（如某些 iCloud 配置），在证据意义上是空的。
✅ **原则：Bcc 目标必须是你有工具能读取并归档的邮箱，且与发件账号是不同账号。**
实测 Gmail→**不同** Gmail 账号不去重（发送 ID 与收件 ID 不同＝真投递）。

**③ 承重层是时间戳，不是 DKIM。**
哈希「发出去的确切字节」再打 RFC3161+OTS，证明「此内容于此刻已存在」，不依赖任何邮件服务商。
DKIM 是加分项，拿不到不影响主链条——**但要在案卷里写明哪层缺、为什么缺**。

**④ `security find-*-password -w` 会弹钥匙串授权窗，把命令卡到超时。**
实测卡满 2 分钟被杀（在无人值守的自动化里就是静默失败）。
✅ 改用 `git credential fill`（走 git 自己已授权的 helper，不弹窗）。

**⑤ Forgejo 默认未开 push-to-create。**
直接 push 报 `403 Push to create is not enabled for users`。先用 API 建库。

**⑥ OTS 盖完只是「日历收据」，必须 upgrade。**
`ots-upgrade-sweep.sh` 定时自动收；**次日要确认已升级**为自包含的比特币证明。
历史教训：曾抽查 60 个 .ots，59 个仍是 PendingAttestation ——
从建立起**从没人跑过 `ots upgrade`**。含义：那些证明只是日历服务器的收据，
效力依赖该服务器继续存在且诚实。一次性补跑 279 个，275 个成功。

**⑦ 云同步目录（iCloud 等）会真损坏 git 对象**，不只是 dataless 占位符，会永久丢 blob。
`.git` 必须放在同步范围外（如 `~/.git-repos/`），工作区只留 `gitdir:` 指针。

**⑧ 案卷里的工作副本 ≠ 送达件。**
若曾重新生成过 PDF（多数 PDF 库每次构建都写入新的时间戳与文档 ID），字节就变了。
✅ **从「已发送」邮件里把附件抽出来存档**，别拿工作副本冒充送达件。

**⑨ 平台工单的线程标记不能丢。**
Salesforce Email-to-Case 靠正文里的 `ref:!<OrgID>.!<CaseID>:ref` 归档，**不靠** In-Reply-To。
主题／正文里保留它，回信才进同一工单；删掉会开新工单。
⚠️ Gmail 的自动翻译会把 `ref` 译成本地语言——**从译文复制会让标记失效**。

**⑩ `git push --force` 能覆盖远程，所以推送 ≠ 防篡改。**
对策三条：①**给 commit hash 本身打 TSA 戳**（把 hash 写进一个小文件再 `stamp` 它）——
即便日后被覆盖，戳过的 hash 仍证明该版本曾存在；②**开分支保护/Ruleset 禁 force push**；
③**多远程**（自建 + GitHub anchor + 本地 + 冷库），篡改成本随副本数上升。

**⑪ 平台界面是易失证据，当场存。**
争议一解决，界面就变。只记文字＝没有证据。见「八层」第 4 条。

**⑫ hash-only anchor：内容与证明分离。**
**建一个独立仓库，只放 SHA-256 与 TSA/OTS 收据，不放任何文档、通信、个人数据**，
README 里写明这一点。好处：可以推到公开／半公开处形成分布式副本，而不泄露案情。
⚠️ 它的价值**不在** git 托管方的时间戳（那个可伪造），而在收据本身与副本冗余。

**⑬ 判断 .eml 有没有 DKIM，必须解析完整头部，不能只读前几 KB。**
踩过：导出后用 `raw[:4000]` 找 `DKIM-Signature`，全部报「没有」，
差点据此写进案卷说「Gmail→Gmail 内部投递不产生 DKIM」。
**实际是 Gmail 把 `ARC-Seal` / `ARC-Message-Signature` / `ARC-Authentication-Results`
排在 `DKIM-Signature` 之前**，4KB 窗口只够装下 ARC 那几条。
✅ 用 `email.message_from_bytes()` 解析后查 `'DKIM-Signature' in m`，
或直接用 `gmail-eml --check`（它已经这么做了）。
**通用教训：对结构化数据做「存在性判断」时，别用固定长度的字节窗口。**

**⑭ 含身份证件／敏感附件的 .eml：文件 gitignore，哈希进 manifest。**
证件信的 .eml 会把加密附件整个带进来（实测每封约 684 KB），推到任何托管都不合适。
✅ 做法：`.gitignore` 排除那几个文件，**但 manifest 照常收录它们的 sha256 并盖戳**——
时间戳保全的是哈希，不需要文件本身在 git 里；文件用你自己的同步方案（如 Syncthing）
传到自有机器。这样保全与保密都成立，且日后能证明「那份证件在该时点是这个字节」。

**⑮ 第三家 TSA：ai.moda —— 值得盖，但它验不了，别把它当「可验证」的那一层。**

`stamp` 会打 `http://rfc3161.ai.moda`（所以是 **4/4**：freetsa + digicert + ai.moda + OTS）。

🔴 **但它有个重要限制**：

| TSA | 开箱 `openssl ts -verify` | 说明 |
|---|---|---|
| **DigiCert** | ✅ OK | Linux 直接验；🔴 **macOS 上 openssl 不读钥匙串，`-CApath /etc/ssl/certs` 会假失败**，要先 `security find-certificate -a -p /System/Library/Keychains/SystemRootCertificates.keychain > roots.pem` 再 `-CAfile roots.pem` |
| **FreeTSA** | ✅ OK（带它自己的 `cacert.pem` + `tsa.crt`） | 社区 TSA |
| **ai.moda** | ❌ **FAILED** | 链到 **AATL（Adobe 信任列表）** 的根，**不在 Mozilla/OS 的通用 CA 库里** |

ai.moda 是**负载均衡器，会轮换后端 CA** —— 实测同一周内分别轮到 **Sectigo**
（OID 1.3.6.1.4.1.6449.2.1.1）和 **GlobalSign AATL R45**（OID 1.3.6.1.4.1.4146.1.31）。
GlobalSign 那条链是三层：签名证书 → `GlobalSign R45 AATL TimeStamping Root CA 2021`（中间）
→ `GlobalSign Timestamping Root R45`（根）。**最后那个根在 openssl 的信任库里一张都匹配不上。**
Adobe Acrobat 能验（AATL 就是给 PDF 签名用的），命令行要验就得手动信任那个根。

⚠️ **由此查出的一个真实错误**：某份卷宗里那枚 ai.moda 戳**从来没被验证通过过**
（报 `ess cert id not found`），而案卷里一直当它是三重可验证时间戳之一。
**盖了 ≠ 可验证** —— 这和坑 ⑥「OTS 盖完只是日历收据」是同一类错觉。

✅ **所以**：
- **可独立验证的承重层是 DigiCert 与 FreeTSA。** 引用时说「双 TSA 可验」是准确的，
  说「三重 RFC3161 可验」不准确。
- ai.moda 的价值是**多一个独立商业 CA 的时间源**（AATL 级，比社区 TSA 权威），不是更好验。
- `stamp` 会把 ai.moda 那枚的**证书链一并存成 `.aimoda.chain.pem`**
  （含按证书 AIA 字段自动抓的上级证书，来源记在 `.sources`）——
  **因为那些中间证书将来可能换地址，现在不存就再也拿不到。**

## 附：无 Gmail MCP 时经 Chrome 网页版代发

MCP 掉线时的替代路径，本身也有坑：

- 🔴 **焦点不在正文框时，`type` 的每个字母会被 Gmail 当成单键快捷键执行**
  （`e`=归档、`f`=转发、`#`=删除…），表现为页面乱跳、正文始终为空，**有误操作风险**。
- **Gmail 启用 Trusted Types**，`innerHTML` 赋值被策略拦截。
  ✅ 用 `createElement`/`createTextNode` 逐节点构建，再派发 `input` 事件：

```js
box.focus();
while (box.firstChild) box.removeChild(box.firstChild);
for (const l of lines) {
  const d = document.createElement('div');
  l === '' ? d.appendChild(document.createElement('br'))
           : d.appendChild(document.createTextNode(l));
  box.appendChild(d);
}
box.dispatchEvent(new InputEvent('input',{bubbles:true,inputType:'insertText'}));
```

- **发送前按字段核对收件人**（比截图可靠）：

```js
['to','cc','bcc'].map(f => [f,
  [...document.querySelector(`div[name="${f}"]`)
     .querySelectorAll('[data-hovercard-id]')].map(e=>e.getAttribute('data-hovercard-id'))]);
```

- 内联回复的收件人区默认折叠，**要先点开才能加 Bcc**；`div[name="bcc"]` 里没有 `input`
  就说明还没展开。
- 改主题用原生 setter 再派发事件：
  `Object.getOwnPropertyDescriptor(HTMLInputElement.prototype,'value').set.call(subj, '…')`

## 若要上得了法庭／听证：还缺三样

（以下以**英格兰及威尔士**民事程序为例，其他法域自行对应。这不是法律意见。）

前八层证明的是「**这段内容在某时刻已经存在**」。它**不证明**内容是真的、
邮件确实送达、或平台界面当时确实那样显示。程序上真正需要的是：

**① 证人陈述（witness statement）+ statement of truth**（CPR PD 32）
法庭不读几十份工作笔记。要一份**以当事人名义、第一人称**的陈述，按时间顺序叙事，
每处引用挂证据编号。**这通常是最大的缺口，但不急**——等真要用时再做。

**② exhibit 编号体系**
描述性文件名不可引用。程序上用 `姓名缩写+序号`（如 `HL1`、`HL2`）。
做陈述时一并建立映射表。

**③ 原始 `.eml`（带完整邮件头）**
正文抄录**不够**——没有 `Received` 链、`DKIM-Signature`、`Authentication-Results`，
而那三样才是技术真实性的核心。
✅ 好消息：**收件方副本头是完整的**——我方去信去 Bcc 邮箱导，对方来信在自己邮箱导。
**这层现在就能补，且不会随时间灭失**（邮件不像网页会变），可以等。

**优先级判断**：③ 不易失可以等；②① 用时再做；
**只有第 4 层（网页存档）是真正会消失的，必须当场做。**

## 做完之后

- 在案卷待办里勾掉，并写明**这次做到了哪几层、缺哪层**
- 向用户汇报时**如实说明缺失层**（例：「两封拿不到可读 Bcc 副本，正文已逐字存档，
  但少了独立副本那层」），不要含糊带过
