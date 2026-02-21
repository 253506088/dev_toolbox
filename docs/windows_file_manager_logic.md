# Windows 文件管理器模块 - 逻辑设计文档

## 1. 模块概述 (Overview)

本模块旨在为 `dev_toolbox` 提供一个轻量级、可视化的 Windows 文件管理功能。核心目标是快速浏览磁盘结构，直观展示文件/文件夹占用空间，并提供流畅的交互体验。

主要功能点：
1.  **磁盘列表**：调用系统底层命令获取磁盘信息。
2.  **文件浏览**：标准的目录层级浏览。
3.  **空间可视化**：使用 Treemap (矩形树图) 展示空间占用。
4.  **异步计算**：后台线程计算文件夹大小，不阻塞 UI。

## 2. 核心架构 (Architecture)

模块采用标准的 `MVVM` (Model-View-ViewModel) 变体结构，逻辑与 UI 分离。

```mermaid
graph TD
    subgraph UI_Layer [UI 层 (View)]
        MainPage[WindowsFileManagerTool]
        FileList[FileList Widget]
        TreeMap[DiskVisualizer Widget]
        Breadcrumbs[Breadcrumbs Widget]
    end

    subgraph Service_Layer [服务层 (Service)]
        FileService[WindowsFileService]
        SizeService[FolderSizeService]
    end

    subgraph Model_Layer [数据层 (Model)]
        Item[FileSystemItem]
    end

    subgraph System_Layer [系统层]
        PowerShell[PowerShell: Get-CimInstance]
        DartIO[Dart: Directory/File]
        Isolate[Dart: Isolate/Compute]
    end

    %% Relationships
    MainPage -->|展示| FileList
    MainPage -->|展示| TreeMap
    MainPage -->|导航| Breadcrumbs
    
    MainPage -->|调用| FileService
    MainPage -->|调用| SizeService
    
    FileService -->|执行| PowerShell
    FileService -->|读取| DartIO
    
    SizeService -->|后台计算| Isolate
    Isolate -->|递归遍历| DartIO
    
    FileService -->|返回| Item
```

## 3. 详细业务逻辑

### 3.1 初始化与磁盘加载
*   **触发时机**：用户点击侧边栏 "Win文件" 图标，或在根目录点击 "刷新"。
*   **执行逻辑**：
    1.  `WindowsFileManagerTool` 调用 `WindowsFileService.getDisks()`。
    2.  服务层执行 PowerShell 命令 `Get-CimInstance -ClassName Win32_LogicalDisk`。
    3.  解析返回的 JSON 数据，映射为 `FileSystemItem` (Type: `disk`)。
    4.  **UI 更新**：展示磁盘列表，右侧可视化区域展示各磁盘总容量比例。

### 3.2 目录导航 (Drill Down)
*   **触发时机**：用户点击列表项、面包屑或 Treemap 方块。
*   **执行逻辑**：
    1.  更新当前路径 `_currentPath`。
    2.  调用 `WindowsFileService.getFiles(path)`。
    3.  使用 `Directory(path).list()` 获取文件流。
    4.  **排序**：文件夹优先，然后按名称排序。
    5.  **UI 更新**：展示文件列表。
    6.  **后续动作**：触发 `_calculateFolderSizes`（见 3.3）。

### 3.3 文件夹大小计算 (Async Calculation)
*   **背景**：标准文件系统 API 不直接提供文件夹大小，必须递归遍历。这非常耗时，必须异步处理。
*   **执行流程**：
    ```mermaid
    sequenceDiagram
        participant UI as UI (Main Thread)
        participant Tool as WindowsFileManagerTool
        participant Service as FolderSizeService
        participant Iso as Isolate (Background)

        UI->>Tool: 加载目录完成
        Tool->>UI: 展示文件列表 (大小未知/0)
        
        loop 遍历每个文件夹
            Tool->>Service: calculateFolderSize(path)
            Service->>Iso: compute(spawn)
            
            note right of Iso: 递归遍历子文件
            note right of Iso: 累加文件大小
            note right of Iso: 忽略无权限错误
            
            Iso-->>Service: 返回 totalSize
            Service-->>Tool: 返回 size (int)
            
            Tool->>UI: setState(更新单个Item大小)
            UI->>UI: 刷新列表 & 重绘 Treemap
        end
    ```
*   **并发控制**：
    *   目前采用简单的并发策略（通过 `compute` 派发任务）。
    *   **取消机制**：如果用户在计算过程中切换了目录，`_loadPath` 会更新 `_calculatingPath` 标记。异步任务返回时，会检查标记，如果路径不匹配则丢弃结果，防止 UI 闪烁或数据错乱。

### 3.4 空间可视化 (Treemap)
*   **算法**：采用 "Squarified Treemap" 的简化变体（切分填充法）。
*   **逻辑**：
    1.  过滤掉大小为 0 的项。
    2.  按大小降序排列。
    3.  根据权重将屏幕区域切分为矩形。
    4.  **颜色映射**：
        *   磁盘：蓝色系
        *   文件夹：绿色系
        *   文件：橙色系
    5.  **交互**：点击矩形等同于点击列表项。

## 4. 数据模型 (Data Model)

### `FileSystemItem`
| 字段 | 类型 | 说明 |
| :--- | :--- | :--- |
| `path` | `String` | 绝对路径 (唯一标识) |
| `type` | `Enum` | `disk`, `directory`, `file` |
| `size` | `int` | 字节大小 (文件夹初始为0，计算后更新) |
| `isCalculating` | `bool` | 是否正在计算大小 (用于 UI loading 状态) |
| `modified` | `DateTime` | 修改时间 |

## 5. 异常处理
*   **权限拒绝**：在遍历文件大小时，遇到 `AccessDenied` 异常会自动忽略，不中断计算，只统计有权限的文件。
*   **路径不存在**：导航时若路径失效，捕获异常并在 UI 显示错误提示。
*   **PowerShell 失败**：若无法调用 PowerShell（非 Windows 环境或被禁用），返回空磁盘列表并记录日志。

## 6. 待优化项 (TODO)
*   [ ] **缓存机制**：已计算过的文件夹大小可以缓存，避免重复计算（需考虑文件变更）。
*   [ ] **大目录优化**：对于包含数万文件的目录，列表渲染可能卡顿，可引入虚拟滚动。
*   [ ] **深度限制**：目前递归计算大小无深度限制，超深目录可能耗时过长。

---
*文档生成时间：2026-02-21*
