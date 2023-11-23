#!/usr/bin/env bash

# 脚本报错即刻退出
set -e

DEFAULT_REGISTRY=ccr.ccs.tencentyun.com
DEFAULT_NAMESPACE=vnimy
DEFAULT_MAIN_VERSION=version-14
DEFAULT_FRAPPE_REPO=https://gitee.com/mirrors/frappe.git
DEFAULT_ERPNEXT_REPO=https://gitee.com/mirrors/erpnext.git
DEFAULT_ERPNEXT_CHINESE_REPO=https://gitee.com/yuzelin/erpnext_chinese.git
DEFAULT_ERPNEXT_OOB_REPO=https://gitee.com/yuzelin/erpnext_oob.git
DEFAULT_IMAGE_NAME=erp

set -a # automatically export all variables
  if [ -f .env ]; then
  source .env
  fi
set +a

function show_usage() {
  echo -e "
    用法：
      <命令> [选项]
    
    命令：
      help                    帮助
      base [选项]             构建基础镜像
      builder [选项]          构建builder镜像
      builder-oob [选项]      构建builder-oob镜像
      custom [选项]           构建自定义APP镜像
      backend [选项]          构建后端镜像
      [镜像] [-h | --help]    镜像构建帮助
      get-default             查看当前构建默认值
      set-default [选项]      设置构建默认值
                                使用方法：set-default param1=value1 param2=value2 ...
                                支持以下参数：
                                镜像注册中心          registry
                                镜像命名空间          namespace
                                主版本                main_version
                                Frappe仓库            frappe_path
                                ERPNext仓库           erpnext_path
                                ERPNext Chinese仓库   erpnext_chinese_path
                                ERPNext OOB仓库       erpnext_oob_path";
}

function show_backend_usage() {
  echo -e "
    用法：
      backend [选项]
    
    命令：
      -h,--help                         帮助
      -f,--apps_file [path]             apps json文件路径，默认：apps.json
      -r,--registry [registry]          镜像注册中心，默认：$DEFAULT_REGISTRY
      -n,--namespace [namespace]        镜像注册中心的命名空间，默认：$DEFAULT_NAMESPACE
      -v,--version [version]            主版本，默认：$DEFAULT_MAIN_VERSION
      -i,--image [name]                 镜像名称，不包含标签，默认：$DEFAULT_NAMESPACE/$DEFAULT_IMAGE_NAME
      -t,--tag [name]                   镜像标签，默认：$DEFAULT_MAIN_VERSION.$(date '+%y%m%d')
         --frappe-repo [repo]           Frappe框架仓库地址，默认：$DEFAULT_FRAPPE_REPO
      -c,--cached                       使用缓存进行构建，默认不使用缓存";
}

function show_custom_usage() {
  echo -e "
    用法：
      backend [选项]
    
    命令：
      -h,--help                         帮助
      -r,--registry [registry]          镜像注册中心，默认：$DEFAULT_REGISTRY
      -n,--namespace [namespace]        镜像注册中心的命名空间，默认：$DEFAULT_NAMESPACE
      -v,--version [version]            主版本，默认：$DEFAULT_MAIN_VERSION
      -i,--image [name]                 镜像名称，不包含标签，默认：$DEFAULT_NAMESPACE/$DEFAULT_IMAGE_NAME
      -t,--tag [name]                   镜像标签，默认：$DEFAULT_MAIN_VERSION.$(date '+%y%m%d')
         --app-branch [branch]          自定义应用分支名称，默认：master
         --app-repo [repo]              自定义应用仓库地址
         --app-name [name]              自定义应用名称";
}

