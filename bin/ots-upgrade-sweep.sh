#!/bin/bash
# ots-upgrade-sweep.sh —— 把 .ots 从「日历收据」升级成「自包含的比特币区块证明」
#
# 起因(2026-08-15):抽查 60 个 .ots,59 个仍是 PendingAttestation ——
#   从建立到现在**从没人跑过 ots upgrade**。含义:那些证明只是日历服务器的收据,
#   效力依赖 eternitywall / catallaxy 继续存在且诚实;一旦服务器消失就无法验证。
#   upgrade 之后文件里会嵌入比特币区块头的 Merkle 路径,变成永久自包含。
#   当天一次性补跑 279 个,275 个成功。
#
# 盖戳后需要等日历确认(通常几小时),所以这个脚本每天跑,把新的 pending 收掉。
set -uo pipefail
OTS="${LIUZHENG_OTS_BIN:-$(command -v ots 2>/dev/null || true)}"
[ -n "$OTS" ] || OTS="$HOME/Library/Python/3.9/bin/ots"
RNOTIFY="$HOME/bin/rnotify"   # 可选:你自己的推送通知脚本,不存在则跳过
LOG="$HOME/.ots_sweep.log"
[ -x "$OTS" ] || { echo "$(date '+%F %T') ots 命令不存在: $OTS" >> "$LOG"; exit 0; }

# 🔴 教训:原先这里硬编码「当前在办的几个案卷目录」,结果新建的一个案卷整个漏掉,
# 那批 .ots 40+ 小时未锚定**而且没有任何报错**。
# → **别维护白名单,扫大目录。** 新案卷自动纳入,漏扫是静默失败,代价比多扫大得多。
#
# 可用 ~/.ots_sweep_roots 覆盖(每行一个目录);否则用下面的默认值。
if [ -f "$HOME/.ots_sweep_roots" ]; then
  ROOTS=(); while IFS= read -r line; do
    [ -n "$line" ] && [ "${line#\#}" = "$line" ] && ROOTS+=("${line/#\~/$HOME}")
  done < "$HOME/.ots_sweep_roots"
else
  ROOTS=(
    "$HOME/Desktop"
    "$HOME/Documents"
    "$HOME/.git-repos"              # hash-only anchor 仓库
  )
fi

file_mtime() {
  stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null || date +%s
}

tot=0; conf=0; pend=0; old_pend=0
NOW=$(date +%s)
while IFS= read -r f; do
  [ -n "$f" ] || continue
  tot=$((tot+1))
  "$OTS" info "$f" 2>/dev/null | grep -qi 'BitcoinBlockHeaderAttestation' && { conf=$((conf+1)); continue; }
  "$OTS" upgrade "$f" >/dev/null 2>&1
  if "$OTS" info "$f" 2>/dev/null | grep -qi 'BitcoinBlockHeaderAttestation'; then
    conf=$((conf+1))
  else
    pend=$((pend+1))
    age=$(( (NOW - $(file_mtime "$f")) / 3600 ))
    [ "$age" -gt 72 ] && old_pend=$((old_pend+1))
  fi
done < <(find "${ROOTS[@]}" -name '*.ots' ! -name '*.bak' 2>/dev/null)

echo "$(date '+%F %T') 扫描 $tot:已确认 $conf,待确认 $pend(其中超 72h 未确认 $old_pend)" >> "$LOG"

# 范围外自检:ROOTS 之外还有没有 .ots(防止再出现「新案卷不在清单里」)
# ⚠️ 必须限深度并 prune 大目录:不加限制时 find "$HOME" 超过 2 分钟仍跑不完,
# launchd 任务可能因此被系统杀掉,反而伤到上面的主循环(2026-08-30 实测踩过)。
# 加 -maxdepth 6 + prune 后约 15 秒。
outside=$(find "$HOME" -maxdepth 6 \
  \( -name Library -o -name .Trash -o -name node_modules -o -name .venv -o -name .git \
     -o -name Pictures -o -name Movies -o -name Music -o -name Applications -o -name .cache \) -prune -o \
  -name '*.ots' ! -name '*.bak' \
  ! -path "$HOME/Desktop/*" ! -path "$HOME/Documents/*" ! -path "$HOME/.git-repos/*" \
  -print 2>/dev/null | wc -l | tr -d ' ')
# ⚠️ 网络挂载(SMB/NFS)不要纳入 ROOTS —— 会掉线,一掉线 find 就卡住,
#    整个 launchd 任务被拖死。让持有文件的那台机器自己跑一份。
if [ "${outside:-0}" -gt 0 ]; then
  echo "$(date '+%F %T') ⚠️ 扫描范围之外发现 $outside 个 .ots —— 检查是否需要扩大 ROOTS" >> "$LOG"
fi

# 超过 72 小时还没确认才值得报警 —— 正常几小时内就好
if [ "$old_pend" -gt 0 ] && [ -x "$RNOTIFY" ]; then
  "$RNOTIFY" "⚠️ OTS 有 $old_pend 个证明超 72h 未锚定" \
    "共 $tot 个,已确认 $conf。可能是日历服务器有问题,查 ~/.ots_sweep.log" 4 warning
fi

# 可选:跑完刷新你自己的仪表盘状态
[ -x "$HOME/bin/evidence-status.sh" ] && bash "$HOME/bin/evidence-status.sh" >/dev/null 2>&1
exit 0
