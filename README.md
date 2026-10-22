# WPS for Linux · Omarchy + Hyprland 下拉菜单修复

> 在 **Omarchy（Hyprland）** 下，把 WPS Office 的「字体 / 字号」下拉从“新开一个窗口”修回“贴着按钮的弹出列表”的完整记录：现象、排查、原理、规则、验证与回退。

- **系统**：Omarchy 4.5.0rc1（Arch Linux），内核 `linux-omarchy 7.2.8-9`
- **窗口管理器**：Hyprland 0.56.2，Lua 配置（0.55+ 的新配置格式）
- **WPS**：`wps-office-365 12.1.2.29183-1`，AUR 安装（`yay -S wps-office-365`），XWayland 运行
- **显示**：ThinkPad T480 内置屏 1920×1080，缩放 1.25
- **状态**：规则已在本机启用，WPS 日常使用正常（文字 / 表格 / 演示 / PDF）

---

## 1. 现象

在 WPS 表格里点「字体」输入框右侧的下拉箭头（或字号下拉），期待的是在输入框下面展开一个字体列表，实际却是：

- 屏幕上**多出一个窗口**，看起来和主界面没有关系；
- 这个窗口会参与平铺（把文档窗口挤小）、带 Hyprland 的边框/圆角/阴影；
- 有时会抢走焦点，点别处也不会像正常下拉那样收起；
- 在窗口列表 / Alt-Tab 里也能看到它。

换桌面环境（GNOME / KDE）或换成浮动窗口管理器时没有这个问题，所以容易被误判成“Hyprland 的 bug”或“字体没装好”。

---

## 2. 结论先说

**这不是字体缺失，也不是 Hyprland 的 bug。**

WPS for Linux 是跑在 **XWayland** 里的 X11 程序，它的下拉面板不是 Wayland 的 `xdg_popup`，也不是 X11 的 override-redirect 弹出窗口，而是**由 WPS 自己创建的一个普通顶层窗口**：

```
WM_CLASS(STRING) = "et", "et"          ← 和主窗口同一个 class
WM_NAME(STRING) =                       ← 标题为空
WM_TRANSIENT_FOR(WINDOW): 主窗口
WM_NORMAL_HINTS: 固定尺寸（min = max）
```

对 Hyprland 来说，这就是一个普通窗口，于是按普通窗口处理：平铺、加装饰、聚焦、进窗口列表——看起来自然就是“新开了一个窗口”。

修复思路：用 **Hyprland 窗口规则**把这类辅助窗口识别出来，按“弹出菜单”对待——浮动、不画边框/阴影、不参与平铺。

---

## 3. 环境与安装方式

### 3.1 系统

```text
Omarchy 4.5.0rc1（Arch Linux）
Hyprland 0.56.2（Lua 配置，配置文件在 ~/.config/hypr/*.lua）
Kernel: linux-omarchy 7.2.8-9
```

Hyprland 0.55 起配置语言从 hyprlang 换成 Lua，窗口规则写法也随之变化。本仓库的规则按 **0.56.x 的 Lua API** 编写；0.54 及更早的旧写法见 §6.3。

### 3.2 WPS 的版本与安装方式

```bash
# 安装（AUR）
yay -S wps-office-365

# 版本信息
pacman -Qi wps-office-365
# 版本           : 12.1.2.29183-1
# 打包者         : Unknown Packager   ← AUR 本地打包
# 安装后大小     : 2.11 GiB
# URL            : https://365.wps.cn/
```

- 包名：`wps-office-365`，AUR 包，`yay` 构建后用 `pacman -U` 装入（`Unknown Packager` 即本地构建）。
- 可选字体包：`wps-office-365-fonts`（方正字体），按需安装。
- Omarchy 自带的 `omarchy` 仓库里还有一个 `wps-office-cn`，是同一版本的另一种打包；本机用的是 AUR 的 `wps-office-365`。
- 运行方式：XWayland（`hyprctl clients` 里 `xwayland: true`）。

---

## 4. 排查过程（可复现）

### 4.1 先排除字体问题

字体缺失的典型表现是**方框 / 乱码**，而不是“下拉变成窗口”。只要界面文字正常、只是下拉行为异常，就不是字体问题：

