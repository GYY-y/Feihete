# 自动发布流程

本项目的发布流程已经封装在 [`tools/release.sh`](tools/release.sh) 中。开发完成后先交给用户验收；只有用户明确确认验收通过并要求发布时，才执行发布流程。

## 使用方式

在项目根目录执行：

```bash
./tools/release.sh --approved
```

不传参数时，脚本会读取 `build.sh` 的当前版本并自动递增 patch 版本。例如 `0.1.2` 会发布为 `0.1.3`。

也可以明确指定版本和分支名：

```bash
./tools/release.sh --approved 0.2.0 release/v0.2.0
```

## 脚本会自动完成的步骤

1. 从当前提交创建新的发布分支，默认名称为 `release/vX.Y.Z`。
2. 同步更新 `build.sh`、`README.md` 和 `说明文档.md` 中的当前版本。
3. 执行 `build.sh`，编译应用、生成 DMG，并验证安装包内容。
4. 将当前工作区修改提交为 `release: vX.Y.Z`。
5. 推送发布分支。
6. 创建并推送带注释的 `vX.Y.Z` Tag。
7. 创建 GitHub Release，自动生成变更说明并上传 `build/Feihete.dmg`。

脚本会拒绝复用已有的分支、Tag 或 Release，避免覆盖历史发布。构建失败时会在提交和推送前停止。

## 前置条件

- 已配置 GitHub `origin` 远端。
- Git 凭据可以推送仓库并创建 Release。
- 项目可以执行 `build.sh`。
- 如果安装了 GitHub CLI，脚本优先使用 `gh release create`；没有安装时会使用 GitHub REST API，并读取本机 Git credential helper 中的凭据。

## 给 AI 的默认约定

完成用户要求的代码修改后，先运行项目检查和测试，然后停下来交给用户验收。收到类似“验收通过，可以发布”“测试通过，帮我发版”的明确确认后，才运行：

```bash
./tools/release.sh --approved
```

如果用户还没有明确确认验收通过，不能运行发布脚本，也不能创建提交、Tag 或 Release。脚本强制要求 `--approved` 参数作为第二道防误发布保护。
