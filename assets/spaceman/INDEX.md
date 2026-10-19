# 游戏资产目录

更新日期：2026-09-15。以下目录均为可供 Godot 使用的成品图像资源；路径相对本文件。

| 目录 | 内容与作用 |
|---|---|
| [body/](body/) | 头盔、躯干、背包和腿部的身体动画，用作组合角色的基础层。 |
| [parts/](parts/) | 枪、袖子、手套和换弹电池，用于引擎内组合手臂与持枪姿势。 |
| [primary/](primary/) | 固定姿势的主手与枪动画图层。 |
| [aux-back/](aux-back/) | 需要放在身体后面的副手动画图层。 |
| [aux-front/](aux-front/) | 副手伸到身体前方的动画图层。 |
| [auxiliary/](auxiliary/) | 合并后的副手图像，用于单独使用副手动画。 |
| [arms/](arms/) | 主副手与枪合并的动画图像。 |
| [assembled/](assembled/) | 完整角色的固定姿势动画，可直接切帧播放。 |
| [holding/](holding/) | 青、橙、紫三种物品的托举和投掷动画，包含分层、整人及左右版本；清单为本目录内的 `manifest.json`。 |
| [projectiles/](projectiles/) | 三种独立投掷物 PNG 及尺寸、锚点参数。 |
| [effects/](effects/) | 小、中、大喷气动画条及独立气团纹理，供动画播放或粒子效果使用。 |

角色图像目录中的 `frames/` 是单帧，`sheets/` 是横排动画条，`atlas.png` 是整张图集；根据引擎接入方式选择使用。根目录 `rig.json` 提供动画和绑定数据，`palette.png` 是共享色板纹理。