```bash
fc-list :lang=zh | head
fc-match "Microsoft YaHei"
```

### 4.2 抓住“新窗口”本体

复现：打开 WPS 表格，点一次字号/字体下拉，然后**保持它开着**，在终端里执行：

```bash
hyprctl clients -j | jq '.[] | select(.class|test("^(wpsoffice|wps|et|wpp|wpspdf|pdf)$"))
                         | {class,title,xwayland,size,at,floating}'
```

本机抓到的输出（节选）：

```json
{
  "class": "et",
  "title": "et",
  "xwayland": true,
  "size": [48, 471],
  "at": [480, 127],
  "floating": true
}
```

`title` 等于 class 名不是巧合——这个窗口的 `WM_NAME` 是空的，Hyprland 用 class 名做了回退。

### 4.3 用 xprop 确认它是“真窗口”

XWayland 的窗口可以直接用 X11 工具查：

```bash
export DISPLAY=:0
xprop -root _NET_CLIENT_LIST          # 列出 X 窗口 id
xprop -id 0x1e00128 WM_CLASS WM_NAME WM_TRANSIENT_FOR WM_NORMAL_HINTS
```

关键结果：

```text
WM_CLASS(STRING) = "et", "et"
WM_NAME(STRING) =
WM_TRANSIENT_FOR(WINDOW): window id # 0x1e00005

WM_NORMAL_HINTS(WM_SIZE_HINTS):
    user specified location: 600, 159
    user specified size: 60 by 588
    program specified minimum size: 60 by 588
    program specified maximum size: 60 by 588
```

三点信息足以定性：

1. 它是 **NORMAL 类型的顶层窗口**，不是 override-redirect 的弹出菜单；
2. 它带 `WM_TRANSIENT_FOR`，说明 WPS 自己知道这是“主窗口的附属窗口”；
3. 尺寸由 WPS 写死（`min = max`），位置也是 WPS 自己指定的（就在下拉按钮下方）。

也就是说：**WPS 在 Linux 上把下拉面板当成一个独立小窗来做**。在浮动窗口管理器里它看起来像下拉；在平铺窗口管理器里，它就会被当成一个窗口平铺进去。

> 实测同样行为的还有「边框颜色」调色板等其他 WPS 弹出面板，class 同样是 `et`，标题为空。

---

## 5. 原理

### 5.1 Wayland 的 popup 与 X11 的窗口不是一回事

| | Wayland | X11 / XWayland |
|---|---|---|
| 弹出菜单 | `xdg_popup`：有父 surface、锚点、相对位置，由合成器负责定位、剪裁、点击外部关闭 | override-redirect 窗口：WM 不接管，直接显示 |
| WPS 的下拉 | ✗ 没有用 `xdg_popup` | ✗ 也不是 override-redirect，而是普通顶层窗口 + `WM_TRANSIENT_FOR` |

Hyprland 支持 `xdg_popup`，所以原生 Wayland 程序（GTK/Qt）的下拉都正常；但 WPS 交给它的是一个“普通窗口”，它只能按窗口规则去猜。

### 5.2 Hyprland 窗口规则能做什么

窗口规则 = **匹配条件（match）+ 效果（effect）**：

```lua
hl.window_rule({
  match = { class = "^(et)$", title = "^(et)?$" },
  float = true,
  decorate = false,
})
```

- 匹配字段：`class` / `title` / `initial_class` / `initial_title` / `xwayland` / `float` / `modal` / `workspace` / `tag` …
- 常用效果：`float`、`tile`、`maximize`、`no_initial_focus`、`decorate`、`border_size`、`rounding`、`no_shadow`、`no_blur`、`no_anim`、`stay_focused`、`no_focus`、`size`、`move` …
- 静态效果只在窗口创建时求值一次，且匹配的是 **initialClass / initialTitle**；正则用 Google RE2（不支持 lookahead，需要反向匹配时用 `negative:` 前缀）。

### 5.3 为什么规则要这样写

WPS 的下拉窗口和主窗口 **class 相同**（`et` / `wps` / `wpp` / `wpspdf`），只有标题不同：

