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
-- 这条规则把这类辅助窗口按弹出菜单处理：浮动、去掉 Hyprland 的装饰。
-- 主窗口标题形如「文件名 - WPS 表格」，不会被匹配到。
--
-- 挂载方式：在 ~/.config/hypr/hyprland.lua 中加 require("hypr.wps")
-- 版本：Hyprland 0.56.x（Lua 配置）。0.54 及更早的 hyprlang 写法见 README。

local wps_classes = "^(wps|et|wpp|wpspdf|pdf)$"

hl.window_rule({
  name = "wps-dropdown-popup",
  match = {
    class = wps_classes,
    -- 标题为空或等于 class 名 = 字体/字号下拉、调色板等辅助窗口
    title = "^(wps|et|wpp|wpspdf|pdf)?$",
  },
  float = true,          -- 不参与平铺
  decorate = false,      -- 不要 Hyprland 画的边框/装饰
  border_size = 0,
  rounding = 0,
  no_shadow = true,
  no_blur = true,
  no_anim = true,
})

-- 可选：如果主窗口在平铺时也出现菜单/工具栏异常，放开下面这条，
-- 让 WPS 主窗口浮动 + 最大化（视觉上等同全屏，但不再被平铺裁剪）。
-- hl.window_rule({
--   name = "wps-main-float",
--   match = { class = wps_classes, title = "negative:^(wps|et|wpp|wpspdf|pdf)?$" },
--   float = true,
--   maximize = true,
-- })