function show_builder_oob_usage() {
  echo -e "
    用法：
      builder-oob [选项]
    
    命令：
      -h,--help                         帮助
      -r,--registry [registry]          镜像注册中心，默认：$DEFAULT_REGISTRY
      -n,--namespace [namespace]        镜像注册中心的命名空间，默认：$DEFAULT_NAMESPACE
      -v,--version [version]            主版本，默认：$DEFAULT_MAIN_VERSION
         --frappe-repo [repo]           Frappe框架仓库地址，默认：$DEFAULT_FRAPPE_REPO
         --erpnext-repo [repo]          ERPNext仓库地址，默认：$DEFAULT_ERPNEXT_REPO
         --erpnext-chinese-repo [repo]  ERPNext Chinese仓库地址，默认：$DEFAULT_ERPNEXT_CHINESE_REPO
         --erpnext-oob-repo [repo]      ERPNext OOB仓库地址，默认：$DEFAULT_ERPNEXT_OOB_REPO
      -c,--cached                       使用缓存进行构建，默认不使用缓存";
}

function show_base_usage() {
  echo -e "
    用法：
      base [选项]
    
    命令：
      -h,--help                         帮助
      -r,--registry [registry]          镜像注册中心，默认：$DEFAULT_REGISTRY
      -n,--namespace [namespace]        镜像注册中心的命名空间，默认：$DEFAULT_NAMESPACE";
}

function show_builder_usage() {
  echo -e "
    用法：
      builder [选项]
    
    命令：
      -h,--help                         帮助
      -r,--registry [registry]          镜像注册中心，默认：$DEFAULT_REGISTRY
      -n,--namespace [namespace]        镜像注册中心的命名空间，默认：$DEFAULT_NAMESPACE";
}

function build_base() {
  NAMESPACE=$DEFAULT_NAMESPACE
  REGISTRY=$DEFAULT_REGISTRY

  ARGS=`getopt -o hr:n -al help,registry:,namespace: -- "$@"`
  if [ $? != 0 ];then
    echo "Terminating..."
    exit 1
  fi

  #重新排列参数顺序
  eval set -- "${ARGS}"
  #通过shift和while循环处理参数
  while :
  do
    case $1 in
      -r|--registry)
        REGISTRY=$2
        shift 2
        ;;
      -n|--namespace)
        NAMESPACE=$2
        shift 2
        ;;
      -h|--help)
        show_base_usage
        exit 0
        ;;
      --)
        shift
        break
        ;;
      *)
        show_base_usage
        exit 0
        ;;
  esac done

  IMAGE=${REGISTRY}/$NAMESPACE/frappe-base:latest
  echo "开始构建镜像：$IMAGE"

  docker build \
    --build-arg=DOCKER_REGISTRY=$REGISTRY \
    --build-arg=DOCKER_NAMESPACE=$NAMESPACE \
    --tag=$IMAGE \
    --file=Dockerfile.base .
  docker push $IMAGE

  echo "构建完成"

  if [ $? -eq 0 ]; then
    docker push $IMAGE
    echo "推送完成"
  fi
}

function build_builder() {
  NAMESPACE=$DEFAULT_NAMESPACE
  REGISTRY=$DEFAULT_REGISTRY

  ARGS=`getopt -o hr:n -al help,registry:,namespace: -- "$@"`
  if [ $? != 0 ];then
    echo "Terminating..."
    exit 1
  fi

  #重新排列参数顺序
  eval set -- "${ARGS}"
  #通过shift和while循环处理参数
  while :
  do
    case $1 in
      -r|--registry)
        REGISTRY=$2
        shift 2
        ;;
      -n|--namespace)
        NAMESPACE=$2
        shift 2
        ;;
      -h|--help)
        show_builder_usage
        exit 0
        ;;
      --)
        shift
        break
        ;;
      *)
        show_builder_usage
        exit 0
        ;;
  esac done

  IMAGE=${REGISTRY}/$NAMESPACE/frappe-builder:latest
  echo "开始构建镜像：$IMAGE"

  docker build \
    --build-arg=DOCKER_REGISTRY=$REGISTRY \
    --build-arg=DOCKER_NAMESPACE=$NAMESPACE \
    --tag=$IMAGE \
    --file=Dockerfile.builder .
  docker push $IMAGE

  echo "构建完成"

  if [ $? -eq 0 ]; then
    docker push $IMAGE
    echo "推送完成"
  fi
}