| 窗口 | class | title |
|---|---|---|
| 主窗口（365 标签式外壳） | `wpsoffice` | `工作簿1 - WPS Office` |
| 主窗口（旧版单组件） | `et` / `wps` | `报表.xlsx - WPS 表格` |
| 字体/字号下拉 | `et` | `et`（WM_NAME 为空，回退成 class） |

所以用「class 属于 WPS 家族 **且** 标题为空或等于家族名」来精确命中辅助窗口，不会误伤主窗口。

> 注意：**不同版本/打包方式的主窗口 class 不一样**——WPS 365 是 `wpsoffice`，老版单组件是 `et`/`wps`。写规则前一定先用 `hyprctl clients` 确认实际值（这一点踩过坑，见 §6.6）。

---

## 6. 修复

### 6.1 规则文件

新建 `~/.config/hypr/wps.lua`：

```lua
-- WPS Office 在 Linux 上跑在 XWayland 里，它的「字体 / 字号」下拉框不是
-- 真正的弹出菜单，而是另开的一个顶层窗口（WM_CLASS 和主窗口一样，
-- 窗口标题为空，所以 Hyprland 里 title 会退化成 class 名）。
-- 平铺布局下这个窗口会被当成普通窗口参与平铺 / 加边框，看起来就像
-- 「点下拉框却新开了一个窗口」。这里把这几个辅助窗口按弹出菜单处理。
local wps_classes = "^(wpsoffice|wps|et|wpp|wpspdf|pdf)$"

-- 1) 下拉/调色板等辅助窗口：浮动、去掉 Hyprland 的装饰
hl.window_rule({
  name = "wps-dropdown-popup",
  match = {
    class = wps_classes,
    -- 标题为空或等于 class 名 = WPS 的字体/字号下拉、调色板等辅助窗口
    title = "^(wpsoffice|wps|et|wpp|wpspdf|pdf)?$",
  },
  float = true,          -- 不参与平铺
  decorate = false,      -- 不要 Hyprland 画的边框/装饰
  border_size = 0,
  rounding = 0,
  no_shadow = true,
  no_blur = true,
  no_anim = true,
})

-- 2) 主窗口：不因「鼠标悬停」抢焦点。
-- 否则鼠标从下拉移回文档时，input:follow_mouse=1 会把焦点切给主窗口，
-- 下拉窗口失焦，WPS 就把它关掉了。点击仍然正常切换焦点，
-- 所以点文档 / 点别的窗口依旧能关掉下拉。
hl.window_rule({
  name = "wps-main-no-hover-focus",
  match = {
    class = wps_classes,
    title = "negative:^(wpsoffice|wps|et|wpp|wpspdf|pdf)?$",
  },
  no_follow_mouse = true,
})
```

### 6.2 挂到主配置

在 `~/.config/hypr/hyprland.lua` 里加一行（放在 `looknfeel` 之后即可）：

```lua
require("hypr.looknfeel")
require("hypr.wps")
require("hypr.autostart")
```

### 6.3 旧版 Hyprland（≤ 0.54，hyprlang 写法）

还在用 `hyprland.conf` 的话，等价写法大致是：

```ini
windowrulev2 = float,class:^(wpsoffice|wps|et|wpp|wpspdf|pdf)$,title:^(wpsoffice|wps|et|wpp|wpspdf|pdf)?$
windowrulev2 = noborder,class:^(wpsoffice|wps|et|wpp|wpspdf|pdf)$,title:^(wpsoffice|wps|et|wpp|wpspdf|pdf)?$
windowrulev2 = noshadow,class:^(wpsoffice|wps|et|wpp|wpspdf|pdf)$,title:^(wpsoffice|wps|et|wpp|wpspdf|pdf)?$
windowrulev2 = noblur,class:^(wpsoffice|wps|et|wpp|wpspdf|pdf)$,title:^(wpsoffice|wps|et|wpp|wpspdf|pdf)?$
windowrulev2 = noanim,class:^(wpsoffice|wps|et|wpp|wpspdf|pdf)$,title:^(wpsoffice|wps|et|wpp|wpspdf|pdf)?$
windowrulev2 = rounding 0,class:^(wpsoffice|wps|et|wpp|wpspdf|pdf)$,title:^(wpsoffice|wps|et|wpp|wpspdf|pdf)?$
```

