#!/usr/bin/env bash

# 脚本报错即刻退出
set -e

DEFAULT_REGISTRY=ccr.ccs.tencentyun.com
DEFAULT_NAMESPACE=vnimy
DEFAULT_MAIN_VERSION=version-15
# 默认自定镜像主版本
DEFAULT_CUSTOM_MAIN_VERSION=version-15
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
      builder [选项]          构建Builder镜像
      erpnext [选项]          构建指定版本的ERPNext镜像，该镜像已包含ERRNext、
                              ERPNext Chinese、ERPNext OOB，可直接部署使用。
      custom [选项]           构建自定义APP镜像。在基于erpnext命令构建出来的镜像的
                              基础上添加自定义APP。
      [镜像] [-h | --help]    镜像构建帮助
      get-default             查看当前构建默认值
      set-default [选项]      设置构建默认值
                                使用方法：set-default param1=value1 param2=value2 ...
                                支持以下参数：
                                镜像注册中心          registry
                                镜像命名空间          namespace
                                主版本                main_version
                                自定义镜像主版本       custom_main_version
                                Frappe仓库            frappe_repo
                                ERPNext仓库           erpnext_repo
                                ERPNext Chinese仓库   erpnext_chinese_repo
                                ERPNext OOB仓库       erpnext_oob_repo";
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

function show_erpnext_usage() {
  echo -e "
    用法：
      erpnext [选项]
    
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

function show_custom_usage() {
  echo -e "
    用法：
      custom [选项]
    
    命令：
      -h,--help                         帮助
      -r,--registry [registry]          镜像注册中心，默认：$DEFAULT_REGISTRY
      -n,--namespace [namespace]        镜像注册中心的命名空间，默认：$DEFAULT_NAMESPACE
      -v,--version [version]            基础镜像版本，默认：$DEFAULT_CUSTOM_MAIN_VERSION
      -i,--image [name]                 镜像名称，不包含标签，默认：$DEFAULT_NAMESPACE/$DEFAULT_IMAGE_NAME
      -t,--tag [name]                   镜像标签，默认：$DEFAULT_CUSTOM_MAIN_VERSION.$(date '+%y%m%d')
      -f,--app-file [file]              自定义应用配置文件，一行一个APP，该配置优先于app-branch,app-repo,app-name参数
                                        例子 custom.txt：
                                            app-name1,app-repo1,app-branch1
                                            app-name2,app-repo2,app-branch2
         --app-branch [branch]          自定义应用分支名称，默认：master
         --app-repo [repo]              自定义应用仓库地址
         --app-name [name]              自定义应用名称";
}

function build_base() {
  NAMESPACE=$DEFAULT_NAMESPACE
  REGISTRY=$DEFAULT_REGISTRY

  ARGS=`getopt -o hr:n: -al help,registry:,namespace: -- "$@"`
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

  ARGS=`getopt -o hr:n: -al help,registry:,namespace: -- "$@"`
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

function build_erpnext() {
  NAMESPACE=$DEFAULT_NAMESPACE
  REGISTRY=$DEFAULT_REGISTRY
  CACHE_ARG=--no-cache

  MAIN_VERSION=$DEFAULT_MAIN_VERSION
  DATE_VERSION=$(date '+%y%m%d')
  TAG=$MAIN_VERSION.$DATE_VERSION

  FRAPPE_REPO=$DEFAULT_FRAPPE_REPO
  FRAPPE_BRANCH=${DEFAULT_FRAPPE_BRANCH:-$MAIN_VERSION}
  ERPNEXT_REPO=$DEFAULT_ERPNEXT_REPO
  ERPNEXT_BRANCH=${DEFAULT_ERPNEXT_BRANCH:-$MAIN_VERSION}
  ERPNEXT_CHINESE_REPO=$DEFAULT_ERPNEXT_CHINESE_REPO
  ERPNEXT_CHINESE_BRANCH=${DEFAULT_ERPNEXT_CHINESE_BRANCH:-"master"}
  ERPNEXT_OOB_REPO=$DEFAULT_ERPNEXT_OOB_REPO
  ERPNEXT_OOB_BRANCH=${DEFAULT_ERPNEXT_OOB_BRANCH:=$MAIN_VERSION}

  ARGS=`getopt -o hcr:n:v: -al help,cached,builder,registry:,namespace:,version:,frappe-repo:,erpnext-repo:,erpnext-chinese-repo:,erpnext-oob-repo: -- "$@"`
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
      --builder)
        BUILDER=1
        shift
        ;;
      -h|--help)
        show_erpnext_usage
        exit 0
        ;;
      --)
        shift
        break
        ;;
      *)
        show_erpnext_usage
        exit 0
        ;;
  esac done

  IMAGE=${REGISTRY}/${NAMESPACE}/erpnext:${TAG}

  echo "开始构建镜像：$IMAGE"

  docker build \
    --build-arg=DOCKER_REGISTRY=$REGISTRY \
    --build-arg=DOCKER_NAMESPACE=$NAMESPACE \
    --build-arg=FRAPPE_REPO=$FRAPPE_REPO \
    --build-arg=FRAPPE_BRANCH=$FRAPPE_BRANCH \
    --build-arg=ERPNEXT_REPO=$ERPNEXT_REPO \
    --build-arg=ERPNEXT_BRANCH=$ERPNEXT_BRANCH \
    --build-arg=ERPNEXT_CHINESE_REPO=$ERPNEXT_CHINESE_REPO \
    --build-arg=ERPNEXT_CHINESE_BRANCH=$ERPNEXT_CHINESE_BRANCH \
    --build-arg=ERPNEXT_OOB_REPO=$ERPNEXT_OOB_REPO \
    --build-arg=ERPNEXT_OOB_BRANCH=$ERPNEXT_OOB_BRANCH \
    --tag=$IMAGE \
    --file=Dockerfile $CACHE_ARG .

  echo "构建完成 $IMAGE"

  if [ $? -eq 0 ]; then
    docker push $IMAGE
    echo "推送完成 $IMAGE"
  fi
}

