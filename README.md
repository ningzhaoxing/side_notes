# SideNotes

SideNotes 是一个给个人使用的 macOS 悬浮计划卡片。它适合长期放在屏幕边缘，用来随手查看和维护当天计划，也可以翻到背面记录长期主义要推进的事情，比如读书、英语、社交、工作成长等。

仓库地址：

```text
git@github.com:ningzhaoxing/side_notes.git
```

## 用途

SideNotes 的核心目标是让计划一直“在场”，但不强打扰：

- 正面是当天计划：可以按领域、项目、早中晚等方式创建分组，并在分组里添加任务。
- 背面是长期计划：可以按读书、英语、社交、健康、工作等领域记录长期事项。
- 任务可以直接在悬浮卡片里编辑、勾选、删除，不必每次打开完整编辑窗口。
- 卡片可以固定在屏幕上，也可以收起到屏幕边缘，只留下一个小书签入口。
- 支持从侧边书签唤起、翻面、归档当天计划、查看历史归档。
- 支持调整卡片透明度、圆角、侧边位置，并可以像普通窗口一样拖动边缘缩放。
- 所有数据只保存在本机 SQLite 数据库里，不做云同步。

## 安装

### 1. 准备环境

需要一台 macOS，并已安装 Swift 工具链。通常安装 Xcode 或 Xcode Command Line Tools 即可。

可以先检查：

```bash
swift --version
```

### 2. 获取代码

```bash
git clone git@github.com:ningzhaoxing/side_notes.git
cd side_notes
```

如果你已经有本地仓库，进入目录后更新即可：

```bash
git pull
```

### 3. 构建并安装到用户应用目录

推荐直接运行安装脚本：

```bash
Scripts/install_app.sh
```

脚本会完成这些事情：

- 构建 `SideNotes.app`
- 结束正在运行的旧 SideNotes 实例
- 复制新版本到 `~/Applications/SideNotes.app`
- 清理隔离属性并做本地签名

安装完成后可以启动：

```bash
open "$HOME/Applications/SideNotes.app"
```

也可以在 Finder 里打开：

```text
~/Applications/SideNotes.app
```

### 4. 只构建不安装

如果只想生成 App 包，不复制到应用目录：

```bash
Scripts/build_app.sh
```

构建产物在：

```text
Build/SideNotes.app
```

可以直接运行：

```bash
open Build/SideNotes.app
```

## 使用方式

- 启动后，卡片默认显示在屏幕边缘附近。
- 点击 `固定` / `取消固定` 可以切换常驻或收起到侧边书签。
- 点击 `翻面` 可以在“今天”和“长期”之间切换。
- 在卡片里直接添加分组、添加任务、改标题、勾选任务或删除条目。
- 拖动窗口边缘可以调整卡片大小。
- 点击 `设置` 可以修改透明度、圆角和侧边位置。
- 点击 `归档` 会把当前当天计划保存到历史，并进入一个新的空白当天计划。
- 点击 `编辑` 或菜单栏里的 SideNotes 入口，可以打开更完整的编辑窗口。
- 点击 `退出` 或侧边书签右键菜单，可以退出应用。

SideNotes 会保持单实例运行；重复打开 App 时，会唤起已有卡片，而不是创建多个悬浮窗口。

## 数据位置

本地数据库保存在：

```text
~/Library/Application Support/SideNotes/SideNotes.sqlite
```

当前版本不包含云同步。删除这个数据库会清空本地计划数据，操作前请先备份。

## 开发与验证

运行核心测试：

```bash
env CLANG_MODULE_CACHE_PATH=/private/tmp/sidenotes-module-cache swift run --disable-sandbox SideNotesCoreTests
```

构建 App：

```bash
env CLANG_MODULE_CACHE_PATH=/private/tmp/sidenotes-module-cache swift build --disable-sandbox --product SideNotes
```
