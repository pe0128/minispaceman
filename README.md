# minispaceman可交互桌宠

Godot 4.7.2 制作的 Windows/macOS 宇航员桌宠。双击进入以当前屏幕截图为背景的横版世界，窗口顶边成为平台；退出后停在最后位置。

## Windows 启动

已构建的版本：完整解压后双击 `build/windows/minispaceman.exe`。右键桌宠选择「设置…」。

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
| 右键桌宠 | 设置或退出程序 |
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

首次使用需要屏幕录制授权，授权后重启。开发包采用 ad-hoc 签名；公开发行需要 Developer ID 签名和公证。GitHub Actions 提供双平台编译与导出；macOS 登录项、权限、透明窗口和 Retina 仍需实机验收。

## 设置

右键普通桌宠 →「设置…」。左侧切换「宇航员」「应用」；修改先进入草稿，点击「应用」才保存并生效。「取消」丢弃修改；关闭窗口或按 Esc 时，未保存修改会询问处理方式。「重置本页」只重置当前分类的草稿。

- 宇航员：50%、100%、150%、200% 四档整数像素尺寸，普通桌宠和桌宠世界共用；应用时保持脚下坐标。小、中、大喷气使用各自素材和发射参数，不改变推力。
- 应用：登录后自动启动、普通桌宠置顶、记住位置、跟随系统/浅色/深色主题。
- 预览只作用于设置窗口。双击桌宠会隐藏设置、保留草稿并进入世界；返回后可继续编辑。

普通桌宠与世界窗口不占 Windows 任务栏位置。macOS 默认不显示 Dock 图标；设置显示时出现，隐藏或关闭后移除。关闭设置不退出桌宠。

应用界面中文使用宋体（Windows SimSun，macOS 可回退 Songti SC），英文与数字使用 Times New Roman。字体从系统加载，缺失时提示安装；原生标题栏使用系统字体。

配置写入 Godot 用户数据目录的 `settings.cfg`，位置单独保存在 `position.cfg`。Windows 通常位于 `%APPDATA%/Godot/app_userdata/minispaceman可交互桌宠/`；macOS 位于 `~/Library/Application Support/Godot/app_userdata/minispaceman可交互桌宠/`。

自启动仅支持导出的应用。Windows 使用当前用户的 Run 登录项；macOS 13+ 使用 SMAppService，若显示「等待允许」，点击按钮进入系统登录项设置。请将应用放在固定位置后再启用；移动应用后重新关闭并开启此项。开发编辑器不会注册为登录项。应用有当前用户单实例保护。

## 检查与导出

根目录 `compile_commands.json` 供 clangd 读取，包含实际编译参数、MSVC 和 Windows SDK 的头文件路径。它是本机生成文件，不提交到仓库。原生扩展构建完成后，可用以下命令刷新：

```powershell
& .tools/venv/Scripts/python.exe -m SCons -C native platform=windows arch=x86_64 target=template_debug custom_api_file=.build/extension_api.json build_profile=build_profile.json compiledb
```

macOS 使用本机工具链和 `platform=macos arch=universal` 生成，不复用 Windows 数据库。GDScript 补全使用 Godot 语言服务。

```powershell
& 'D:/godot/Godot_v4.7.2-stable_win64_console.exe' --headless --editor --path . --import --quit
python tools/fetch_templates.py --platform windows --output .tools/export_templates/4.7.2.stable
powershell -ExecutionPolicy Bypass -File tools/build_native.ps1 -Target template_release
New-Item -ItemType Directory -Force build/windows
& 'D:/godot/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --export-release 'Windows Desktop'
```

模板工具从官方归档按 HTTP 范围请求只下载当前平台所需文件，Mac 改用 `--platform macos` 和导出预设 `macOS`。也可手动将对应模板放入 `.tools/export_templates/4.7.2.stable/`。

测试专用脚本、合成场景、截图和日志已移除；构建流程只保留资源导入、原生编译和平台导出检查。

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
| `tools/` | 构建、导出依赖、版权声明和启动工具 |
| `docs/asset-notes.md` | 已核对的动作、图层、绑定规则和实现注意事项 |
| `AGENTS.md` | 后续开发需遵循的项目约束 |

架构、实现边界及验证入口见 [实现说明](docs/implementation.md)。`.godot`、`.tools`、编译产物和构建包不进入版本控制。
