#!/usr/bin/env bash
set -euo pipefail

# Publish the current worktree as a versioned GitHub release.
# Usage: ./tools/release.sh --approved [version] [branch]

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT_DIR"

REMOTE="${RELEASE_REMOTE:-origin}"
BUILD_FILE="build.sh"
PRODUCT_NAME="Feihete"
ASSET="build/${PRODUCT_NAME}.dmg"

approved=false
args=()
for arg in "$@"; do
    if [[ "$arg" == "--approved" ]]; then
        approved=true
    else
        args+=("$arg")
    fi
done

if [[ "$approved" != true ]]; then
    echo "发布前必须先完成验收，并使用 --approved 明确确认。" >&2
    echo "用法: $0 --approved [版本号] [分支名]" >&2
    exit 2
fi

if [[ ${#args[@]} -gt 2 ]]; then
    echo "用法: $0 --approved [版本号] [分支名]" >&2
    exit 2
fi

current_version=$(sed -nE 's/^VERSION="([0-9]+\.[0-9]+\.[0-9]+)"/\1/p' "$BUILD_FILE" | head -1)
if [[ -z "$current_version" ]]; then
    echo "无法从 ${BUILD_FILE} 读取 VERSION。" >&2
    exit 1
fi

if [[ -n "${args[0]:-}" ]]; then
    version="${args[0]}"
else
    version=$(CURRENT_VERSION="$current_version" python3 - <<'PY'
import os
major, minor, patch = (int(part) for part in os.environ["CURRENT_VERSION"].split("."))
print(f"{major}.{minor}.{patch + 1}")
PY
)
fi

if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "版本号必须是 x.y.z 格式: ${version}" >&2
    exit 2
fi

tag="v${version}"
branch="${args[1]:-release/${tag}}"

if git show-ref --verify --quiet "refs/tags/${tag}" || \
   git ls-remote --exit-code --tags "$REMOTE" "refs/tags/${tag}" >/dev/null 2>&1; then
    echo "标签 ${tag} 已存在，脚本停止以避免覆盖已有 Release。" >&2
    exit 1
fi

if git show-ref --verify --quiet "refs/heads/${branch}"; then
    echo "本地分支 ${branch} 已存在，脚本停止以避免覆盖已有开发分支。" >&2
    exit 1
fi

if git ls-remote --exit-code --heads "$REMOTE" "$branch" >/dev/null 2>&1; then
    echo "远端分支 ${branch} 已存在，脚本停止以避免覆盖已有开发分支。" >&2
    exit 1
fi

echo "创建发布分支: ${branch}"
git switch -c "$branch"

CURRENT_VERSION="$current_version" NEXT_VERSION="$version" python3 - <<'PY'
from pathlib import Path
import os
import re

old = os.environ["CURRENT_VERSION"]
new = os.environ["NEXT_VERSION"]
files = {
    Path("build.sh"): [(rf'(?m)^VERSION="{re.escape(old)}"', f'VERSION="{new}"')],
    Path("README.md"): [(rf'(当前版本\**\s*){re.escape(old)}', rf'\g<1>{new}')],
    Path("说明文档.md"): [(rf'(当前版本\s*:)\s*{re.escape(old)}', rf'\g<1>{new}')],
}

for path, replacements in files.items():
    if not path.exists():
        continue
    text = path.read_text(encoding="utf-8")
    updated = text
    for pattern, replacement in replacements:
        updated = re.sub(pattern, replacement, updated)
    if updated != text:
        path.write_text(updated, encoding="utf-8")
PY

cache_dir=$(mktemp -d "${TMPDIR:-/tmp}/feihete-module-cache.XXXXXX")
cleanup_files=()
cleanup() {
    rm -rf "$cache_dir"
    # macOS 自带 bash 3.2 在 set -u 下展开空数组会报 unbound variable
    if [[ ${#cleanup_files[@]} -gt 0 ]]; then
        for path in "${cleanup_files[@]}"; do
            rm -f "$path"
        done
    fi
}
trap cleanup EXIT

echo "构建并校验安装包"
CLANG_MODULE_CACHE_PATH="$cache_dir" \
SWIFT_MODULECACHE_PATH="$cache_dir" \
    ./build.sh

if [[ ! -f "$ASSET" ]]; then
    echo "构建完成但找不到 ${ASSET}。" >&2
    exit 1
fi

git diff --check
git add -A
if git diff --cached --quiet; then
    echo "没有可提交的修改。" >&2
    exit 1
fi

git commit -m "release: ${tag}"
git push -u "$REMOTE" "$branch"
git tag -a "$tag" -m "Release ${tag}"
git push "$REMOTE" "$tag"

previous_tag=""
if previous_tag=$(git describe --tags --abbrev=0 "${tag}^" 2>/dev/null); then
    :
fi
notes_file=$(mktemp "${TMPDIR:-/tmp}/feihete-release-notes.XXXXXX")
cleanup_files+=("$notes_file")
{
    echo "## 变更"
    echo
    if [[ -n "$previous_tag" ]]; then
        git log --pretty=format:'- %s' "${previous_tag}..${tag}"
    else
        git log --pretty=format:'- %s' "$tag"
    fi
    echo
    echo
    echo "## 安装"
    echo
    echo '下载 `Feihete.dmg`，打开后将 Feihete.app 拖入 Applications 文件夹。'
} > "$notes_file"

remote_url=$(git remote get-url "$REMOTE")
# 兼容 GitHub 镜像远端（如 https://gitclone.com/github.com/owner/repo.git）
repo_slug=$(printf '%s' "$remote_url" | sed -E 's#^(git@github\.com:|https?://github\.com/|https?://[^/]+/github\.com/)##; s#\.git$##')
if [[ ! "$repo_slug" =~ ^[^/]+/[^/]+$ ]]; then
    echo "无法从远端地址解析 GitHub 仓库: ${remote_url}" >&2
    exit 1
fi

release_url=""
if command -v gh >/dev/null 2>&1; then
    release_url=$(gh release create "$tag" "$ASSET" \
        --repo "$repo_slug" \
        --title "${PRODUCT_NAME} ${tag}" \
        --notes-file "$notes_file")
else
    cred_file=$(mktemp "${TMPDIR:-/tmp}/feihete-git-cred.XXXXXX")
    netrc_file=$(mktemp "${TMPDIR:-/tmp}/feihete-netrc.XXXXXX")
    response_file=$(mktemp "${TMPDIR:-/tmp}/feihete-release-response.XXXXXX")
    cleanup_files+=("$cred_file" "$netrc_file" "$response_file")

    printf 'protocol=https\nhost=github.com\n\n' | git credential fill > "$cred_file"
    gh_user=$(awk -F= '$1 == "username" {print substr($0, index($0,"=")+1)}' "$cred_file")
    gh_pass=$(awk -F= '$1 == "password" {print substr($0, index($0,"=")+1)}' "$cred_file")
    if [[ -z "$gh_user" || -z "$gh_pass" ]]; then
        echo "找不到 GitHub 凭据。请先安装 gh 并执行 gh auth login，或配置 git credential。" >&2
        exit 1
    fi

    printf 'machine api.github.com login %s password %s\nmachine uploads.github.com login %s password %s\n' \
        "$gh_user" "$gh_pass" "$gh_user" "$gh_pass" > "$netrc_file"
    chmod 600 "$netrc_file"

    TAG="$tag" BRANCH="$branch" NOTES_FILE="$notes_file" BODY_FILE="$response_file" \
        python3 - <<'PY'
import json
import os
from pathlib import Path

body = {
    "tag_name": os.environ["TAG"],
    "target_commitish": os.environ["BRANCH"],
    "name": f"Feihete {os.environ['TAG']}",
    "body": Path(os.environ["NOTES_FILE"]).read_text(encoding="utf-8"),
    "draft": False,
    "prerelease": False,
}
Path(os.environ["BODY_FILE"]).write_text(json.dumps(body, ensure_ascii=False), encoding="utf-8")
PY

    curl -sS --fail --netrc-file "$netrc_file" \
        -X POST \
        -H 'Accept: application/vnd.github+json' \
        -H 'Content-Type: application/json' \
        -H 'X-GitHub-Api-Version: 2022-11-28' \
        --data-binary "@$response_file" \
        "https://api.github.com/repos/${repo_slug}/releases" > "${response_file}.created"
    cleanup_files+=("${response_file}.created")

    release_id=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["id"])' "${response_file}.created")
    release_url=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["html_url"])' "${response_file}.created")
    curl -sS --fail --netrc-file "$netrc_file" \
        -X POST \
        -H 'Accept: application/vnd.github+json' \
        -H 'Content-Type: application/x-apple-diskimage' \
        -H 'X-GitHub-Api-Version: 2022-11-28' \
        --data-binary "@$ASSET" \
        "https://uploads.github.com/repos/${repo_slug}/releases/${release_id}/assets?name=$(basename "$ASSET")" >/dev/null
fi

echo
echo "发布完成: ${release_url}"
echo "下载地址: https://github.com/${repo_slug}/releases/download/${tag}/$(basename "$ASSET")"
