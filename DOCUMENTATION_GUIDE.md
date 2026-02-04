# 📚 Snow Fish 文档导航

> **重要**: 所有项目文档已整合到 [PROJECT_COMPLETE_GUIDE.md](PROJECT_COMPLETE_GUIDE.md) 中  
> 请优先查看该文件获取完整的项目信息

---

## 📖 文档导航

### 🎯 快速查阅

**第一次了解项目?**
→ 阅读 [PROJECT_COMPLETE_GUIDE.md](PROJECT_COMPLETE_GUIDE.md) 的前 5 个章节

**需要开发新功能?**
→ 查看 [PROJECT_COMPLETE_GUIDE.md](PROJECT_COMPLETE_GUIDE.md) 的"开发指南"章节

**遇到问题?**
→ 查看 [PROJECT_COMPLETE_GUIDE.md](PROJECT_COMPLETE_GUIDE.md) 的"问题排查"章节

**部署到生产?**
→ 查看 [PROJECT_COMPLETE_GUIDE.md](PROJECT_COMPLETE_GUIDE.md) 的"部署与配置"章节

---

## 📂 文件清单

### 综合文档

| 文档 | 用途 | 优先级 |
|------|------|--------|
| **[PROJECT_COMPLETE_GUIDE.md](PROJECT_COMPLETE_GUIDE.md)** | 完整项目指南（包含所有重要信息） | 🔴 必读 |
| README.md | 项目简介和快速开始 | 🟡 参考 |

### 遗留文档（已整合，保留以参考）

| 文档 | 原用途 | 现状 |
|------|--------|------|
| PROJECT_COMPLETION_REPORT.md | 项目完成报告 | ✅ 已整合 |
| REFACTORING_SUMMARY.md | 重构详情 | ✅ 已整合 |
| ARCHITECTURE_GUIDE.md | 架构指南 | ✅ 已整合 |
| MIGRATION_CHECKLIST.md | 迁移清单 | ✅ 已整合 |
| SUPABASE_UPDATES.md | Supabase 更新说明 | ✅ 已整合 |
| DATABASE_QUERIES.md | 数据库查询示例 | ✅ 已整合 |
| DEPLOYMENT_CHECKLIST.md | 部署清单 | ✅ 已整合 |
| PROJECT_STRUCTURE.md | 项目结构 | ✅ 已整合 |
| QUICK_REFERENCE.md | 快速参考 | ✅ 已整合 |
| FILE_MANIFEST.md | 文件清单 | ✅ 已整合 |

---

## 🗺️ 内容地图

### 项目概述
- 基本信息（名称、类型、版本等）
- 核心特性列表
- 项目目标

**在 PROJECT_COMPLETE_GUIDE.md 中的位置**: [项目概述](#项目概述)

### 技术架构
- 前端技术栈（Flutter, Dart, Material Design）
- 后端技术栈（Supabase, PostgreSQL, OSS）
- 核心依赖包列表

**位置**: [技术架构](#技术架构)

### 数据库设计
- 完整的 SQL 表创建语句
- 表结构说明和字段定义
- 索引和约束策略
- 6 个核心表: entities, media, user_profiles, posts, comments, interactions

**位置**: [数据库设计](#数据库设计)

### 项目结构
- 完整的目录树
- 文件分类说明
- 核心模块介绍

**位置**: [项目结构](#项目结构)

### 核心功能模块
- 6 大模块的设计和流程：
  1. 用户认证
  2. 首页双 Tab
  3. 商品发布
  4. 个人资料
  5. 商品详情
  6. 媒体服务

**位置**: [核心功能模块](#核心功能模块)

### 数据模型
- BaseEntity（通用实体）
- MediaModel（媒体）
- UserProfile（用户资料）
- 完整的 Dart 类定义和使用示例

**位置**: [数据模型](#数据模型)

### 核心服务
- EntityService（统一实体服务）
  - 6 个核心方法
  - 使用示例
- MediaService（媒体服务）
  - 3 个核心方法
  - 特性说明

**位置**: [核心服务](#核心服务)

### 页面路由
- 完整的导航结构树
- 20+ 页面的映射表
- 路由说明

**位置**: [页面路由](#页面路由)

### API 接口
- REST API 示例（实体、媒体、用户资料操作）
- GraphQL 订阅示例
- 完整的请求/响应格式

**位置**: [API 接口](#api-接口)

### Edge Functions
- get-oss-upload-url 函数详细文档
- 请求/响应格式
- 环境变量配置
- 实现细节

**位置**: [Edge Functions](#edge-functions)

### 开发指南
- 5 个常见开发任务的完整步骤
- 代码示例
- 调试技巧

**位置**: [开发指南](#开发指南)

### 部署与配置
- 前置要求
- 环境变量配置
- 部署步骤（6 个步骤）
- OSS Bucket 配置

**位置**: [部署与配置](#部署与配置)

### 问题排查
- 6 个常见问题的解决方案
- 调试清单
- 代码示例

**位置**: [问题排查](#问题排查)

---

## 💡 使用建议

### 按角色查看

**👨‍💼 项目管理者**
1. 项目概述
2. 技术架构（概览）
3. 更新日志

**👨‍💻 开发人员（新手）**
1. 项目概述
2. 项目结构
3. 数据模型
4. 开发指南（第1、2个任务）

**👨‍💻 开发人员（中级）**
1. 核心功能模块
2. 核心服务
3. 开发指南（所有任务）

**🔧 DevOps/运维**
1. 技术架构
2. 数据库设计
3. 部署与配置
4. 问题排查

**🎨 UI/UX 设计师**
1. 页面路由
2. 项目结构（pages 部分）

---

## 📊 文档统计

- **总文档数**: 20+（已整合为 1 个主文档）
- **主文档字数**: 15,000+
- **覆盖的主题**: 13 个
- **代码示例**: 50+
- **表格**: 20+

---

## 🔄 文档维护

### 更新频率
- 每周：开发进度更新
- 每个版本：功能更新
- 实时：bug 修复和问题解决

### 如何贡献
1. 修改 [PROJECT_COMPLETE_GUIDE.md](PROJECT_COMPLETE_GUIDE.md)
2. 保持一致的格式和结构
3. 添加代码示例和说明
4. 更新目录索引

### 反馈渠道
- 提交 GitHub Issue
- 发送邮件
- Pull Request

---

## 🎯 快速链接

### 常用链接
- [Supabase Dashboard](https://supabase.com/dashboard)
- [Flutter Docs](https://flutter.dev/docs)
- [Dart Language Tour](https://dart.dev/guides/language/language-tour)
- [Supabase Docs](https://supabase.com/docs)

### 重要资源
- GitHub 仓库: [链接]
- Supabase 项目: [链接]
- 阿里云 OSS: [链接]

---

## ✅ 验证清单

使用此清单验证文档的完整性：

- [ ] 能够理解项目的整体架构
- [ ] 知道如何添加新功能
- [ ] 明白数据流向
- [ ] 能够部署到生产环境
- [ ] 能够排查和修复常见问题
- [ ] 理解 API 接口和用法
- [ ] 了解开发规范和最佳实践

如果以上都满足，说明你已充分掌握项目！

---

**文档最后更新**: 2026年2月4日  
**下次完整审查时间**: 2026年2月11日
