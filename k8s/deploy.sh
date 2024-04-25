#!/usr/bin/env bash

# 脚本报错即刻退出
set -e

# Chart包版本
CHART_VERSION=""
# 命名空间
NAMESPACE=""
# 站点名称
SITE="site1.example.com"

# 路由名称
INGRESS_NAME="site1-ingress"
# 路由SSL证书保密字典
INGRESS_TLS_SECRET_NAME="site1-ssl"
# 管理员密码
ADMIN_PASSWORD="admin"
# 安装的应用
INSTALL_APPS=erpnext,erpnext_chinese,erpnext_oob

# 数据库设置
DB_HOST="mariadb.development"
DB_PORT=3306
DB_ROOT_USER="root"
DB_ROOT_PASSWORD="root"

# 镜像仓库的保密字典
IMAGE_PULL_SECRET_NAME="tx-registry"

# 镜像
IMAGE_REPOSITORY="vnimy/erp"
IMAGE_TAG="version-14.240222.2404061753"

# 持久化数据设置
PERSISTENCE_STORAGE_CLASS="nfs-client"

if [[ ! -f .env && -f .env.sample ]]; then
  cp .env.sample .env
fi

set -a # automatically export all variables
if [ -f .env ]; then
  source .env
fi
set +a

SET_VALUES_ARGS=""

function show_usage() {
  echo -e "
    用法：
      <命令> [选项]
    
    命令：
      help                    帮助
      install [选项]          安装，可用参数-n|-v|-t
      uninstall [选项]        卸载，可用参数-n
      new-site [选项]         新建站点，可用参数-n|-v|-s|-t
      create-ingress [选项]   创建路由，可用参数-n|-v|-s|-t|--ingress
      migrate [选项]          合并，可用参数-n|-v|-s|-t
      get-default             查看部署默认值
      set-default [选项]      设置部署默认值
                                使用方法：set-default param1=value1 param2=value2 ...
                                支持以下参数：
                                命名空间              namespace
                                Chart版本             chart_version
                                站点名称              site
                                镜像版本              image_tag
                                路由名称              ingress_name
                                路由TLS保密字典名称   ingress_tls_secret_name
                                管理员密码            admin_password
    参数：
      -n|--namespace        命名空间
      -v|--chart_version    Chart版本
      -s|--site             站点名称
      -t|--tag              镜像版本
         --install_apps     安装的应用，多个应用用英文逗号分隔，用于新建站点
         --admin_password   管理员密码，用于新建站点
         --ingress_name     路由名称，用于创建路由
         --ingress_tls      路由TLS保密字典名称，用于创建路由";
}

function get_params() {
  ARGS=`getopt -o hv:n:s:t: -al help,chart_version:,namespace:,site:,tag:,ingress_name:,ingress_tls:,admin_password:,install_apps: -- "$@"`
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
      -t|--tag)
        IMAGE_TAG=$2
        shift 2
        ;;
      --ingress_name)
        INGRESS_NAME=$2
        shift 2
        ;;
      --ingress_tls)
        INGRESS_TLS_SECRET_NAME=$2
        shift 2
        ;;
      --install_apps)
        INSTALL_APPS=$2
        shift 2
        ;;
      --admin_password)
        ADMIN_PASSWORD=$2
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
  
  if [ -n $DB_HOST ]; then
    SET_VALUES_ARGS="$SET_VALUES_ARGS --set dbHost=$DB_HOST"
  fi
  if [ -n $DB_PORT ]; then
    SET_VALUES_ARGS="$SET_VALUES_ARGS --set dbPort=$DB_PORT"
  fi
  if [ -n $DB_ROOT_USER ]; then
    SET_VALUES_ARGS="$SET_VALUES_ARGS --set dbRootUser=$DB_ROOT_USER"
  fi
  if [ -n $DB_ROOT_PASSWORD ]; then
    SET_VALUES_ARGS="$SET_VALUES_ARGS --set dbRootPassword=$DB_ROOT_PASSWORD"
  fi
  if [ -n $IMAGE_PULL_SECRET_NAME ]; then
    SET_VALUES_ARGS="$SET_VALUES_ARGS --set imagePullSecrets[0].name=$IMAGE_PULL_SECRET_NAME"
  fi
  if [ -n $IMAGE_REPOSITORY ]; then
    SET_VALUES_ARGS="$SET_VALUES_ARGS --set image.repository=$IMAGE_REPOSITORY"
  fi
  if [ -n $IMAGE_TAG ]; then
    SET_VALUES_ARGS="$SET_VALUES_ARGS --set image.tag=$IMAGE_TAG"
  fi
  if [ -n $PERSISTENCE_STORAGE_CLASS ]; then
    SET_VALUES_ARGS="$SET_VALUES_ARGS --set persistence.worker.storageClass=$PERSISTENCE_STORAGE_CLASS"
  fi

  if [[ -n $CHART_VERSION && ! -e ./erpnext-$CHART_VERSION.tgz ]]; then
    download_chart
  fi
}