旧版没有和 `no_follow_mouse` 完全对应的逐窗口写法，想解决“鼠标移开就关闭”只能用全局 `input:follow_mouse = 0`，或给下拉窗口加 `stayfocused`（取舍见 §6.5）。

### 6.4 备选方案：让 WPS 主窗口浮动 + 最大化

如果主窗口在平铺时也有菜单/工具栏异常，可以改成社区里常见的另一种做法：让 WPS 主窗口浮动并最大化（视觉上仍是全屏，但 WPS 不再被平铺裁剪）：

```lua
hl.window_rule({
  name = "wps-main-float",
  match = { class = wps_classes, title = "negative:^(wpsoffice|wps|et|wpp|wpspdf|pdf)?$" },
  float = true,
  maximize = true,
})
```

两条规则可以共存：辅助窗口走 §6.1，主窗口走这条。按需开启，不必默认。

### 6.5 追加修复：鼠标一移开下拉，下拉就被关掉

**现象**：下拉能正常显示了，但只要鼠标从下拉窗口移到文档上（还没点任何东西），下拉立刻消失，根本来不及选字体。

**原因**：这是「焦点跟随鼠标」和 WPS 的实现撞在一起：

1. Hyprland 默认 `input:follow_mouse = 1`——鼠标移到哪个窗口，焦点就切给哪个窗口；
2. WPS 的下拉是独立窗口，打开时它拿到焦点；
3. 鼠标一移到文档上，Hyprland 把焦点切回主窗口；
4. WPS 的下拉收到 `focus-out`，按弹出菜单的常规逻辑把自己关掉。

所以这不是“鼠标离开”触发的，是**焦点被抢走**触发的。

**修复**：让 WPS 主窗口不因「悬停」抢焦点（`no_follow_mouse`），见 §6.1 规则 2。

- 鼠标从下拉移回文档：焦点不动，下拉保持打开；
- 点文档任意位置：点击依然会正常切换焦点 → 下拉关闭；
- 点别的窗口：同样关闭；
- 选中字体：WPS 自己关闭。

**取舍**：WPS 主窗口不再“鼠标移上去就聚焦”，需要点一下才聚焦。对办公软件来说基本无感；如果你依赖悬停聚焦，可以改成给下拉窗口加 `stay_focused = true`（保持焦点在下拉上），代价是下拉关掉之前几乎点不动其它窗口——这也是它不作为默认方案的原因。

```lua
-- 备选：让下拉窗口强制保持焦点（更“黏”，但会挡住其它窗口的点击）
hl.window_rule({
  match = { class = wps_classes, title = "^(wpsoffice|wps|et|wpp|wpspdf|pdf)?$" },
  stay_focused = true,
})
```

另一种更彻底的做法是把全局的 `input:follow_mouse` 改成 `0`（点击才聚焦），但那会影响整个桌面，不只是 WPS。

### 6.6 为什么第一版规则没解决“鼠标移开就关”

第一版规则里 class 写的是 `wps|et|wpp|wpspdf|pdf`，但 **WPS 365 的主窗口 class 是 `wpsoffice`**（标签式外壳），不是 `et`。结果：

- 下拉窗口（class `et`）被正确浮动、去装饰 → 显示正常；
- 主窗口 `wpsoffice` 没匹配到 → `no_follow_mouse` 规则从未生效 → 鼠标移到文档上时焦点照旧被主窗口拿走，下拉失焦关闭。

把 `wpsoffice` 加进正则后，规则才真正覆盖主窗口。判断是否生效：

```bash
# 把鼠标停在 WPS 窗口上（不要点），如果 activewindow 仍是别的程序，说明 no_follow_mouse 生效
hyprctl activewindow -j | jq -r .class
```

教训：**主窗口 class 随版本/打包方式变化**（`wpsoffice` / `et` / `wps` / `wpp`），写规则前先用 `hyprctl clients` 抓一次真身，别照着教程抄。

---

## 7. 验证

```bash
hyprctl reload
hyprctl configerrors          # 应该没有输出
```

再打开 WPS 点一次字体下拉，预期：

