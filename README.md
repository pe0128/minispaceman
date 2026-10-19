# minispaceman可交互桌宠

Godot 4.7.2 制作的 Windows/macOS 宇航员桌宠。双击进入以当前屏幕截图为背景的横版世界，窗口顶边成为平台；退出后停在最后位置。

## Windows 启动

需要 Python 3.11+、Visual Studio C++ x64 工具链、Windows SDK，以及本机 `D:/godot/` 中的 Godot 4.7.2。构建工具安装在项目 `.tools/venv` 内。

```powershell
git submodule update --init --depth 1
powershell -ExecutionPolicy Bypass -File tools/build_native.ps1
powershell -ExecutionPolicy Bypass -File tools/run.ps1
```

也可编译扩展后，在 Godot 中导入本目录 `project.godot`，关闭“嵌入游戏”，以独立窗口运行。

## 操作

| 输入 | 行为 |
| --- | --- |
| 拖动 / 双击桌宠 | 移动 / 进入世界 |
| 右键桌宠 | 进入世界或退出程序 |
| A/D、左右方向键 | 左右移动 |
| S、下方向键 | 蹲伏和蹲行 |
| 空格 | 起跳；空中再次按下或持续按住 250 ms 启动喷气 |
| 按住/松开空格 | 持续喷气/停止推力，之后受重力下落 |
| S＋空格 | 穿过窗口平台，不穿过屏幕底部 |
| 鼠标 / 左键 | 360° 瞄准 / 单击射击 |
| Q / E | 拾取附近物品 / 朝瞄准方向投掷 |
| Esc | 返回普通桌宠，保留最后位置 |

每次进入生成青、橙、紫各一个道具，手中最多一个。W/上方向键暂未绑定交互。无敌人、生命值、弹药或燃料限制。

世界只覆盖当前显示器，后台程序和声音继续运行。截图只在内存中使用，不保存、不上传。游戏不会点击真实应用；失焦暂停，重新聚焦继续，每次进入重新生成关卡。

## macOS

目标为 macOS 13+，Intel 和 Apple Silicon。需要 Xcode Command Line Tools、Python 3 和相同版本的 Godot。

```bash
export GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot"
bash tools/build_native.sh
"$GODOT_BIN" --editor --path .
```

首次使用需要屏幕录制授权，授权后重启。开发包采用 ad-hoc 签名；公开发行需要 Developer ID 签名和公证。GitHub Actions 提供双平台构建与测试；macOS 权限、透明窗口和 Retina 仍需实机验收。

## 检查与导出

```powershell
powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Visual
python tools/fetch_templates.py --platform windows --output .tools/export_templates/4.7.2.stable
powershell -ExecutionPolicy Bypass -File tools/build_native.ps1 -Target template_release
New-Item -ItemType Directory -Force build/windows
& 'D:/godot/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --export-release 'Windows Desktop'
```

模板工具从官方归档按 HTTP 范围请求只下载当前平台所需文件，Mac 改用 `--platform macos` 和导出预设 `macOS`。也可手动将对应模板放入 `.tools/export_templates/4.7.2.stable/`。

`-Visual` 会短暂打开图形测试窗口，检查真实截图与 50 次切换；冒烟截图使用合成背景，写入忽略的 `artifacts/smoke.png`，不保存真实桌面。

## 项目边界

- 本目录是项目根目录，项目所需代码、配置、文档及运行素材均应在本目录内。
- `assets/` 存放项目实际使用的素材。使用源素材前，必须先复制到这里，再通过项目内路径引用。
- 外部素材来源为 `D:/aseprite/spaceman/`，其 `README.md`、`INDEX.md`、`rig.json` 与各目录的清单描述素材结构和动画参数。
- 外部素材目录不是项目运行依赖，不可直接引用其中的图片，也不可依赖指向它的符号链接。

## 目录

| 路径 | 用途 |
| --- | --- |
| `assets/` | 已复制到项目内的运行素材和动画参数 |
| `scripts/`、`scenes/`、`shaders/` | 窗口状态、桌面服务、角色、世界和效果 |
| `native/` | Win32/DWM、CoreGraphics 原生适配与固定提交的 godot-cpp |
| `tests/`、`tools/` | 自动化检查、构建和启动工具 |
| `docs/asset-notes.md` | 已核对的动作、图层、绑定规则和实现注意事项 |
| `AGENTS.md` | 后续开发需遵循的项目约束 |

架构、实现边界及验证入口见 [实现说明](docs/implementation.md)。`.godot`、`.tools`、编译产物和构建包不进入版本控制。
