# FluxQ DMG 自动构建设计

## 目标

在 Xcode 中选择 `FluxQ DMG` scheme 后点击 Build (⌘B)，自动完成 macOS Release 构建、代码签名、公证、DMG 打包。

## 架构

Aggregate Target `FluxQ DMG` → 依赖 `FluxQ` app target → Run Script Phase 调用打包脚本。

```
Build FluxQ.app (Release)
  → codesign (Developer ID Application)
  → notarize (xcrun notarytool)
  → staple
  → hdiutil create DMG (含 Applications 快捷方式)
```

## 文件结构

```
scripts/
├── create-dmg.sh       # DMG 打包（hdiutil + Applications symlink）
├── notarize.sh          # 签名 + 公证 + staple
├── generate-icons.sh    # 已有
└── generate-icon-base.py # 已有
```

## 脚本职责

### create-dmg.sh

输入：`$BUILT_PRODUCTS_DIR/FluxQ.app`
输出：`build/FluxQ-<version>.dmg`

1. 从 Info.plist 读取版本号
2. 创建临时文件夹，放入 `.app` + `Applications` symlink
3. `hdiutil create` 生成 DMG
4. 清理临时文件

### notarize.sh

输入：已签名的 `.app` 路径
输出：公证并 staple 后的 `.app`

1. `codesign --deep --force --options runtime --sign "Developer ID Application: ..."` 签名
2. `ditto -c -k` 创建 zip
3. `xcrun notarytool submit` 提交公证
4. `xcrun notarytool wait` 等待完成
5. `xcrun stapler staple` 钉合票据
6. 凭证通过 Keychain profile 或环境变量传入

## Xcode 集成

- **Target**: Aggregate Target `FluxQ DMG`
  - Target Dependency: `FluxQ`
  - Run Script Phase: `"${SRCROOT}/scripts/create-dmg.sh"`
  - Build Configuration: Release
- **Scheme**: `FluxQ DMG`
  - Build action: `FluxQ DMG` target
  - Build Configuration: Release

## 凭证配置

通过环境变量传入（不硬编码）：

| 变量 | 用途 |
|------|------|
| `DEVELOPER_ID_NAME` | 签名证书名 |
| `TEAM_ID` | Apple Developer Team ID |
| `NOTARIZE_KEYCHAIN_PROFILE` | notarytool Keychain profile 名 |

首次配置：
```bash
xcrun notarytool store-credentials "FluxQ-notarize" \
  --apple-id "your@email.com" \
  --team-id "XXXXXXXXXX" \
  --password "app-specific-password"
```

## 使用方式

1. Xcode 选择 `FluxQ DMG` scheme
2. ⌘B 构建
3. 输出 `build/FluxQ-x.x.x.dmg`
