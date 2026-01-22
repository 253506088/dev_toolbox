# 开发者工具箱 (Dev Toolbox)

一款基于 Flutter 开发的 Windows 桌面端开发者工具集合，集成了日常开发中常用的格式化、编解码、转换等功能。

## 📋 功能列表

| 功能 | 说明 |
|------|------|
| SQL IN 格式化 | 将多行文本转为 SQL IN 语句格式，支持反向转换 |
| JSON 格式化 | 格式化、压缩、转义/去转义、Unicode 编解码 |
| 时间转换 | 日期时间与秒级/毫秒级时间戳互转 |
| Base64 | 文本的 Base64 编码与解码 |
| MD5 | 计算文本的 MD5 哈希值 |
| URL 编解码 | URL 参数的编码与解码 |
| 二维码 | 生成二维码图片（解析功能开发中） |
| Cron 表达式 | 可视化 Cron 表达式生成器 |
| XML/JSON 转换 | XML 与 JSON 格式互转 |
| 文本对比 | 对比两段文本的差异，高亮显示增删内容 |

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
│   ├── sql_formatter_tool.dart  # SQL IN 格式化
│   ├── json_formatter_tool.dart # JSON 工具
│   ├── time_converter_tool.dart # 时间转换
│   ├── base64_tool.dart         # Base64 编解码
│   ├── md5_tool.dart            # MD5 计算
│   ├── url_tool.dart            # URL 编解码
│   ├── qr_tool.dart             # 二维码生成
│   ├── cron_tool.dart           # Cron 表达式
│   ├── xml_json_tool.dart       # XML/JSON 转换
│   └── diff_tool.dart           # 文本对比
├── widgets/                     # 可复用组件（预留）
└── utils/                       # 工具类（预留）
```

## 📖 使用说明

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

### Cron 表达式
- 通过 Tab 页分别设置：秒、分、时、日、月、周、年
- 支持通配符、范围、步长、指定值
- 支持将表达式反解析回 UI

### 文本对比
- 左侧输入原始文本，右侧输入新文本
- 自动高亮显示：🟢 新增 / 🔴 删除

## 🔧 依赖说明

| 依赖包 | 用途 |
|--------|------|
| provider | 状态管理 |
| intl | 日期格式化 |
| crypto | MD5 计算 |
| qr_flutter | 二维码生成 |
| xml2json / xml | XML 与 JSON 转换 |
| diff_match_patch | 文本差异比较 |
| file_selector | 文件选择 |
| desktop_drop | 拖拽文件支持 |

## 🤖 AI 重新生成提示词

如需使用 AI 重新生成本项目，可使用以下提示词：

```
这是一个 Flutter 项目，刚初始化，希望开发一个开发者工具箱 Windows 软件，页面布局上主要考虑 Windows 桌面端。所需要的功能有：

1. SQL IN 格式化。输入一串字符串，格式化为 SQL IN 能接受的参数，相反输入 SQL IN 接受的参数，转换为非格式化的。提供【复制】、【清空】按钮

2. JSON 格式化。输入一串 JSON 字符串，提供如下按钮的功能【格式化】、【压缩】、【转义】、【去转义】、【Unicode编码】、【Unicode解码】、【复制】、【清空】

3. 时间与时间戳相互转换，用户输入【YYYY-MM-DD HH:mm:ss】格式的时间（也可以通过时间组件选择），转换为毫秒级和秒级的时间戳，相反输入时间戳（秒级或毫秒的）转换为【YYYY-MM-DD HH:mm:ss】格式的时间

4. Base64 编码与解码

5. MD5 编码

6. URL 编码与解码

7. 二维码生成 & 二维码解析。输入文本内容转换为二维码。粘贴入二维码图片或通过上传二维码图片，解析二维码的内容。

8. Cron 表达式。包含秒、分、时、日、月、周、年的 Tab 页，每个 Tab 支持：每X（通配符*）、周期（范围-）、从X开始每Y执行（步长/）、指定（勾选具体值）。表达式可以转换为 GUI 选项，GUI 选项也可以转换为表达式。

9. XML 转 JSON，JSON 转 XML

10. 文本对比，类似于 Git 那种对比两个文件的差别

注意：这 10 个功能，请按照功能拆分成不同的文件，避免一个文件里塞入了十个功能。
```

## 📄 许可证

MIT License

## 🙋 贡献

欢迎提交 Issue 和 Pull Request！
