# DeepSeek-Chat
# 🐋 DeepSeek Chat iOS (原生液态玻璃版)

> 一个完全依赖 iPhone 云端构建、极致还原 iOS 26 Liquid Glass 设计语言的 DeepSeek 原生客户端。

![Platform](https://img.shields.io/badge/Platform-iOS%2026.0%2B-blue.svg)
![Language](https://img.shields.io/badge/Language-Swift%206-orange.svg)
![UI](https://img.shields.io/badge/UI-SwiftUI-green.svg)
![Build](https://img.shields.io/badge/Build-GitHub%20Actions-black.svg)

---

## 💡 项目背景：一部手机、一个 AI、两小时

这是一个**没有 Mac 电脑、没有 Xcode** 的非专业开发者，躺在床上一手拿 iPhone，一手和 AI 结对编程，从零开始写出来的全原生 iOS 应用。

从产品需求、UI 设计、Swift 代码编写，到利用 GitHub Actions 进行云端 macOS 编译、产出未签名 IPA，最后使用手机端的签名工具完成真机安装。**全程未触碰任何电脑**。

---

## ✨ 核心特性

- **🪟 极致的 iOS 原生体验**：基于 iOS 26 SDK 打造，顶栏、输入框、气泡全面采用 `GlassEffect` 原生液态玻璃材质，支持环境光折射与动态融合动画。
- **🌗 纯粹的黑白极简美学**：摒弃繁杂的彩色高亮，全局采用纯黑/纯白/毛玻璃的高对比度设计，跟随系统深浅色模式无缝切换。
- **🧠 双模型无缝切换**：原生支持 `DeepSeek-V3` (极速) 与 `DeepSeek-R1` (深度思考)。R1 模型的思考链 (Reasoning) 支持独立折叠展示。
- **📡 内置硬核扩展工具**：
  - **Web 联网搜索**：可接入 Tavily Search API，让 AI 突破知识库限制，回答最新资讯。
  - **本地 RAG 知识库**：支持导入 PDF/TXT 文档，自动在本地进行分块检索，大幅节省 Token 并提升回答准确性。
  - **多模态识图**：预留 OpenAI 格式的 Vision 接口，填入智谱 GLM-4V 等模型即可拍照识图。
- **🛠️ 极客专属沙盒**：
  - **HTML 网页预览**：AI 生成的 HTML 代码可直接在 App 内通过 `WKWebView` 渲染预览。
  - **JS 代码执行**：内置 `JavaScriptCore`，生成的 JS 代码点击即可运行输出结果。
- **🎭 进阶交互玩法**：
  - **双模型自动辩论 (AutoGen)**：设定话题，让 V3 和 R1 自动进行 3 个回合的辩论对垒。
  - **Prompt 模板与角色设定**：支持自定义 System Prompt，内置翻译、代码审查等快捷角色。
- **💎 更多细节**：
  - 原生流式输出，带打字机光标。
  - Apple 原生 `Speech` 框架语音输入。
  - 支持将对话导出为优雅的分享长图，并直接保存至相册。
  - 自动统计 Prompt 与 Completion Token 消耗量。

---

## 📱 界面预览

*(此处建议插入你手机的截图，你可以直接在 GitHub 上编辑这段，把截图拖进去)*
| 主界面 (浅色) | 聊天界面 (深色) | 液态输入框 |
| :---: | :---: | :---: |
| *请替换为截图* | *请替换为截图* | *请替换为截图* |

---

## 🚀 如何构建与安装（纯云端方案）

由于本项目无需 Mac，我们使用 **XcodeGen + GitHub Actions** 进行全自动云端打包。

### 1. 准备环境
- 一个 GitHub 账号（Fork 本仓库）。
- 一张有效的 iOS 签名证书（`.p12`）和描述文件（`.mobileprovision`）。

### 2. 修改配置
- 编辑根目录的 `project.yml`，将 `PRODUCT_BUNDLE_IDENTIFIER` 中的 `com.yourname.DeepSeekChat` 修改为你自己的 Bundle ID。
- （可选）修改 `.github/workflows/build-unsigned.yml` 中的 `runs-on` 环境。

### 3. 触发云端构建
- 进入仓库的 **Actions** 页面。
- 点击左侧的 **Build Unsigned IPA**，在右侧点击 **Run workflow**。
- 等待约 1-2 分钟（XcodeGen 生成工程 + Xcode 26 编译）。构建完成后，在页面底部下载 `DeepSeekChat-unsigned-ipa`。

### 4. 本地签名安装
- 将下载的 `.zip` 解压得到未签名的 `.ipa` 文件。
- 使用你的 iPhone 签名工具（如 轻松签、GBox、全能签 等），导入你的 `.p12` 证书和描述文件。
- 导入刚才解压的 `.ipa` 进行签名并安装到手机上。

---

## ⚙️ 开始使用

1. 首次打开 App，点击左上角菜单进入 **设置**。
2. 填入你的 **DeepSeek API Key**（在 [DeepSeek 开放平台](https://platform.deepseek.com/) 申请）。
3. （可选）填入 **Tavily API Key** 以启用联网搜索功能。
4. 返回主页，点击右上角 `+` 号，开始与你的专属 AI 对话吧！

---

## 🛠️ 技术栈

- **UI 框架**: SwiftUI (iOS 26 Target)
- **编译构建**: XcodeGen, GitHub Actions
- **网络请求**: URLSession, SSE (Server-Sent Events) 流式解析
- **安全存储**: iOS Keychain
- **媒体与文档**: PDFKit, PhotosUI, AVFoundation
- **沙盒运行**: JavaScriptCore, WKWebView

---

## ⚠️ 免责声明

- 本项目仅供个人学习、研究和交流使用，请勿用于商业用途。
- App 内置的 API 均为官方公开接口，请自行前往 DeepSeek 平台获取密钥并遵守相关服务条款。
- 请妥善保管你的 `.p12` 证书和 API Key，切勿随意泄露。

---

## 💖 致谢

- 感谢 **DeepSeek** 提供如此强大且高性价比的大模型 API。
- 感谢 **Apple** 在 iOS 26 中带来了惊艳的液态玻璃渲染引擎。
- 以及，感谢那个在深夜和我结对编程、不知疲倦的 **AI 助手**。