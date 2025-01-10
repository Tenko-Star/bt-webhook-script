#!/bin/bash

# BT bug
# Why???
echo ""

######################## 配置 ########################
# 本地项目目录
project_path=''
# Git仓库地址
git_path=''

# 要更新的分支
branch_name='master'

# 更新模式
# - tag模式：仅更新到最新的tag，其他情况不更新，不跟随主线更新
# - master模式：跟随主线更新，直接更新到最新的一条记录
mode='tag'
# mode='master'

# 彩色终端
# 如果终端或使用日志模式，可以设置为0来关闭色彩，避免不必要的输出
enable_color=1
####################################################

###################### 运行信息 #####################
user=$(whoami)
execute_time=$(date -d today '+%Y-%m-%d %H:%M:%S')
remote_branch_name="origin/$branch_name"
####################################################

######################## 函数 ########################
function error() {
  if $enable_color; then
    echo -e "\033[31m\033[47mError: $1\033[0m"
  else
    echo "$1"
  fi
}

function success() {
  if $enable_color; then
    echo -e echo -e "\033[42m$1\033[0m"
  else
    echo "$1"
  fi
}

function fixPermission() {
  if ! chown -R www:www "$project_path"; then
    error "Could not fix permission."
    exit 2
  fi

  return 0
}

function isOriginUpdated() {
  (
    cd "$project_path" || exit 1
    git fetch
    local_hash=$(git rev-parse "$branch_name")
    remote_hash=$(git rev-parse $remote_branch_name)

    if [[ "$local_hash" == "$remote_hash" ]];then
        return 1
      else
        return 0
      fi
  )
}

function isTagUpdated() {
  (
    cd "$project_path" || exit 1
    current_tag=$(git describe --abbrev --tags 2>/dev/null | tr -d '[:space:]')
    last_tag=$(git tag -l 2>/dev/null | sort -V | tail -n 1 | tr -d '[:space:]')

    if [[ -z "$current_tag" ]]; then
      error "The current branch is not associated with any tag."
      return 1
    fi

    if [[ "$current_tag" == "$last_tag" ]]; then
      return 0
    else
      return 1
    fi
  )
}

function checkLocalRepository() {
  # 检查文件夹是否存在
  if [ ! -d "$project_path" ]; then
    # 如果不存在，则克隆仓库
    if git clone "$git_path" "$project_path"; then
      git config --global --add safe.directory "$project_path"
      success "Update success."
      exit 0
    else
      error "Could not create local repository: $project_path, remote: $git_path"
      exit 1
    fi
  fi
}

function resetRepository() {
  (
    cd "$project_path" || exit 1
    if ! git reset --hard "$remote_branch_name"; then
      error "Could not reset local repository."
      exit 3
    fi
  )

  return 0
}

function updateRepository() {
  (
    cd "$project_path" || exit 1
    git rebase "$remote_branch_name"
    fixPermission
  )

  return 0
}

function updateToNewestTag() {
  (
    cd "$project_path" || exit 1
    git fetch
    if isTagUpdated; then
      latest_tag=$(git tag -l | sort -V | tail -n 1)
      git checkout "$latest_tag"
      fixPermission
      return $?
    else
      return 1
    fi
  )
}

####################################################

####################### Main #######################

echo "-------------------- Run Git WebHook --------------------"
echo "Start time: $execute_time"
echo "User: $user"
echo "Remote repository: $git_path"
echo "Local repository: $project_path"
echo "---------------------------------------------------------"

checkLocalRepository
if ! isOriginUpdated; then
  success "Origin is not update."
  exit 0
fi

if [[ "$mode" == "master" ]]; then
  resetRepository
  updateRepository
elif [[ "$mode" == "tag" ]]; then
  resetRepository
  updateToNewestTag
else
  error "Mode not support."
fi

success "Update success."