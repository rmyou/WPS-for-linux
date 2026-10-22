# 排错笔记

## 1. 确认规则加载成功

```bash
hyprctl reload
hyprctl configerrors       # 无输出 = 没有配置错误
```

`require("hypr.wps")` 只写一次；文件路径必须是 `~/.config/hypr/wps.lua`。

## 2. 抓 WPS 辅助窗口的 class / title

```bash
hyprctl clients -j | jq '.[] | select(.class|test("wps|et|wpp|pdf"))
                         | {class,title,xwayland,floating,size,at}'
```

没有 `jq` 时：

```bash
hyprctl clients -j | python3 -c '
import json,sys
for c in json.load(sys.stdin):
    if c["class"] in ("wps","et","wpp","wpspdf","pdf"):
        print(c["class"], repr(c["title"]), c["size"], c["floating"])
'
```

要点：

- 辅助窗口的 `title` 通常等于 class 名（`WM_NAME` 为空，Hyprland 回退）；
- 主窗口的 `title` 形如 `文件名 - WPS 表格`；
- `xwayland` 一定是 `true`。

## 3. 常见问题

### 下拉还是被平铺

说明规则没匹配上。先看 `hyprctl clients` 里该窗口的 `class` / `title`，按实际值改正则。WPS 升级后 class 可能变。

### 鼠标一碰下拉就消失

Hyprland FAQ 的经典问题。给该窗口加：

```lua
hl.window_rule({
  match = { class = "^(et)$", title = "^(et)?$" },
  stay_focused = true,
})
```

代价：在这个下拉关掉之前，主界面点不动。

### 下拉位置不对（不在按钮下面）

```lua
hl.window_rule({
  match = { class = "^(et)$", title = "^(et)?$" },
  move = "onscreen cursor",
})
```

这主要针对 XWayland 程序“弹出窗口不在光标处”的情况，按需使用。

### 去掉边框后还能看到圆角/阴影

检查是否同时继承了全局的 `decoration` 规则；把 `border_size = 0`、`rounding = 0`、`no_shadow = true` 放在同一条规则里（本仓库的 `wps.lua` 已包含）。

### 窗口在 Alt-Tab 里还能看到

这是本质限制：WPS 的下拉就是独立窗口。不要用 `no_focus` 去硬藏——会让下拉无法输入搜索。接受它，或用 §6.4 的“主窗口浮动 + 最大化”方案减少干扰。

## 4. 验证 X11 属性（可选）

```bash
export DISPLAY=:0
xprop -root _NET_CLIENT_LIST          # 找到窗口 id
xprop -id <id> WM_CLASS WM_NAME WM_TRANSIENT_FOR WM_NORMAL_HINTS
```

正常情况下会看到：

```text
WM_CLASS(STRING) = "et", "et"
WM_NAME(STRING) =
WM_TRANSIENT_FOR(WINDOW): window id # <主窗口 id>
WM_NORMAL_HINTS: user specified location / size，min = max
```

## 5. 回退

```bash
rm ~/.config/hypr/wps.lua
# 再从 ~/.config/hypr/hyprland.lua 删掉 require("hypr.wps")
hyprctl reload
```