function template() {
  template_new_site
  template_migrate
  template_ingress
}

function install() {
  check_namespace
  check_chart_version

  SET_ARGS="$SET_VALUES_ARGS"
  helm upgrade --install -n $NAMESPACE erpnext erpnext-$CHART_VERSION.tgz -f custom-values.yaml $SET_ARGS
}

function uninstall() {
  check_namespace

  helm uninstall -n $NAMESPACE erpnext
}

function template_new_site() {
  check_namespace
  check_chart_version

  if [ ! -d "./dist" ]; then
    mkdir ./dist
  fi

  SET_ARGS="template erpnext -n $NAMESPACE ./erpnext-$CHART_VERSION.tgz -f ./custom-values.yaml"
  SET_ARGS="$SET_ARGS -s templates/job-create-site.yaml -f templates/job-create-site.yaml"
  if [ -n $SITE ]; then
    SET_ARGS="$SET_ARGS --set jobs.createSite.siteName=$SITE"
  fi
  if [ -n $ADMIN_PASSWORD ]; then
    SET_ARGS="$SET_ARGS --set jobs.createSite.adminPassword=$ADMIN_PASSWORD"
  fi
  if [ -n $INSTALL_APPS ]; then
    SET_ARGS="$SET_ARGS --set jobs.createSite.installApps={$INSTALL_APPS}"
  fi
  SET_ARGS="$SET_ARGS $SET_VALUES_ARGS"
  helm $SET_ARGS > dist/job-create-site.yaml
}

function template_migrate() {
  check_namespace
  check_chart_version

  if [ ! -d "./dist" ]; then
    mkdir ./dist
  fi

  SET_ARGS="template erpnext -n $NAMESPACE ./erpnext-$CHART_VERSION.tgz -f ./custom-values.yaml"
  SET_ARGS="$SET_ARGS -s templates/job-migrate-site.yaml -f templates/job-migrate-site.yaml"
  if [ -n $SITE ]; then
    SET_ARGS="$SET_ARGS --set jobs.migrate.siteName=$SITE"
  fi
  SET_ARGS="$SET_ARGS $SET_VALUES_ARGS"
  helm $SET_ARGS > dist/job-migrate-site.yaml
}

