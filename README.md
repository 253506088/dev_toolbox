# 开发者工具箱 (Dev Toolbox)

一款基于 Flutter 开发的 Windows 桌面端开发者工具集合，集成了日常开发中常用的格式化、编解码、转换等功能。

## 📋 功能列表

| 功能 | 说明 |
|------|------|
| SQL 格式化 | 标准 SQL 语句的格式化与压缩 |
| SQL IN 格式化 | 将多行文本转为 SQL IN 语句格式，支持反向转换 |
| JSON 格式化 | 格式化、压缩、转义/去转义、Unicode 编解码 |
| 时间转换 | 日期时间与秒级/毫秒级时间戳互转 |
| Base64 | 文本的 Base64 编码与解码 |
| MD5 | 计算文本的 MD5 哈希值 |
| URL 编解码 | URL 参数的编码与解码 |
| 二维码 | 生成二维码图片，支持识别/解析二维码图片 |
| Cron 表达式 | 可视化 Cron 表达式生成器 |
| XML/JSON 转换 | XML 与 JSON 格式互转 |
| 文本对比 | 对比两段文本的差异，支持行内细节高亮 |
| 便签 | 桌面便签，支持富文本、图片、搜索及定时提醒 |

## 🛠️ 环境要求

- **Flutter SDK**: 3.10.0 或更高版本
- **Dart SDK**: 3.0.0 或更高版本
- **操作系统**: Windows 10/11
- **开发工具**: VS Code / Android Studio / IntelliJ IDEA
- **Windows 开发者模式**: 需开启（用于插件符号链接支持）

### 开启 Windows 开发者模式

```powershell
start ms-settings:developers
```

在打开的设置页面中启用"开发者模式"。

## 🚀 快速开始

### 1. 克隆项目

```bash
git clone <your-repo-url>
cd dev_toolbox
```

### 2. 安装依赖

```bash
flutter pub get
```

### 3. 运行项目

```bash
flutter run -d windows
```

## 📦 打包发布

### 构建 Release 版本

```bash
flutter build windows --release
```

构建产物位于：`build/windows/x64/runner/Release/`

### 打包为安装程序（可选）

可使用 [Inno Setup](https://jrsoftware.org/isinfo.php) 或 [MSIX](https://pub.dev/packages/msix) 打包为安装程序：

```bash
# 使用 msix 打包
flutter pub add msix --dev
flutter pub run msix:create
```

## 📁 项目结构

```
lib/
├── main.dart                    # 应用入口，主布局（NavigationRail）
├── tools/                       # 各功能模块
│   ├── sql_format_tool.dart     # SQL 格式化 (美化/压缩)
│   ├── sql_in_formatter_tool.dart # SQL IN 格式化
│   ├── json_formatter_tool.dart # JSON 工具
│   ├── time_converter_tool.dart # 时间转换
│   ├── base64_tool.dart         # Base64 编解码
│   ├── md5_tool.dart            # MD5 计算
│   ├── url_tool.dart            # URL 编解码
│   ├── qr_tool.dart             # 二维码生成/解析
│   ├── cron_tool.dart           # Cron 表达式
│   ├── xml_json_tool.dart       # XML/JSON 转换
│   ├── diff_tool.dart           # 文本对比
│   └── sticky_note_tool.dart    # 便签工具
├── widgets/                     # 可复用组件（如便签卡片、提醒弹窗等）
├── services/                    # 业务服务（便签存储、提醒服务、节假日API等）
├── models/                      # 数据模型
└── utils/                       # 工具类
```

## 📖 使用说明

### SQL 格式化
- **格式化**：将挤压的 SQL 语句美化为易读的多行格式
- **压缩**：将多行 SQL 压缩为单行，去除多余空白

### SQL IN 格式化
- **输入**：每行一个值（如 `11\n22`）
- **格式化**：转为 `'11','22'` 格式
- **去格式化**：将 SQL IN 格式还原为多行

### JSON 工具
- **格式化**：美化 JSON 结构
- **压缩**：移除空格换行
- **转义/去转义**：处理特殊字符
- **Unicode**：中文与 `\uXXXX` 互转

### 时间转换
- 支持 `YYYY-MM-DD HH:mm:ss` 格式
- 可选择日期时间组件快速输入
- 支持实时更新当前时间

### 二维码
- **生成**：输入文本生成二维码
- **解析**：支持从剪贴板粘贴图片解析，或选择本地图片文件进行解析识别内容

### Cron 表达式
- 通过 Tab 页分别设置：秒、分、时、日、月、周、年
- 支持通配符、范围、步长、指定值
- 支持将表达式反解析回 UI

### 文本对比
- 左侧输入原始文本，右侧输入新文本
- **行级差异**：标记新增/删除的行
- **行内高亮**：精准标记行内字符级变化（如修改了某个单词或标点）

### 便签
- **新建/编辑**：点击新建便签，支持输入文本内容。
- **图片支持**：在编辑界面按 `Ctrl+V` 可直接粘贴剪贴板图片（截图），也可粘贴本地图片文件。
- **搜索功能**：通过顶部搜索框，输入关键字实时筛选便签内容。
- **背景颜色**：便签创建时自动分配随机莫兰迪色系背景。
- **智能提醒**：支持设置定时提醒，集成节假日 API，可选择仅在工作日提醒（自动跳过周末和节假日）。
- **数据清空**：支持一键清空所有便签及关联的本地图片缓存。

## 🔧 依赖说明

| 依赖包 | 用途 |
|--------------|--------|
| provider | 状态管理 |
| intl | 日期格式化 |
| crypto | MD5 计算 |
| qr_flutter | 二维码生成 |
| flutter_zxing | 二维码解析 |
| pasteboard | 剪贴板图片读取 |
| xml2json / xml | XML 与 JSON 转换 |
| diff_match_patch | 文本差异比较 |
| file_selector | 文件选择 |
| desktop_drop | 拖拽文件支持 |
| local_notifier | 系统原生通知 |
| flutter_staggered_grid_view | 瀑布流布局 |
| shared_preferences | 简单配置存储 |
| path_provider | 本地文件路径获取 |
| http | 网络请求 (节假日API) |

## 🤖 AI 重新生成提示词

如需使用 AI 重新生成本项目，可使用以下提示词（包含最新功能的描述）：

```
这是一个 Flutter 项目，刚初始化，希望开发一个开发者工具箱 Windows 软件，页面布局上主要考虑 Windows 桌面端。所需要的功能有：

... (前11个功能保持不变)

12. 桌面便签。支持瀑布流展示，每张便签有不同的随机背景色（莫兰迪色系）。
    - 支持新建、编辑、删除便签。
    - 编辑时支持文本输入，并支持 Ctrl+V 粘贴剪贴板中的图片或图片文件。
    - 列表页提供搜索框，可对便签内容进行模糊搜索过滤。
    - 支持为便签设置定时提醒。提醒功能需结合节假日 API，支持"仅工作日提醒"选项，若开启则自动跳过周末和法定节假日。
    - 提供"清空全部"功能，需二次确认，并清理所有关联的本地图片文件以释放空间。
```

## 📄 许可证

MIT License

## 🙋 贡献

欢迎提交 Issue 和 Pull Request！