function build_builder_oob() {
  NAMESPACE=$DEFAULT_NAMESPACE
  REGISTRY=$DEFAULT_REGISTRY
  CACHE_ARG=--no-cache

  MAIN_VERSION=$DEFAULT_MAIN_VERSION

  FRAPPE_REPO=$DEFAULT_FRAPPE_REPO
  ERPNEXT_REPO=$DEFAULT_ERPNEXT_REPO
  ERPNEXT_CHINESE_REPO=$DEFAULT_ERPNEXT_CHINESE_REPO
  ERPNEXT_OOB_REPO=$DEFAULT_ERPNEXT_OOB_REPO

  ARGS=`getopt -o hcr:n:v: -al help,cached,registry:,namespace:,version:,frappe-repo:,erpnext-repo:,erpnext-chinese-repo:,erpnext-oob-repo: -- "$@"`
  if [ $? != 0 ];then
    echo "Terminating..."
    exit 1
  fi

  #重新排列参数顺序
  eval set -- "${ARGS}"
  #通过shift和while循环处理参数
  while :
  do
    case $1 in
      -r|--registry)
        REGISTRY=$2
        shift 2
        ;;
      -n|--namespace)
        NAMESPACE=$2
        shift 2
        ;;
      --frappe-repo)
        FRAPPE_REPO=$2
        shift 2
        ;;
      --erpnext-repo)
        ERPNEXT_REPO=$2
        shift 2
        ;;
      --erpnext-chinese-repo)
        ERPNEXT_CHINESE_REPO=$2
        shift 2
        ;;
      --erpnext-oob-repo)
        ERPNEXT_OOB_REPO=$2
        shift 2
        ;;
      -v|--version)
        MAIN_VERSION=$2
        shift 2
        ;;
      -c|--cached)
        CACHE_ARG=""
        shift
        ;;
      -h|--help)
        show_builder_oob_usage
        exit 0
        ;;
      --)
        shift
        break
        ;;
      *)
        show_builder_oob_usage
        exit 0
        ;;
  esac done

  IMAGE=${REGISTRY}/${NAMESPACE}/frappe-builder-oob:${MAIN_VERSION}
  echo "开始构建镜像：$IMAGE"

  docker build \
    --build-arg=DOCKER_REGISTRY=$REGISTRY \
    --build-arg=DOCKER_NAMESPACE=$NAMESPACE \
    --build-arg=FRAPPE_REPO=$FRAPPE_REPO \
    --build-arg=FRAPPE_BRANCH=$MAIN_VERSION \
    --build-arg=ERPNEXT_REPO=$ERPNEXT_REPO \
    --build-arg=ERPNEXT_BRANCH=$MAIN_VERSION \
    --build-arg=ERPNEXT_CHINESE_REPO=$ERPNEXT_CHINESE_REPO \
    --build-arg=ERPNEXT_CHINESE_BRANCH=master \
    --build-arg=ERPNEXT_OOB_REPO=$ERPNEXT_OOB_REPO \
    --build-arg=ERPNEXT_OOB_BRANCH=$MAIN_VERSION \
    --tag=$IMAGE \
    --file=Dockerfile.builder-oob $CACHE_ARG .

  echo "构建完成"

  if [ $? -eq 0 ]; then
    docker push $IMAGE
    echo "推送完成"
  fi
}