- [ ] 下拉列表出现在字体框下方，不再把文档窗口挤走（不参与平铺）；
- [ ] 没有 Hyprland 的边框 / 圆角 / 阴影；
- [ ] `hyprctl clients` 里该窗口 `floating: true`；
- [ ] **鼠标移到文档上，下拉不消失**；
- [ ] 鼠标悬停在 WPS 主窗口上不会抢走焦点（`no_follow_mouse` 生效）；
- [ ] 点文档或其它窗口，下拉关闭；
- [ ] 点选字体后列表正常消失，文档内容不变。

检查辅助窗口状态：

```bash
hyprctl clients -j | jq '.[] | select(.class=="et" or .class=="wps")
                         | {class,title,floating,size,at}'
```

---

## 8. 回退

删除 `~/.config/hypr/wps.lua`，并去掉 `hyprland.lua` 里的 `require("hypr.wps")`，然后：

```bash
hyprctl reload
```

WPS 会回到“下拉是独立窗口”的原始行为，不会影响文档数据。

---

## 9. 已知限制

- 规则只是让这个窗口**看起来/用起来像**下拉，它本质上仍是独立窗口：Alt-Tab / 窗口列表里可能仍能看到它（取决于你的 Hyprland 配置）。
- WPS 升级后如果改了窗口 class 或标题策略，需要同步调整正则；用 `hyprctl clients` 重新抓一次即可。
- 若 WPS 将来改用 Wayland 原生 + `xdg_popup`，这些规则可以删掉。
- 规则不会改变 WPS 内部的字体列表加载逻辑；字体特别多时首次展开仍可能慢半拍（与渲染无关）。
- 为了不让下拉失焦，WPS 主窗口加了 `no_follow_mouse`：它不再随鼠标悬停聚焦，需要点击才聚焦；如果你依赖悬停聚焦，可改用 §6.5 的备选方案。

---

## 10. 后续测试计划

本仓库会持续记录 WPS for Linux 在 Omarchy + Hyprland 下的功能测试。清单与进度见 [`docs/test-plan.md`](docs/test-plan.md)，目前覆盖：

- 启动与新建 / 打开 docx、xlsx、pptx、pdf
- 字体、字号、颜色等下拉与对话框
- 打印、导出 PDF、字体嵌入
- 中文输入法（fcitx5）、剪贴板、拖拽
- 高 DPI（1.25 / 1.5）、多显示器、缩放切换
- 深色模式 / 主题、窗口动画、屏幕共享
- 云文档、宏（JSA）、文件关联

欢迎在 Issues 里补充你的环境与复现步骤。

---

## 11. 参考资料

- Hyprland Wiki · Window Rules：<https://wiki.hypr.land/Configuring/Basics/Window-Rules/>
- Hyprland Wiki · FAQ（下拉/弹出窗口消失、定位问题）：<https://wiki.hypr.land/FAQ/>
- ArchWiki · WPS Office：<https://wiki.archlinux.org/title/WPS_Office>
- AUR · wps-office-365：<https://aur.archlinux.org/packages/wps-office-365>

---

## English TL;DR

WPS Office for Linux runs under XWayland and implements its font/size dropdowns as **real top-level windows** (`WM_CLASS=et`, empty `WM_NAME`, `WM_TRANSIENT_FOR` set, fixed size), not as X11 override-redirect popups nor Wayland `xdg_popup`s. On a tiling compositor such as Hyprland they are managed like normal windows, so opening the font dropdown looks like "a new window appeared".

Fix: a Hyprland 0.56 Lua window rule that matches WPS windows whose title is empty or equal to the class name, and applies `float`, `decorate=false`, `border_size=0`, `rounding=0`, `no_shadow`, `no_blur`, `no_anim`. A second rule sets `no_follow_mouse` on the main WPS window so that `input:follow_mouse=1` no longer steals focus from the open dropdown and makes WPS close it as soon as the pointer moves back to the document. See [`wps.lua`](wps.lua).

Tested on Omarchy 4.5.0rc1 / Hyprland 0.56.2 / wps-office-365 12.1.2.29183 (AUR).

---

## License

文档与配置以 MIT 许可发布，见 [LICENSE](LICENSE)。WPS Office 是金山办公的专有软件，本仓库不包含其任何二进制或字体文件。
