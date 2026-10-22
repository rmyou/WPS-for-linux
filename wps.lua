-- ~/.config/hypr/wps.lua
--
-- WPS Office for Linux 跑在 XWayland 里，它的「字体 / 字号」下拉框不是
-- xdg_popup，也不是 X11 override-redirect 菜单，而是 WPS 自己创建的
-- 普通顶层窗口：
--   WM_CLASS = "et" 与主窗口相同，WM_NAME 为空，带 WM_TRANSIENT_FOR，
--   尺寸由程序写死（min = max）。
-- Hyprland 只能把它当普通窗口：平铺、加边框/阴影、抢焦点，
-- 于是点下拉看起来就像「新开了一个窗口」。
--
-- 这个文件解决两件事：
--   1) 下拉被当成普通窗口参与平铺 / 加装饰；
--   2) 鼠标一移开下拉，焦点被主窗口抢走，WPS 收到失焦后把下拉关掉。
--
-- 挂载方式：在 ~/.config/hypr/hyprland.lua 中加 require("hypr.wps")
-- 版本：Hyprland 0.56.x（Lua 配置）。0.54 及更早的 hyprlang 写法见 README。

local wps_classes = "^(wpsoffice|wps|et|wpp|wpspdf|pdf)$"

-- 1) 下拉/调色板等辅助窗口：浮动、去掉 Hyprland 的装饰
hl.window_rule({
  name = "wps-dropdown-popup",
  match = {
    class = wps_classes,
    -- 标题为空或等于 class 名 = 字体/字号下拉、调色板等辅助窗口
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
-- 否则鼠标从下拉移回文档时，input:follow_mouse = 1 会把焦点切给主窗口，
-- 下拉窗口失焦，WPS 就把它关掉了。点击仍然正常切换焦点，
-- 所以点文档 / 点别的窗口依旧能关掉下拉。
hl.window_rule({
  name = "wps-main-no-hover-focus",
  match = {
    class = wps_classes,
    -- 主窗口标题形如「文件名 - WPS 表格」，不是空/class 名
    title = "negative:^(wpsoffice|wps|et|wpp|wpspdf|pdf)?$",
  },
  no_follow_mouse = true,
})

-- 可选 A：如果主窗口在平铺时也出现菜单/工具栏异常，放开下面这条，
-- 让 WPS 主窗口浮动 + 最大化（视觉上等同全屏，但不再被平铺裁剪）。
-- hl.window_rule({
--   name = "wps-main-float",
--   match = { class = wps_classes, title = "negative:^(wpsoffice|wps|et|wpp|wpspdf|pdf)?$" },
--   float = true,
--   maximize = true,
-- })

-- 可选 B：如果想让下拉“更黏”——连鼠标移到其它程序上也不关闭，
-- 换成给下拉窗口加 stay_focused。代价：下拉关掉之前几乎点不动其它窗口。
-- hl.window_rule({
--   name = "wps-dropdown-stay-focused",
--   match = { class = wps_classes, title = "^(wpsoffice|wps|et|wpp|wpspdf|pdf)?$" },
--   stay_focused = true,
-- })