function template_ingress() {
  check_namespace
  check_chart_version

  if [ ! -d "./dist" ]; then
    mkdir ./dist
  fi

  SET_ARGS="template erpnext -n $NAMESPACE ./erpnext-$CHART_VERSION.tgz -f ./custom-values.yaml"
  SET_ARGS="$SET_ARGS -s templates/ingress.yaml -f templates/ingress.yaml"
  if [ -n $IMAGE_TAG ]; then
    SET_ARGS="$SET_ARGS --set image.tag=$IMAGE_TAG"
  fi
  if [ -n $SITE ]; then
    SET_ARGS="$SET_ARGS --set ingress.hosts[0].host=$SITE --set ingress.tls[0].hosts[0]=$SITE"
  fi
  if [ -n $INGRESS_NAME ]; then
    SET_ARGS="$SET_ARGS --set ingress.ingressName=$INGRESS_NAME"
  fi
  if [ -n $INGRESS_TLS_SECRET_NAME ]; then
    SET_ARGS="$SET_ARGS --set ingress.tls[0].secretName=$INGRESS_TLS_SECRET_NAME"
  fi
  SET_ARGS="$SET_ARGS $SET_VALUES_ARGS"
  helm $SET_ARGS > dist/ingress.yaml
}

function new_site() {
  template_new_site
  kubectl -n $NAMESPACE apply -f ./dist/job-create-site.yaml
}

function migrate() {
  template_migrate
  kubectl -n $NAMESPACE apply -f ./dist/job-migrate-site.yaml
}

function create_ingress() {
  template_ingress
  kubectl -n $NAMESPACE apply -f ./dist/ingress.yaml
}

function download_chart() {
  echo "正在下载Chart包..."
  wget https://helm.erpnext.com/erpnext-$CHART_VERSION.tgz
  echo "Chart包下载完成"
}

function check_site() {
  if [ -z $SITE ]; then
    echo "请指定站点名称(-s|--site)，或设置默认站点名称(set-default site=xxx)"
  fi
}

function check_namespace() {
  if [ -z $NAMESPACE ]; then
    echo "请指定命名空间(-n|--namespace)，或设置默认命名空间(set-default namespace=xxx)"
  fi
}

function check_chart_version() {
  if [ -z $CHART_VERSION ]; then
    echo "请指定Chart包版本(-v|--chart_version)，或设置默认Chart包版本(set-default chart_version=xxx)"
  fi
}

function check_image_tag() {
  if [ -z $IMAGE_TAG ]; then
    echo "请指定镜像版本(-t|--tag)，或设置默认镜像版本(set-default image_tag=xxx)"
  fi
}


function get_default() {
  echo -e "namespace: $NAMESPACE
chart_version: $CHART_VERSION
site: $SITE
image_tag: $IMAGE_TAG
ingress_name: $INGRESS_NAME
ingress_tls_secret_name: $INGRESS_TLS_SECRET_NAME
admin_password: $ADMIN_PASSWORD"
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
      "image_tag")
      IMAGE_TAG=${arr[1]}
      ;;
    esac
  done
  echo -e "# Chart包版本
CHART_VERSION=$CHART_VERSION
# 命名空间
NAMESPACE=$NAMESPACE
# 站点名称
SITE=$SITE

# 安装的应用
INSTALL_APPS=erpnext,erpnext_chinese,erpnext_oob
# 管理员密码
ADMIN_PASSWORD=$ADMIN_PASSWORD

# 路由名称
INGRESS_NAME=$INGRESS_NAME
# 路由SSL证书保密字典
INGRESS_TLS_SECRET_NAME=$INGRESS_TLS_SECRET_NAME

# 数据库设置
DB_HOST=$DB_HOST
DB_PORT=$DB_PORT
DB_ROOT_USER=$DB_ROOT_USER
DB_ROOT_PASSWORD=$DB_ROOT_PASSWORD

# 镜像仓库的保密字典
IMAGE_PULL_SECRET_NAME=$IMAGE_PULL_SECRET_NAME

# 镜像
IMAGE_REPOSITORY=$IMAGE_REPOSITORY
IMAGE_TAG=$IMAGE_TAG

# 持久化数据设置
PERSISTENCE_STORAGE_CLASS=$PERSISTENCE_STORAGE_CLASS" > .env
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
  "template")
    get_params $@
    template $@
    exit 0
    ;;
  *)
    show_usage
    exit 0
    ;;
esac
