#!/usr/bin/env bash

# 脚本报错即刻退出
set -e

function show_usage() {
  echo -e "
    用法：
      <命令> [选项]
    
    命令：
      help              帮助
      base              打包基础镜像
      builder           打包builder镜像
      backend [选项]    打包后端镜像";
}

function show_backend_usage() {
  echo -e "
    用法：
      backend [options]
    
    命令：
      -h,--help                         帮助
      -f,--apps_file [path]             apps json文件路径，默认：apps.json
      -r,--registry [registry]          镜像注册中心，默认：ccr.ccs.tencentyun.com
      -i,--image [name]                 镜像名称，不包含标签，默认：vnimy/erp
      -t,--tag [name]                   镜像标签，默认：version-15.$(date '+%y%m%d')";
}

function build_backend() {
  MAIN_VERSION=version-15
  DATE_VERSION=$(date '+%y%m%d')
  TAG=$MAIN_VERSION.$DATE_VERSION
  IMAGE_NAME=vnimy/erp
  REGISTRY=ccr.ccs.tencentyun.com
  APPS_FILE=apps.json
  CACHE_ARG=--no-cache

  ARGS=`getopt -o hcf:r:i:t:v: -al help,cached,apps_file:,registry:,image:,tag:,version: -- "$@"`
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
  echo "开始打包镜像：$IMAGE"

  docker build \
    --build-arg=FRAPPE_PATH=https://gitee.com/mirrors/frappe.git \
    --build-arg=FRAPPE_BRANCH=$MAIN_VERSION \
    --build-arg=APPS_JSON_BASE64=$(base64 -w 0 ${APPS_FILE}) \
    --tag=$IMAGE $CACHE_ARG .

  echo "打包完成"

  if [ $? -eq 0 ]; then
    docker push $IMAGE
    echo "推送完成"
  fi
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
    IMAGE=ccr.ccs.tencentyun.com/vnimy/frappe-base:latest
    docker build --tag=$IMAGE --file=Dockerfile.base .
    docker push $IMAGE
    exit 0
    ;;
  "builder")
    IMAGE=ccr.ccs.tencentyun.com/vnimy/frappe-builder:latest
    docker build --tag=$IMAGE --file=Dockerfile.builder .
    docker push $IMAGE
    exit 0
    ;;
  "backend")
    build_backend $@
    exit 0
    ;;
  *)
    show_usage
    exit 0
    ;;
esac
