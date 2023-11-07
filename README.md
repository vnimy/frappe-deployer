- [部署说明](#部署说明)
  - [环境要求](#环境要求)
    - [安装Docker](#安装docker)
    - [安装docker-compose](#安装docker-compose)
  - [构建](#构建)
    - [了解`build.sh`的命令](#了解buildsh的命令)
      - [设置构建默认值](#设置构建默认值)
    - [构建基础镜像](#构建基础镜像)
      - [相关命令](#相关命令)
    - [构建生产镜像](#构建生产镜像)
  - [部署](#部署)
    - [首次安装](#首次安装)
      - [准备部署目录](#准备部署目录)
      - [启动ERP服务](#启动erp服务)
      - [新建站点](#新建站点)
    - [更新服务](#更新服务)


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
>       base                    打包基础镜像
>       builder                 打包builder> 镜像
>       backend [选项]          打包后端镜像
>       backend [-h | --help]   后端镜像打包帮助
>       get-default             查看当前构建默认值
>       set-default             设置构建默认值
>                                 使用方法：set-default param1=value1 param2=value2 ...
>                                 支持以下参数：
>                                 镜像注册中心  registry
>                                 镜像命名空间  namespace
>                                 Frappe版本    frappe_version
>                                 Frappe仓库    frappe_path

#### 设置构建默认值
构建镜像时基于几个默认变量来确定镜像名称，要推送到的注册中心，frappe框架版本等，默认值如下：

| 参数名称       | 参数           | 默认值                               |
| -------------- | -------------- | ------------------------------------ |
| 镜像注册中心   | registry       | ccr.ccs.tencentyun.com               |
| 镜像命名空间   | namespace      | vnimy                                |
| Frappe框架版本 | frappe_version | version-15                           |
| Frappe仓库地址 | frappe_path    | https://gitee.com/mirrors/frappe.git |

1. 设置默认值
    ```shell
    ./build.sh set-default \
      registry=ccr.ccs.tencentyun.com \
      namespace=vnimy \
      frappe_version=version-15 \
      frappe_path=https://gitee.com/mirrors/frappe.git
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

### 构建生产镜像

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
      },
      {
        "url": "https://gitee.com/yuzelin/zelin_pp.git",
        "branch": "master"
      }
    ]
   ```

2. 构建并推送生产镜像
    ```shell
    ./build.sh backend
    ```
    > 该命令会产生镜像`{$registry}/{$namespace}/erp:{$frappe_version}.{$(date '+%y%m%d')}`，镜像版本由Frappe框架版本及构建日期组成，如：`ccr.ccs.tencentyun.com/vnimy/erp:version-15.231106`。

## 部署

### 首次安装

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
   cp .env.sample
   ```

   修改`.env`文件，设置ERP的`镜像名称(IMAGE)`、`镜像版本(VERSION)`、`访问端口(FRONTEND_PORT)`环境变量

#### 启动ERP服务

```shell
docker-compose up -d -V
```

#### 新建站点

1. 新建站点
    ```shell
    bench new-site {站点域名} --mariadb-root-password {数据库管理员密码} --admin-password {管理员登陆密码} --no-mariadb-socket
    ```

2. 为站点安装应用
    ```shell
    bench --site {站点域名} install-app \
      erpnext \
      erpnext_chinese \
      erpnext_oob \
      {...更多应用}
    ```
    **注意:** 请确保需要安装的应用已经存在ERP镜像中



### 更新服务

1. 拉取最新镜像
    ```shell
    docker-compose pull backend
    ```

2. 重新创建ERP服务
    ```shell
    docker-compose up -d -V
    ```

3. 当更新的版本涉及到字段变动时，需要进行一次合并操作
    ```shell
    docker-compose exec backend --site {站点域名} migrate
    ```