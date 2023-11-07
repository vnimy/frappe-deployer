#!/usr/bin/env bash

# 脚本报错即刻退出
set -e

DEFAULT_REGISTRY=ccr.ccs.tencentyun.com
DEFAULT_NAMESPACE=vnimy
DEFAULT_FRAPPE_VERSION=version-14
DEFAULT_FRAPPE_PATH=https://gitee.com/mirrors/frappe.git

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
      base                    构建基础镜像
      builder                 构建builder镜像
      backend [选项]          构建后端镜像
      backend [-h | --help]   后端镜像构建帮助
      get-default             查看当前构建默认值
      set-default             设置构建默认值
                                使用方法：set-default param1=value1 param2=value2 ...
                                支持以下参数：
                                镜像注册中心  registry
                                镜像命名空间  namespace
                                Frappe版本    frappe_version
                                Frappe仓库    frappe_path";
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
      -v,--version [version]            Frappe框架版本，默认：$DEFAULT_FRAPPE_VERSION
      -i,--image [name]                 镜像名称，不包含标签，默认：{命名空间}/erp
      -t,--tag [name]                   镜像标签，默认：{Frappe框架版本}.$(date '+%y%m%d')
         --frappe-path [repo]           Frappe框架仓库地址，默认：https://gitee.com/mirrors/frappe.git
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

  docker build --tag=$IMAGE --file=Dockerfile.base .
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

  docker build --tag=$IMAGE --file=Dockerfile.builder .
  docker push $IMAGE

  echo "构建完成"

  if [ $? -eq 0 ]; then
    docker push $IMAGE
    echo "推送完成"
  fi
}

function build_backend() {
  MAIN_VERSION=$DEFAULT_FRAPPE_VERSION
  DATE_VERSION=$(date '+%y%m%d')
  TAG=$MAIN_VERSION.$DATE_VERSION
  NAMESPACE=$DEFAULT_NAMESPACE
  IMAGE_NAME=$NAMESPACE/erp
  REGISTRY=$DEFAULT_REGISTRY
  APPS_FILE=apps.json
  CACHE_ARG=--no-cache
  FRAPPE_PATH=$DEFAULT_FRAPPE_PATH

  ARGS=`getopt -o hcf:r:n:i:t:v: -al help,cached,apps_file:,registry:,namespace:,image:,tag:,version: -- "$@"`
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
      --frappe-path)
        FRAPPE_PATH=$2
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
    --build-arg=FRAPPE_PATH=$FRAPPE_PATH \
    --build-arg=FRAPPE_BRANCH=$MAIN_VERSION \
    --build-arg=APPS_JSON_BASE64=$(base64 -w 0 ${APPS_FILE}) \
    --tag=$IMAGE $CACHE_ARG .

  echo "构建完成"

  if [ $? -eq 0 ]; then
    docker push $IMAGE
    echo "推送完成"
  fi
}

function get_default() {
  echo -e "registry: $DEFAULT_REGISTRY
namespace: $DEFAULT_NAMESPACE
frappe_version: $DEFAULT_FRAPPE_VERSION
frappe_path: $DEFAULT_FRAPPE_PATH"
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
      "frappe_version")
      DEFAULT_FRAPPE_VERSION=${arr[1]}
      ;;
      "frappe_path")
      DEFAULT_FRAPPE_PATH=${arr[1]}
      ;;
    esac
  done
  echo -e "DEFAULT_REGISTRY=$DEFAULT_REGISTRY
DEFAULT_NAMESPACE=$DEFAULT_NAMESPACE
DEFAULT_FRAPPE_VERSION=$DEFAULT_FRAPPE_VERSION
DEFAULT_FRAPPE_PATH=$DEFAULT_FRAPPE_PATH" > .env
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
  "backend")
    build_backend $@
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
