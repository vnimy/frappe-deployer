#!/usr/bin/env bash

# 脚本报错即刻退出
set -e

IMAGE=""
VERSION=""
STACK_NAME=erp
DEPLOY_REPLICAS=3
FRONTEND_PORT=8080

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
      version                 查看当前镜像版本
      ps                      查看任务列表
      services                查看服务列表
      init                    初始化全局配置
      start                   启动服务
      restart                 重启服务
      down                    关闭服务
      update [版本]           更新到指定版本，如不指定版本则使用当前版本进行更新服务
      migrate [站点域名]      合并指定站点
      scale [实例数]          将backend、frontend、websocket服务的实例调整到指定数量
      port                    设置前端端口号，默认：8080
      port [端口]             设置前端端口号
      attach                  进入backend容器终端";
}

function update() {
  if [ -n "$1" ]; then
    sed -i "s/VERSION=$VERSION/VERSION=$1/g" .env
    VERSION=$1
    docker pull $IMAGE:$VERSION
  fi
  run
}

function scale() {
  if [ -n "$1" ]; then
    sed -i "s/DEPLOY_REPLICAS=$DEPLOY_REPLICAS/DEPLOY_REPLICAS=$1/g" .env
    DEPLOY_REPLICAS=$1
    docker service scale \
      ${STACK_NAME}_backend=$DEPLOY_REPLICAS \
      ${STACK_NAME}_frontend=$DEPLOY_REPLICAS \
      ${STACK_NAME}_websocket=$DEPLOY_REPLICAS
  fi
}

function port() {
  if [ -n "$1" ]; then
    sed -i "s/FRONTEND_PORT=$FRONTEND_PORT/FRONTEND_PORT=$1/g" .env
    FRONTEND_PORT=$1
  else
    echo $FRONTEND_PORT
  fi
}

function migrate() {
  backend_id_in_stack=$(docker stack ps $STACK_NAME | grep backend | head -n 1 | awk '{print $1}')
  backend_id=$(docker ps | grep $backend_id_in_stack | awk '{print $1}')
  docker exec $backend_id bench --site $1 migrate
}

function attach() {
  backend_id_in_stack=$(docker stack ps $STACK_NAME | grep backend | head -n 1 | awk '{print $1}')
  backend_id=$(docker ps | grep $backend_id_in_stack | awk '{print $1}')
  docker exec -it $backend_id /bin/bash
}

function run() {
  docker stack deploy -c stack.yaml $STACK_NAME
}

function down() {
  docker stack rm $STACK_NAME
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
  "version")
    echo $VERSION
    exit 0
    ;;
  "ps")
    docker stack ps $STACK_NAME
    exit 0
    ;;
  "services")
    docker stack services $STACK_NAME
    exit 0
    ;;
  "init")
    docker-compose -f init.yml up
    exit 0
    ;;
  "start")
    run $@
    exit 0
    ;;
  "restart")
    run $@
    exit 0
    ;;
  "down")
    down $@
    exit 0
    ;;
  "update")
    update $@
    exit 0
    ;;
  "migrate")
    migrate $@
    exit 0
    ;;
  "scale")
    scale $@
    exit 0
    ;;
  "attach")
    attach $@
    exit 0
    ;;
  "port")
    port $@
    exit 0
    ;;
  *)
    show_usage
    exit 0
    ;;
esac
