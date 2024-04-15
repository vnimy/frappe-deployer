#!/usr/bin/env bash

# 脚本报错即刻退出
set -e

CHART_VERSION=""
NAMESPACE=""
SITE=""

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
      install [选项]          安装
          -n|--namespace        命名空间
          -v|--chart_version    Chart版本
      uninstall [选项]        卸载
          -n|--namespace        命名空间
      new-site [选项]         新建站点
          -n|--namespace        命名空间
          -s|--site             站点名称
      create-ingress [选项]   创建路由
          -n|--namespace        命名空间
          -s|--site             站点名称
      migrate [选项]          合并
          -n|--namespace        命名空间
          -s|--site             站点名称
      get-default             查看部署默认值
      set-default [选项]      设置部署默认值
                                使用方法：set-default param1=value1 param2=value2 ...
                                支持以下参数：
                                命名空间              namespace
                                Chart版本             chart_version
                                站点名称              site";
}

function get_params() {
  ARGS=`getopt -o hv:n:s: -al help,chart_version:,namespace:site: -- "$@"`
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
      -v|--chart_version)
        CHART_VERSION=$2
        shift 2
        ;;
      -n|--namespace)
        NAMESPACE=$2
        shift 2
        ;;
      -s|--site)
        SITE=$2
        shift 2
        ;;
      -h|--help)
        show_usage
        exit 0
        ;;
      --)
        shift
        break
        ;;
      *)
        show_usage
        exit 0
        ;;
  esac done

  if [[ -n $CHART_VERSION && ! -e ./erpnext-$CHART_VERSION.tgz ]]; then
    download_chart
  fi
}

function template() {
  helm template erpnext -n $NAMESPACE ./erpnext-$CHART_VERSION.tgz -f ./custom-values.yaml -f $SITE/tpl-new-site.yaml -s templates/job-create-site.yaml > $SITE/job-create-site.yaml
  helm template erpnext -n $NAMESPACE ./erpnext-$CHART_VERSION.tgz -f ./custom-values.yaml -f $SITE/tpl-migrate.yaml -s templates/job-migrate-site.yaml > $SITE/job-migrate-site.yaml
  helm template erpnext -n $NAMESPACE ./erpnext-$CHART_VERSION.tgz -f ./custom-values.yaml -f $SITE/tpl-ingress.yaml -s templates/ingress.yaml > $SITE/ingress.yaml
}

function install() {
  helm upgrade --install -n $NAMESPACE erpnext erpnext-$CHART_VERSION.tgz -f custom-values.yaml
}

function uninstall() {
  helm uninstall -n $NAMESPACE erpnext
}

function new_site() {
  template
  kubectl -n $NAMESPACE apply -f ./$SITE/job-create-site.yaml
}

function migrate() {
  template
  kubectl -n $NAMESPACE apply -f ./$SITE/job-migrate-site.yaml
}

function create_ingress() {
  template
  kubectl -n $NAMESPACE apply -f ./$SITE/ingress.yaml
}

function download_chart() {
  echo "正在下载Chart包..."
  wget https://helm.erpnext.com/erpnext-$CHART_VERSION.tgz
  echo "Chart包下载完成"
}


function get_default() {
  echo -e "namespace: $NAMESPACE
chart_version: $CHART_VERSION
site: $SITE"
}

function set_default() {
  for var in $@
  do
    arr=(${var//=/ })
    case "${arr[0]}" in
      "namespace")
      NAMESPACE=${arr[1]}
      ;;
      "chart_version")
      CHART_VERSION=${arr[1]}
      ;;
      "site")
      SITE=${arr[1]}
      ;;
    esac
  done
  echo -e "NAMESPACE=$NAMESPACE
CHART_VERSION=$CHART_VERSION
SITE=$SITE" > .env
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
  "install")
    get_params $@
    install $@
    exit 0
    ;;
  "uninstall")
    get_params $@
    uninstall $@
    exit 0
    ;;
  "new-site")
    get_params $@
    new_site $@
    exit 0
    ;;
  "create-ingress")
    get_params $@
    create_ingress $@
    exit 0
    ;;
  "migrate")
    get_params $@
    migrate $@
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
