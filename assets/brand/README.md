# 品牌素材目录

把雪鱼专有的标志素材放在这个目录，文件名按下面命名，我就能直接接进代码。

## 需要的文件

| 文件名 | 用途 | 建议 |
| --- | --- | --- |
| `wordmark.png` | 顶栏 `skneo.` 字标 | 透明背景，高度 ≥ 96px（可加 `wordmark@2x.png`、`wordmark@3x.png`） |
| `logo_mark.png` | 方形图标（头像占位、启动图中央标志） | 透明背景，512×512 |
| `app_icon_512.png` | 替换 PWA 桌面图标 | 不透明方图，512×512 |
| `marker_ski.png` / `marker_photo.png` / `marker_food.png` / `marker_gear.png` | 约约约四类活动专属标志 | 透明背景，128×128 |
| `splash.png` | 开屏静态图 | 1080×1920 或 750×1626 |

需要动效开屏时，再加一个 `splash.json`（Lottie）或 `splash.webp`（动态 WebP）。

## 注意事项

- 请给 **PNG 或 WebP**。Flutter 默认不能直接渲染 SVG，用 SVG 需要额外引入 `flutter_svg`。
- 文件名用小写 + 下划线，避免中文与空格。
- 放好后告诉我，我会在 `pubspec.yaml` 注册，并在顶栏、开屏、活动图标处替换。
