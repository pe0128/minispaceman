# 项目约束

- 项目名称：minispaceman可交互桌宠。
- 项目根目录：`D:/minispaceman/`。项目文件均放在此目录内。
- 必须支持 Windows 和 macOS。涉及窗口、输入或系统集成时，考虑两端差异。
- 原始素材库：`D:/aseprite/spaceman/`。先阅读其中的 `README.md`、`INDEX.md` 及相关 JSON 参数。
- 使用任何源图片前，先复制到本项目 `assets/`，代码只引用项目内副本。依赖的 JSON 清单也应一并复制，并保持或正确调整其路径语义。
- 不要修改原始素材库，不要将 `.backup/` 归档作为运行素材引入。
- 像素素材使用最近邻过滤；遵循素材中的帧尺寸、根点、地面线、循环标记与逐帧时长。
- 首版行为已由用户确认并授权实现；运行方式见 README.md，模块与实现边界见 docs/implementation.md。后续开发保持 Godot 4.7.2 与双平台原生适配。
- 源码与构建产物分开：不要提交 .godot、.tools、build 产物或 native/bin 中的编译库；保留这些目录的忽略标记。
- macOS 权限、Spaces、Retina、透明窗口行为须实机验证，不能将 CI 编译成功描述为已完成实机验收。
- 已核对的素材详情参见 `docs/asset-notes.md`。
- 设置使用独立草稿和「应用」按钮；新增字段先更新 settings_store 的默认值、校验和对应分类页面。主题颜色由 settings_theme 集中维护。
- 用户要求移除测试代码与输出；验证使用临时目录并在结束时清理，不在项目重新建立测试目录或调试入口。保留用户自己的 `.vscode/`。
