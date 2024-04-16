- [部署说明](#部署说明)
  - [环境要求](#环境要求)
    - [安装Docker](#安装docker)
    - [安装docker-compose](#安装docker-compose)
  - [构建](#构建)
    - [了解`build.sh`的命令](#了解buildsh的命令)
      - [设置构建默认值](#设置构建默认值)
    - [构建基础镜像](#构建基础镜像)
      - [相关命令](#相关命令)
    - [构建生产镜像(非固定版本)](#构建生产镜像非固定版本)
    - [构建生产镜像(固定版本)](#构建生产镜像固定版本)
  - [部署](#部署)
    - [Docker Compose 单机部署](#docker-compose-单机部署)
      - [准备部署目录](#准备部署目录)
      - [启动ERP服务](#启动erp服务)
      - [新建站点](#新建站点)
      - [更新服务](#更新服务)
    - [Docker Swarm 集群部署](#docker-swarm-集群部署)
      - [要求](#要求)
      - [配置Docker Swarm](#配置docker-swarm)
      - [准备部署目录](#准备部署目录-1)
      - [配置NFS服务器](#配置nfs服务器)
      - [了解`deploy.sh`命令](#了解deploysh命令)
      - [初始化全局配置](#初始化全局配置)
      - [启动ERP集群](#启动erp集群)
      - [新建站点](#新建站点-1)
      - [更新服务](#更新服务-1)
    - [K8s Helm 部署](#k8s-helm-部署)
      - [准备](#准备)
      - [部署](#部署-1)
    - [其他](#其他)
      - [使用外部数据库（适用于Docker Compose 和 Docker Swarm）](#使用外部数据库适用于docker-compose-和-docker-swarm)
  - [特别感谢](#特别感谢)
  - [相关链接](#相关链接)


# 部署说明

## 环境要求

- Docker
- docker-compose

### 安装Docker

1. 使用官方安装脚本自动安装
    ```shell
      curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun
    ```

2. 启动Docker
    ```shell
    systemctl start docker
    ```

### 安装docker-compose
1. 下载及安装Compose
    ```shell
    curl -SL https://github.com/docker/compose/releases/download/v2.23.0/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose
    ```

2. 给docker-compose设置可执行权限
    ```shell
    chmod +x /usr/local/bin/docker-compose
    ```

3. 执行`docker-compose`命令是否有相关输出
    > **注意**
    >
    > 如果`docker-compose`命令无效，请检查docker-compose的路径。您也可以创建一个软连接到`/usr/bin`。如：
    >
    > ```shell
    > sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
    > ```

## 构建

### 了解`build.sh`的命令

> `root@server:~# ./build.sh help`
>
>     用法：
>       <命令> [选项]
>     
>     命令：
>       help                    帮助
>       base [选项]             构建基础镜像
>       builder [选项]          构建builder镜像
>       backend [选项]          构建后端镜像。该命令将基于最新的代码进行构建镜像，该操作将
>                               无法固定Frappe、ERPNext的版本。
>       builder-oob [选项]      构建builder-oob镜像。该命令用于构建指定版本的基础镜像，并
>                               用于后续基于该镜像快速构建自定义镜像，该操作可固定Frappe、
>                               ERPNext的版本。
>       custom [选项]           构建自定义APP镜像。在基于builder-oob命令构建出来的镜像的
>                               基础上添加自定以APP。
>       [镜像] [-h | --help]    镜像构建帮助
>       get-default             查看当前构建默认值
>       set-default [选项]      设置构建默认值
>                                 使用方法：set-default param1=value1 param2=value2 ...
>                                 支持以下参数：
>                                 镜像注册中心          registry
>                                 镜像命名空间          namespace
>                                 主版本                main_version
>                                 自定义镜像主版本       custom_main_version
>                                 Frappe仓库            frappe_repo
>                                 ERPNext仓库           erpnext_repo
>                                 ERPNext Chinese仓库   erpnext_chinese_repo
>                                 ERPNext OOB仓库       erpnext_oob_repo

#### 设置构建默认值
构建镜像时基于几个默认变量来确定镜像名称，要推送到的注册中心，frappe框架版本等，默认值如下：

| 参数名称       | 参数           | 默认值                               |
| -------------- | -------------- | ------------------------------------ |
| 镜像注册中心   | registry       | ccr.ccs.tencentyun.com               |
| 镜像命名空间   | namespace      | vnimy                                |
| 主版本 | main_version | version-15                           |
| 自定义镜像主版本 | custom_main_version | version-15                           |
| Frappe仓库地址 | frappe_repo    | https://gitee.com/mirrors/frappe.git |
| ERPNext仓库地址 | erpnext_repo    | https://gitee.com/mirrors/erpnext.git |
| ERPNext汉化仓库地址 | erpnext_chinese_repo    | https://gitee.com/yuzelin/erpnext_chinese.git |
| ERPNext开箱即用仓库地址 | erpnext_oob_repo    | https://gitee.com/yuzelin/erpnext_oob.git |

1. 设置默认值
    ```shell
    ./build.sh set-default \
      registry=ccr.ccs.tencentyun.com \
      namespace=vnimy \
      main_version=version-15 \
      frappe_repo=https://gitee.com/mirrors/frappe.git
    ```

2. 查看默认值
    ```shell
    ./build.sh get-default
    ```

3. 构建镜像前请确保已经登陆镜像注册中心，否则会导致推送镜像失败
  
    **使用以下命令登录镜像中心：**
    ```shell
    docker login -u {用户名} -p {密码} {注册中心}
    ```

### 构建基础镜像

在构建ERP镜像之前需要有`frappe-base`和`frappe-builder`两个基础镜像支撑
- `frappe-base`：为ERP的运行环境镜像，提供`Python`、`Nodejs`、`Bench`等支持，同时也是`frappe-builder`的基础镜像。
- `frappe-builder`：为构建ERP时初始化`frappe`框架及安装应用时提供环境支持。
- `frappe-base`和`frappe-builder`只需要构建一次即可，可供构建ERP镜像时重复使用。

#### 相关命令

1. 构建并推送`frappe-base`镜像
    ```shell
    ./build.sh base
    ```

2. 构建并推送`frappe-builder`镜像
    ```shell
    ./build.sh builder
    ```

### 构建生产镜像(非固定版本)

1. 配置`apps.json`
   
   `apps.json`文件用于构建生产镜像时安装指定的应用，您可以根据自己的需求增加应用

   **注意：** 请确认应用的版本分支，一般情况下应该与Frappe框架的版本一致。
   ```json
    [
      {
        "url": "https://gitee.com/mirrors/erpnext.git",
        "branch": "version-15"
      },
      {
        "url": "https://gitee.com/yuzelin/erpnext_chinese.git",
        "branch": "master"
      },
      {
        "url": "https://gitee.com/yuzelin/erpnext_oob.git",
        "branch": "version-15"
      }
    ]
   ```

2. 构建并推送生产镜像
    ```shell
    ./build.sh backend
    ```
    > 该命令会产生镜像`{$registry}/{$namespace}/erp:{$main_version}.{$(date '+%y%m%d')}`，镜像版本由Frappe框架版本及构建日期组成，如：`ccr.ccs.tencentyun.com/vnimy/erp:version-15.231106`。

### 构建生产镜像(固定版本)

1. 设置默认值
   由于基础镜像包含Frappe、ERPNext、ERPNext Chinese、ERPNext OOB等应用，因此需要提前设置好这些应用的仓库地址以及版本信息
    ```shell
    ./build.sh set-default \
      registry=ccr.ccs.tencentyun.com \
      namespace=vnimy \
      main_version=version-15 \
      frappe_repo=https://gitee.com/mirrors/frappe.git
      erpnext_repo=https://gitee.com/mirrors/erpnext.git
      erpnext_chinese_repo=https://gitee.com/yuzelin/erpnext_chinese.git
      erpnext_oob_repo=https://gitee.com/yuzelin/erpnext_oob.git
    ```

2. 构建自定义镜像基础镜像
    ```shell
    ./build.sh builder-oob
    ```

    > 该命令构建并推送镜像`{$registry}/{$namespace}/frappe-builder-oob:{$main_version}.{$(date '+%y%m%d')}`
    如：ccr.ccs.tencentyun.com/vnimy/frappe-builder-oob:version-15.231106

3. 准备构建配置
    在项目目录中创建文件`custom.txt`，并确保有以下内容
    ```
    app-name-1,app-repo-1,app-branch
    app-name-2,app-repo-2,app-branch
    app-name-3,app-repo-3,app-branch
    ```

    
    > **如何在构建时不需要密码和SSH Key拉取私有仓库APP？**
      创建一个访问令牌，在仓库URL中使用令牌来拉取。如：`https://x-access-token:your-token@github.com/your-username/your-repo.git`，具体令牌创建及访问方式视Git托管平台而定。

    设置默认基础镜像版本：
    **注意：** 版本为上一步构建的版本，如果不需要基于更新的基础版本，可以不更改改默认值
    ```shell
    ./build.sh set-default custom_main_version=version-15.231106
    ```

4. 构建自定义APP镜像
    执行构建命令：
    ```shell
    ./build.sh custom
    ```
    > 该命令会产生镜像`{$registry}/{$namespace}/erp:{$custom_main_version}.{$(date '+%y%m%d')}`，镜像版本由自定义镜像主版本及构建日期组成，如：`ccr.ccs.tencentyun.com/vnimy/erp:version-15.231106.231213`。

## 部署

### Docker Compose 单机部署

#### 准备部署目录

设置一个目录作为ERP的部署目录，如：`~/docker/erp`，后面用`{部署目录}`代替。

1. 创建部署目录
   ```shell
   mkdir -p ~/docker
   cp -r deploy/compose ~/docker/erp
   cd ~/docker/erp
   ```

2. 配置环境变量
   ```shell
   cp .env.sample .env
   ```

   修改`.env`文件，设置ERP的`镜像名称(IMAGE)`、`镜像版本(VERSION)`、`访问端口(FRONTEND_PORT)`环境变量

#### 启动ERP服务

```shell
docker-compose up -d -V
```

#### 新建站点

1. 新建站点
    ```shell
    docker-compose exec backend \
      bench new-site {站点域名} \
      --mariadb-root-password {数据库管理员密码} \
      --admin-password {管理员登陆密码} \
      --no-mariadb-socket
    ```

2. 为站点安装应用
    ```shell
    docker-compose exec backend \
      bench --site {站点域名} install-app \
      erpnext \
      erpnext_chinese \
      erpnext_oob \
      {...更多应用}
    ```
    **注意:** 请确保需要安装的应用已经存在ERP镜像中

#### 更新服务

1. 修改`.env`的镜像版本

2. 拉取最新镜像
    ```shell
    docker-compose pull backend
    ```

3. 重新创建ERP服务
    ```shell
    docker-compose up -d -V
    ```

4. 当更新的版本涉及到字段变动时，需要进行一次合并操作
    ```shell
    docker-compose exec backend --site {站点域名} migrate
    ```

### Docker Swarm 集群部署

#### 要求
- Docker Swarm
- NFS服务

#### 配置Docker Swarm
1. 初始化Docker Swarm
   ```shell
   docker swarm init --advertise-addr {本机内网IP地址}
   ```

    示例：
   ```shell
    root@ubuntu:~# docker swarm init --advertise-addr 192.168.18.130
    Swarm initialized: current node (djjwd24eft4b2b6wp192oc652) is now a manager.

    To add a worker to this swarm, run the following command:

        docker swarm join --token SWMTKN-1-4a8mnmeo8x12q3jykc4we9mefy27dnv6mtc06i5kiho0dx9ocx-1i2yhrwsoclekureu0rlpqrgj 192.168.18.130:2377

    To add a manager to this swarm, run 'docker swarm join-token manager' and follow the instructions.
   ```
   本次执行将初始化集群环境，并输出加入集群的token：`docker swarm join --token xxxxx`

2. 其他主机加入集群
   使用上一步生成的命令执行加入集群操作，如果忘记了命令，可以执行`docker swarm join-token manager`来查看命令
    ```shell
    docker swarm join --token xxxxx
    ```

#### 准备部署目录

1. 创建部署目录
   ```shell
   mkdir -p ~/docker
   cp -r deploy/swarm ~/docker/erp
   cd ~/docker/erp
   ```

2. 配置环境变量
   ```shell
   cp .env.sample .env
   ```

   修改`.env`文件，设置ERP的`镜像名称(IMAGE)`、`镜像版本(VERSION)`、`访问端口(FRONTEND_PORT)`、`NFS服务器(NFS_SERVER)`

    ```properties
    # 镜像名称
    IMAGE=ccr.ccs.tencentyun.com/vnimy/erp
    # 镜像版本
    VERSION=version-15.231107
    # ERP访问端口
    FRONTEND_PORT=8080
    ```

#### 配置NFS服务器
NFS服务用于sites的持久化，所有需要用到sites的目录都需要挂在存储在NFS中的sites目录
修改`.env`文件，设置`NFS服务器(NFS_SERVER)`

```properties
# NFS设置，用于持久化sites目录
NFS_SERVER=192.168.200.88
# sites目录在NFS的位置
NFS_SITES_PATH=/erp/sites
```

#### 了解`deploy.sh`命令
>     用法：
>       <命令> [选项]
>     
>     命令：
>       help                    帮助
>       version                 查看当前镜像版本
>       ps                      查看任务列表
>       services                查看服务列表
>       init                    初始化全局配置
>       start                   启动服务
>       restart                 重启服务
>       down                    关闭服务
>       update [版本]           更新到指定版本，如不指定版本则使用当前版本进行更新服务
>       migrate [站点域名]      合并指定站点
>       scale [实例数]          将backend、frontend、websocket服务的实例调整到指定数量
>       port                    设置前端端口号，默认：8080
>       port [端口]             设置前端端口号
>       attach                  进入backend容器终端

#### 初始化全局配置
第一次运行服务前需要先初始化服务配置，用于生成sites目录的必要文件
```shell
./deploy.sh init
```

#### 启动ERP集群

```shell
./deploy.sh start
```

通过输入`./deploy.sh services`命令来查看服务启动情况，确认`REPLICAS`全部正常
```shell
root@ubuntu:~/docker/erp# ./deploy.sh services
ID             NAME                 MODE         REPLICAS   IMAGE                                                PORTS
ij5j7yr0jvim   erp_backend          replicated   3/3        ccr.ccs.tencentyun.com/vnimy/erp:version-15.231107
r3iuc82t5fc8   erp_db               replicated   1/1        mariadb:10.6                                         *:63306->3306/tcp
sr9gr7m7ecvm   erp_frontend         replicated   3/3        ccr.ccs.tencentyun.com/vnimy/erp:version-15.231107   *:8081->8080/tcp
2yum62qcmbtj   erp_queue-default    replicated   1/1        ccr.ccs.tencentyun.com/vnimy/erp:version-15.231107
hmddjx48quy4   erp_queue-long       replicated   1/1        ccr.ccs.tencentyun.com/vnimy/erp:version-15.231107
o2i86xt1t1a7   erp_queue-short      replicated   1/1        ccr.ccs.tencentyun.com/vnimy/erp:version-15.231107
pascw8zeu4l5   erp_redis-cache      replicated   1/1        redis:6.2-alpine
oy8v3zf5bu1u   erp_redis-queue      replicated   1/1        redis:6.2-alpine
tpw6s0gslqgi   erp_redis-socketio   replicated   1/1        redis:6.2-alpine
2veav9jt1xtp   erp_scheduler        replicated   1/1        ccr.ccs.tencentyun.com/vnimy/erp:version-15.231107
j2xtpotdsmp4   erp_websocket        replicated   3/3        ccr.ccs.tencentyun.com/vnimy/erp:version-15.231107
```

#### 新建站点

1. 进入backend容器
    ```shell
    ./deploy.sh attach
    ```
    进入backend容器后可使用bench命令进行新建站点、安装应用、更新站点等操作

2. 新建站点
    ```shell
    bench new-site {站点域名} \
      --mariadb-root-password {数据库管理员密码} \
      --admin-password {管理员登陆密码} \
      --no-mariadb-socket
    ```

3. 为站点安装应用
    ```shell
    bench --site {站点域名} install-app \
      erpnext \
      erpnext_chinese \
      erpnext_oob \
      {...更多应用}
    ```
    **注意:** 请确保需要安装的应用已经存在ERP镜像中

#### 更新服务

1. 执行更新命令
    ```shell
    ./deploy.sh update {版本号}
    ```

4. 当更新的版本涉及到字段变动时，需要进行一次合并操作
    ```shell
    ./deploy.sh migrate {站点域名}
    ```

### K8s Helm 部署

#### 准备
  1. **目录结构**
     - k8s
       - .env
       - custom-values.yaml
       - deploy.sh
       - site1.example.com **具体站点的模板**
         - tpl-new-site.yaml
         - tpl-migrate.yaml
         - tpl-ingress.yaml

  2. **部署设置**
      修改`custom-values.yaml`文件，按实际情况设置

  3. **设置站点模板**
      新建**站点名称**目录，将site1的文件复制进去，根据实际情况修改模板文件

  4. **设置默认值**
      ```properties
      # Chart包版本，可以在https://helm.erpnext.com/查询对应ERPNext版本的包版本
      CHART_VERSION=6.0.96
      # K8s命名空间
      NAMESPACE=frappe-bench-v14
      # 默认站点，在不设置--site参数时默认使用的站点，单站点推荐设置
      SITE=site1
      ```

#### 部署
  **命令**
  ```shell
  # ./deploy help
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
                              站点名称              site
  ```

  ```shell
  # 安装
  ./deploy.sh install
  # 卸载
  ./deploy.sh uninstall
  # 新建站点
  ./deploy.sh new-site -s site1.example.com
  # 创建路由
  ./deploy.sh create-ingress -s site1.example.com
  # 合并
  ./deploy.sh migrate -s site1.example.com
  ```


### 其他
#### 使用外部数据库（适用于Docker Compose 和 Docker Swarm）
  修改`.env`文件，设置`DB_HOST`、`DB_PORT`以及`DB_PASSWORD`
  ```properties
  # 数据库主机
  DB_HOST=192.168.200.10
  # 数据库端口
  DB_PORT=3306
  # 数据库root密码
  DB_PASSWORD=root
  ```
  **注意：** 只能使用**MariaDB**

## 特别感谢
感谢[余则霖](https://gitee.com/yuzelin)对ERPNext本地化的贡献，基于此将[界面汉化](https://gitee.com/yuzelin/erpnext_chinese)及[开箱即用](https://gitee.com/yuzelin/erpnext_oob)应用默认添加到builder-oob基础镜像中。

## 相关链接
- Frappe Framework https://frappeframework.com
- Frappe https://github.com/frappe/frappe
- ERPNext https://github.com/frappe/erpnext
- Frappe Docker https://github.com/frappe/frappe_docker
- ERPNext界面汉化 https://gitee.com/yuzelin/erpnext_chinese
- ERPNext开箱即用 https://gitee.com/yuzelin/erpnext_oob