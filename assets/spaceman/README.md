# 宇航员 · Godot 游戏资产

更新日期：2026-09-15。此目录仅包含成品 PNG、动画与绑定 JSON，以及资产说明。目录索引见 [INDEX.md](INDEX.md)。

## 导入与使用

把整个 `spaceman_refined` 目录放入 Godot 项目的资产目录。PNG 包括单帧、横排动画条、左右朝向版本和图集，可按需要选择使用；这些是同一素材的不同交付形式，不需要同时加载。

角色动画共 15 类、92 帧，单帧 96×96，根点为 (48,60)，站立地面为 y=76。动画速度、循环、特殊帧时长、肩点及零件锚点见 `rig.json`。像素画应使用最近邻过滤。

`rig.json`、`effects/manifest.json`、`projectiles/manifest.json` 内的图片路径相对本目录；`holding/manifest.json` 内的图片路径相对 `holding/`。JSON 是参数数据，需要通过 Godot 的 JSON 接口读取，再由游戏代码使用；它不会自动创建动画或绑定骨骼。发布游戏时，需确保这些 JSON 数据也被包含在导出包中。

## 角色组合规则

连续 360° 瞄准使用身体动画与 `parts/` 零件组合。主手上抬由肩带动大臂；下放至大臂与躯干平行后，大臂保持不动，继续下瞄由肘带动小臂与枪。手与枪连接，枪口不作为转轴。

副手使用另一侧独立肩点，不能与主手共用；基础副肩加 `(0,-2)` 位移得到实际副肩。副手臂长为 6+7 像素、袖宽为 7/6 像素。托举时，手掌在身体局部坐标中相对副肩向前 8、向下 5 像素，屈肘向前上方托住物品。物品以 `palmAnchor` 贴在掌心，独立偏移为零。

组合层序为：后方副手 → 身体 → 前伸副手 → 主手与枪。头盔与领口遮挡数据见逐帧 `helmetSpans`；手套应按 `gloveSamples` 采样，排除两个突兀亮点。固定姿势的成品分层与整人动画已经包含对应绘制结果。

投掷为 6 帧、9 FPS，第 4 帧开始释放（索引 3）。首帧副手对应托举态，末帧对应空手静息态。状态切换可采用 120 ms 的副手关节角过渡。角色位移、重力、后坐力及投掷物飞行由引擎计算。

小喷气可直接播放动画条；逐团生成的中、大喷气使用 `effects/gas-puff/` 纹理及 `rig.json` 中的发射参数。

## 交付范围

这是资产包，不是可运行的 Godot 项目。原目录没有 Godot 原生脚本，本次未新增或移植脚本。360° 瞄准、关节过渡、拾取、投掷、遮挡和气团生成等逻辑需要在 Godot 中实现。固定整人动画可直接按帧播放，但不会产生任意角度瞄准。

Web、JS、Python、Lua 工具，原始生成图、中间素材及当前 Aseprite 工程已从本资产目录删除。历史版本统一存放于工作区根目录 `.backup/`，其中的 `.gdignore` 用于阻止 Godot 导入归档内容。

Godot 官方参考：[PNG 导入](https://docs.godotengine.org/en/4.4/tutorials/assets_pipeline/importing_images.html)、[JSON 数据读取](https://docs.godotengine.org/en/stable/classes/class_json.html)、[项目与忽略目录](https://docs.godotengine.org/en/stable/tutorials/best_practices/project_organization.html)。
