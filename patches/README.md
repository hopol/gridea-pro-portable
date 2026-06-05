# 补丁目录

此目录用于存放对上游源码的补丁文件（如有需要）。

## 当前状态

绿色便携版的构建主要通过 Go build tag `-tags portable` 实现，无需修改源项目代码。

如果未来需要对源码进行微调（例如：修复构建错误、调整默认行为），可在此目录放置 `.patch` 文件，
并在 `scripts/sync-upstream.sh` 中添加 `git apply` 步骤。

## 补丁格式

```bash
# 生成补丁
cd source
git diff > ../patches/fix-something.patch

# 应用补丁（在 sync-upstream.sh 中自动执行）
git apply ../patches/fix-something.patch
```

## 设计原则

- **尽量少打补丁**：优先通过编译参数和构建标签控制行为
- **补丁必须幂等**：多次应用不应出错
- **补丁必须有说明**：每个 `.patch` 文件头部注释说明目的