function build_backend() {
  MAIN_VERSION=$DEFAULT_MAIN_VERSION
  DATE_VERSION=$(date '+%y%m%d')
  TAG=$MAIN_VERSION.$DATE_VERSION
  NAMESPACE=$DEFAULT_NAMESPACE
  IMAGE_NAME=$NAMESPACE/$DEFAULT_IMAGE_NAME
  REGISTRY=$DEFAULT_REGISTRY
  APPS_FILE=apps.json
  CACHE_ARG=--no-cache
  FRAPPE_REPO=$DEFAULT_FRAPPE_REPO

  ARGS=`getopt -o hcf:r:n:i:t:v: -al help,cached,apps_file:,registry:,namespace:,image:,tag:,version:,frappe-repo: -- "$@"`
  if [ $? != 0 ];then
    echo "Terminating..."
    exit 1
  fi

  #重新排列参数顺序
  eval set -- "${ARGS}"
  #通过shift和while循环处理参数
  while :
  do
    case $1 in
      -f|--apps_file)
        APPS_FILE=$2
        shift 2
        ;;
      -t|--tag)
        TAG=$2
        shift 2
        ;;
      -r|--registry)
        REGISTRY=$2
        shift 2
        ;;
      -i|--image)
        IMAGE_NAME=$2
        shift 2
        ;;
      -n|--namespace)
        NAMESPACE=$2
        shift 2
        ;;
      --frappe-repo)
        FRAPPE_REPO=$2
        shift 2
        ;;
      -v|--version)
        MAIN_VERSION=$2
        shift 2
        ;;
      -c|--cached)
        CACHE_ARG=""
        shift
        ;;
      -h|--help)
        show_backend_usage
        exit 0
        ;;
      --)
        shift
        break
        ;;
      *)
        show_backend_usage
        exit 0
        ;;
  esac done

  if [ ! -f $APPS_FILE ]; then
    echo "${APPS_FILE}文件不存在"
    exit 1
  fi

  IMAGE=${REGISTRY}/${IMAGE_NAME}:${TAG}
  echo "开始构建镜像：$IMAGE"

  docker build \
    --build-arg=DOCKER_REGISTRY=$REGISTRY \
    --build-arg=DOCKER_NAMESPACE=$NAMESPACE \
    --build-arg=FRAPPE_REPO=$FRAPPE_REPO \
    --build-arg=FRAPPE_BRANCH=$MAIN_VERSION \
    --build-arg=APPS_JSON_BASE64=$(base64 -w 0 ${APPS_FILE}) \
    --tag=$IMAGE $CACHE_ARG .

  echo "构建完成"

  if [ $? -eq 0 ]; then
    docker push $IMAGE
    echo "推送完成"
  fi
}

function build_custom() {
  MAIN_VERSION=$DEFAULT_MAIN_VERSION
  DATE_VERSION=$(date '+%y%m%d')
  TAG=$MAIN_VERSION.$DATE_VERSION
  NAMESPACE=$DEFAULT_NAMESPACE
  IMAGE_NAME=$NAMESPACE/$DEFAULT_IMAGE_NAME
  REGISTRY=$DEFAULT_REGISTRY

  CUSTOM_APP_BRANCH=master
  CUSTOM_APP_REPO=""
  CUSTOM_APP_NAME=""


  ARGS=`getopt -o hr:n:i:t:v: -al help,registry:,namespace:,image:,tag:,version:,app-branch:,app-repo:,app-name: -- "$@"`
  if [ $? != 0 ];then
    echo "Terminating..."
    exit 1
  fi

  #重新排列参数顺序
  eval set -- "${ARGS}"
  #通过shift和while循环处理参数
  while :
  do
    case $1 in
      -t|--tag)
        TAG=$2
        shift 2
        ;;
      -r|--registry)
        REGISTRY=$2
        shift 2
        ;;
      -i|--image)
        IMAGE_NAME=$2
        shift 2
        ;;
      -n|--namespace)
        NAMESPACE=$2
        shift 2
        ;;
      -v|--version)
        MAIN_VERSION=$2
        shift 2
        ;;
      --app-branch)
        CUSTOM_APP_BRANCH=$2
        shift 2
        ;;
      --app-repo)
        CUSTOM_APP_REPO=$2
        shift 2
        ;;
      --app-name)
        CUSTOM_APP_NAME=$2
        shift 2
        ;;
      -h|--help)
        show_custom_usage
        exit 0
        ;;
      --)
        shift
        break
        ;;
      *)
        show_custom_usage
        exit 0
        ;;
  esac done

  IMAGE=${REGISTRY}/${IMAGE_NAME}:${TAG}
  echo "开始构建镜像：$IMAGE"

  docker build \
    --build-arg=DOCKER_REGISTRY=$REGISTRY \
    --build-arg=DOCKER_NAMESPACE=$NAMESPACE \
    --build-arg=MAIN_VERSION=$MAIN_VERSION \
    --build-arg=CUSTOM_APP_BRANCH=$CUSTOM_APP_BRANCH \
    --build-arg=CUSTOM_APP_REPO=$CUSTOM_APP_REPO \
    --build-arg=CUSTOM_APP_NAME=$CUSTOM_APP_NAME \
    --tag=$IMAGE \
    --file=Dockerfile.custom $CACHE_ARG .

  echo "构建完成"

  if [ $? -eq 0 ]; then
    docker push $IMAGE
    echo "推送完成"
  fi
}

