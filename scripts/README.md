# FluxQ 图标生成脚本

自动生成 FluxQ 项目所需的所有应用图标（iOS、macOS、watchOS）。

## 功能特性

### 🎨 自动生成
- ✅ iOS 图标（@2x、@3x）
- ✅ macOS 图标（1x、2x）
- ✅ watchOS 图标（@2x）
- ✅ Marketing icons（1024x1024）

### 🔍 智能验证
- ✅ 生成前清理旧图标
- ✅ 正确处理 marketing icons（1x 而非 @2x）
- ✅ 自动验证与 Contents.json 匹配
- ✅ 检测缺失或多余的文件
- ✅ 防止 Xcode "unassigned child" 警告

### 📦 双应用支持
- ✅ FluxQ (iOS/macOS) - 28 个图标
- ✅ FluxQWatch (watchOS) - 1 个图标

## 使用方法

### 基本用法

```bash
./scripts/generate-icons.sh
```

### 输出示例

```
Generating FluxQ app icons...
Cleaning old icons...
Creating base icon...
✅ Generated icon: /tmp/icon-base.png
Generating macOS icons...
Generating iOS icons...
Generating watchOS icons...
Copying watchOS icon to FluxQWatch...

Validating generated icons...
✅ FluxQ: All 28 icons match Contents.json
✅ FluxQWatch: All 1 icons match Contents.json

✅ Icons generated successfully!
📁 FluxQ Output: FluxQ/Assets.xcassets/AppIcon.appiconset
📁 FluxQWatch Output: FluxQWatch/Assets.xcassets/AppIcon.appiconset
```

## 依赖项

脚本会自动检查并安装依赖：

1. **ImageMagick** - 图像处理
   ```bash
   brew install imagemagick
   ```

2. **Python 3 + Pillow** - 基础图标生成
   ```bash
   pip3 install Pillow
   ```

## 生成的图标

### FluxQ (iOS/macOS)

| 平台 | 尺寸 | 数量 |
|-----|------|------|
| iOS | 20pt - 83.5pt (@2x/@3x) | 11 |
| macOS | 16px - 1024px (1x/2x) | 7 |
| watchOS | 24pt - 108pt (@2x) | 9 |
| Marketing | 1024x1024 (1x) | 1 |
| **总计** | | **28** |

### FluxQWatch (watchOS)

| 类型 | 尺寸 | 数量 |
|-----|------|------|
| Marketing Icon | 1024x1024 (1x) | 1 |

## 脚本流程

```
1. 清理旧图标 → 2. 生成基础图标 → 3. 生成各平台图标
                      ↓
4. 复制到 FluxQWatch ← 5. 验证文件完整性 → 6. 报告结果
```

## 验证机制

脚本会自动验证：

1. **完整性检查**
   - 确保所有 Contents.json 中配置的文件都已生成
   - 检测缺失的图标文件

2. **清洁性检查**
   - 检测多余的图标文件
   - 防止"unassigned child"警告

3. **语法检查**
   - 验证 Contents.json 语法正确

## 错误处理

### 缺失文件

```
❌ Missing files: icon-ios-1024.png
⚠️  Validation failed. Please check the files.
```

### 多余文件

```
⚠️  Extra files: icon-extra.png
⚠️  Validation failed. Please check the files.
```

### 解决方法

脚本会自动清理旧文件，如果仍有问题：

```bash
# 清理并重新生成
rm FluxQ/Assets.xcassets/AppIcon.appiconset/icon-*.png
rm FluxQWatch/Assets.xcassets/AppIcon.appiconset/icon-*.png
./scripts/generate-icons.sh
```

## Xcode 缓存问题

如果 Xcode 显示"unassigned child"警告，但脚本验证通过：

```bash
# 1. 清理 Xcode 缓存
rm -rf ~/Library/Developer/Xcode/DerivedData/FluxQ-*

# 2. 清理构建
xcodebuild clean -project FluxQ.xcodeproj -scheme FluxQ

# 3. 重新构建
xcodebuild build -project FluxQ.xcodeproj -scheme FluxQ
```

## 颜色配置

品牌绿色定义在脚本顶部：

```bash
FLUXQ_GREEN="#00C733"
```

如需修改品牌色，编辑此变量并重新运行脚本。

## 相关文件

- `scripts/generate-icons.sh` - 主生成脚本
- `scripts/generate-icon-base.py` - 基础图标生成器
- `FluxQ/Assets.xcassets/AppIcon.appiconset/Contents.json` - iOS/macOS 图标配置
- `FluxQWatch/Assets.xcassets/AppIcon.appiconset/Contents.json` - watchOS 图标配置

## 最佳实践

1. ✅ **每次修改品牌色后运行**：确保所有图标使用最新颜色
2. ✅ **提交前运行**：确保图标完整且与配置匹配
3. ✅ **清理 Xcode 缓存**：如果 Xcode 显示警告但验证通过
4. ❌ **不要手动编辑图标**：使用脚本生成以保证一致性

## 故障排查

### 问题：ImageMagick 安装失败

```bash
# macOS
brew install imagemagick

# Linux
sudo apt-get install imagemagick
```

### 问题：Pillow 安装失败

```bash
pip3 install --break-system-packages --user Pillow
```

### 问题：生成的图标模糊

检查 `generate-icon-base.py` 中的字体路径和渲染设置。

## 参考

- [Apple Human Interface Guidelines - App Icons](https://developer.apple.com/design/human-interface-guidelines/app-icons)
- [Asset Catalog Format Reference](https://developer.apple.com/library/archive/documentation/Xcode/Reference/xcode_ref-Asset_Catalog_Format/)
