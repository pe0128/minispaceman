# 图标

彩色图标来自项目内 `assets/spaceman/assembled/sheets/idle.png` 的第一帧。

灰色图标使用 imagegen 技能的内置图像工具，以 `app.png` 为参考生成。源图保存在 `tray_disabled_source.png`；运行 `tools/generate_icons.gd` 会裁去透明边距、标准化灰阶和 alpha，并以最近邻生成常用托盘尺寸，不覆盖源图。主体像素不依赖半透明表示停用。源图不进入导出包。

生成提示词：

> Create a replacement INACTIVE SYSTEM TRAY ICON as a transparent pixel-art PNG based on this exact reference astronaut. Keep the full standing astronaut, facing right, same pose, silhouette, helmet, backpack and small gun, no new objects or text. Strict monochrome grayscale only: very dark gray contour, medium-gray suit with distinct lighter-gray highlight planes, dark gray visor, NO cyan or any colored pixels. Make the suit visibly gray rather than nearly white. OPAQUE solid pixels inside the character, genuinely transparent empty background, no drop shadow, no haze, no reduced opacity. Preserve hard square pixel-art edges. Simplify detail for legibility at 16–32 pixels, compact icon centered with small transparent margin. This is the disabled/idle resident application icon and must be unmistakably gray but clearly visible against both light and dark taskbars. Reference is the original character appearance, not a request to invent a different mascot.