function build_custom() {
  MAIN_VERSION=$DEFAULT_CUSTOM_MAIN_VERSION
  # 这里可以将版本定到分钟级，有助于在频繁推送并用Helm更新时候可以正常拉去最新镜像
  DATE_VERSION=$(date '+%y%m%d%H%M')
  TAG=$MAIN_VERSION.$DATE_VERSION
  NAMESPACE=$DEFAULT_NAMESPACE
  IMAGE_NAME=$NAMESPACE/$DEFAULT_IMAGE_NAME
  REGISTRY=$DEFAULT_REGISTRY

  CUSTOM_APP_BRANCH=master
  CUSTOM_APP_REPO=""
  CUSTOM_APP_NAME=""
  CUSTOM_APPS=""


  ARGS=`getopt -o hr:n:i:t:v:f: -al help,registry:,namespace:,image:,tag:,version:,app-branch:,app-repo:,app-name:,app-file: -- "$@"`
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
      -f|--app-file)
        if [ -e $2 ]; then
          CUSTOM_APPS=$(cat $2)
        fi
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

  if [ ! -n "${CUSTOM_APPS}" ]; then
    if [ -n "${CUSTOM_APP_REPO}" ]; then
      CUSTOM_APPS="${CUSTOM_APP_NAME},${CUSTOM_APP_REPO},${CUSTOM_APP_BRANCH:-"master"}"
    elif [ -e "custom.txt" ]; then
      CUSTOM_APPS=$(cat "custom.txt" | grep -v "#")
    fi
  fi

  IMAGE=${REGISTRY}/${IMAGE_NAME}:${TAG}
  echo "开始构建镜像：$IMAGE"
  docker build \
    --build-arg=DOCKER_REGISTRY=$REGISTRY \
    --build-arg=DOCKER_NAMESPACE=$NAMESPACE \
    --build-arg=MAIN_VERSION=$MAIN_VERSION \
    --build-arg=CUSTOM_APPS="$CUSTOM_APPS" \
    --tag=$IMAGE \
    --file=Dockerfile.custom --no-cache .

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
custom_main_version: $DEFAULT_CUSTOM_MAIN_VERSION
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
      "custom_main_version")
      DEFAULT_CUSTOM_MAIN_VERSION=${arr[1]}
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
DEFAULT_CUSTOM_MAIN_VERSION=$DEFAULT_CUSTOM_MAIN_VERSION
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
  "erpnext")
    build_erpnext $@
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