function get_default() {
  echo -e "registry: $DEFAULT_REGISTRY
namespace: $DEFAULT_NAMESPACE
main_version: $DEFAULT_MAIN_VERSION
frappe_repo: $DEFAULT_FRAPPE_REPO
erpnext_repo: $DEFAULT_ERPNEXT_REPO
erpnext_chinese_repo: $DEFAULT_ERPNEXT_CHINESE_REPO
erpnext_oob_repo: $DEFAULT_ERPNEXT_OOB_REPO"
}

function set_default() {
  for var in $@
  do
    arr=(${var//=/ })
    case "${arr[0]}" in
      "registry")
      DEFAULT_REGISTRY=${arr[1]}
      ;;
      "namespace")
      DEFAULT_NAMESPACE=${arr[1]}
      ;;
      "main_version")
      DEFAULT_MAIN_VERSION=${arr[1]}
      ;;
      "frappe_repo")
      DEFAULT_FRAPPE_REPO=${arr[1]}
      ;;
      "erpnext_repo")
      DEFAULT_ERPNEXT_REPO=${arr[1]}
      ;;
      "erpnext_chinese_repo")
      DEFAULT_ERPNEXT_CHINESE_REPO=${arr[1]}
      ;;
      "erpnext_oob_repo")
      DEFAULT_ERPNEXT_OOB_REPO=${arr[1]}
      ;;
    esac
  done
  echo -e "DEFAULT_REGISTRY=$DEFAULT_REGISTRY
DEFAULT_NAMESPACE=$DEFAULT_NAMESPACE
DEFAULT_MAIN_VERSION=$DEFAULT_MAIN_VERSION
DEFAULT_FRAPPE_REPO=$DEFAULT_FRAPPE_REPO
DEFAULT_ERPNEXT_REPO=$DEFAULT_ERPNEXT_REPO
DEFAULT_ERPNEXT_CHINESE_REPO=$DEFAULT_ERPNEXT_CHINESE_REPO
DEFAULT_ERPNEXT_OOB_REPO=$DEFAULT_ERPNEXT_OOB_REPO" > .env
}

if [ -z $1 ]; then
  show_usage
  exit 0
fi

shift $((OPTIND -1))  # remove options
subcommand=$1; shift

case "$subcommand" in
  "help")
    show_usage
    exit 0
    ;;
  "base")
    build_base $@
    exit 0
    ;;
  "builder")
    build_builder $@
    exit 0
    ;;
  "builder-oob")
    build_builder_oob $@
    exit 0
    ;;
  "backend")
    build_backend $@
    exit 0
    ;;
  "custom")
    build_custom $@
    exit 0
    ;;
  "get-default")
    get_default $@
    exit 0
    ;;
  "set-default")
    set_default $@
    exit 0
    ;;
  *)
    show_usage
    exit 0
    ;;
esac
