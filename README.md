# TCC Dispatcher 🚀

> 我是一个菜鸟，也不是程序员。我只是因为被 macOS 的权限弹窗折磨，所以做了这样一个解决痛点的小工具。或许有大神可以做得比我更好，但这是我目前能想到的最解脱的方案。它原生支持 Alfred。
> 
> I am a newbie, not a programmer. I made this small tool simply because I was tortured by macOS permission popups. Perhaps there are experts who can do this much better than me, but this is the most relieving solution I could come up with so far. It natively supports Alfred.

[中文版](#中文版) | [English](#english)

---

## 中文版

**TCC Dispatcher** 是一款 macOS 权限管理利器，旨在通过极简、专业的流程化操作，终结 macOS 复杂的权限授权痛苦。

### 核心功能
- **极速 Alfred 搜索**：输入 `tcc` 加上应用名，瞬间查看该应用的所有系统权限状态（支持 16 项 macOS 核心隐私权限）。
- **精准跳转与拖拽辅助**：回车一键直达系统设置的最深处。同时自动弹出高亮该 App 的辅助 Finder 窗口，只需移动 1 厘米即可完成高危权限（如全盘访问）的手工拖拽授权。
- **三连发深度链接**：集成 2024/2025 最新跳转协议，精准刺穿系统设置（适配 macOS 14/15/26+）。
- **极度静默**：拒绝任何自作聪明的自动弹窗，所有交互均由您掌控。

### Alfred 集成使用方法
1. 双击项目根目录下的 `TCC_Search_Final.alfredworkflow` 进行安装。
2. 呼出 Alfred，输入 `tcc` + 空格 + 应用名，即时搜索权限。
3. 选择你想修改的权限项，按回车，瞬间跳转到系统设置对应页面，并将 App 自动送到你手边供拖拽。
4. **⌘+回车** (应用项): 快速打开此应用。
*(注：初次使用需要授予 Alfred 自身全盘访问权限以读取 TCC 数据库)*

---

## English

**TCC Dispatcher** is a macOS utility designed to manage privacy permissions (TCC) with a streamlined workflow, ending the pain of macOS's complex permission authorization process.

### Key Features
- **Lightning-fast Alfred Search**: Type `tcc` plus the app name to instantly view all system permission statuses for that app (supports 16 core macOS privacy permissions).
- **Precise Jump & Drag Assist**: Press Enter to jump directly to the deepest level of System Settings. It simultaneously opens a Finder window highlighting the App right next to it, allowing you to grant high-risk permissions (like Full Disk Access) with a 1-centimeter manual drag-and-drop.
- **Triple-Chain Deep Links**: Uses the most advanced URL schemes to jump directly to specific privacy sub-pages in macOS 14/15/26+.
- **Silent & Unobtrusive**: No automatic popups. Everything is manual and follows your lead.

### Alfred Integration
1. Double-click `TCC_Search_Final.alfredworkflow` in the root directory to install.
2. Open Alfred, type `tcc` + space + app name to search permissions instantly.
3. Select a permission item and press Enter to jump to the system settings and have the App served right to your cursor for dragging.
4. **⌘+Enter** on an app item: open the app quickly.
*(Note: Requires granting Alfred Full Disk Access to read the TCC database upon first use)*

---
*Created by a non-programmer who just wanted a better Mac experience.*
