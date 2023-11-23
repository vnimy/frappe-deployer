ARG DOCKER_REGISTRY=ccr.ccs.tencentyun.com
ARG DOCKER_NAMESPACE=vnimy
FROM ${DOCKER_REGISTRY}/${DOCKER_NAMESPACE}/frappe-builder:latest as builder

# apps.json includes
ARG APPS_JSON_BASE64
RUN if [ -n "${APPS_JSON_BASE64}" ]; then \
    mkdir /opt/frappe && echo "${APPS_JSON_BASE64}" | base64 -d > /opt/frappe/apps.json; \
  fi

USER frappe

ARG FRAPPE_BRANCH=version-15
ARG FRAPPE_REPO=https://github.com/frappe/frappe
# ARG ERPNEXT_REPO=https://github.com/frappe/erpnext
# ARG ERPNEXT_BRANCH=version-15
RUN \
  # 设置镜像
  mkdir ~/.pip \
  && echo '[global]' > ~/.pip/pip.conf \
  && echo 'index-url = https://pypi.tuna.tsinghua.edu.cn/simple' >> ~/.pip/pip.conf \
  && echo '[install]' >> ~/.pip/pip.conf \
  && echo 'trusted-host = https://pypi.tuna.tsinghua.edu.cn' >> ~/.pip/pip.conf \
  # 安装app
  export APP_INSTALL_ARGS="" && \
  if [ -n "${APPS_JSON_BASE64}" ]; then \
    export APP_INSTALL_ARGS="--apps_path=/opt/frappe/apps.json"; \
  fi && \
  bench init ${APP_INSTALL_ARGS}\
  --frappe-branch=${FRAPPE_BRANCH} \
  --frappe-path=${FRAPPE_REPO} \
  --no-procfile \
  --no-backups \
  --skip-redis-config-generation \
  --verbose \
  /home/frappe/frappe-bench && \
  cd /home/frappe/frappe-bench && \
  # bench get-app --branch=${ERPNEXT_BRANCH} --resolve-deps erpnext ${ERPNEXT_REPO} && \
  echo "{}" > sites/common_site_config.json && \
  find apps -mindepth 1 -path "*/.git" | xargs rm -fr

FROM ${DOCKER_REGISTRY}/${DOCKER_NAMESPACE}/frappe-base:latest as erpnext


COPY resources/nginx-template.conf /templates/nginx/frappe.conf.template
COPY resources/entrypoints /usr/local/bin

RUN cd /usr/local/bin \
  && chmod 755 \
  backend-entrypoint.sh \
  configurator-entrypoint.sh \
  nginx-entrypoint.sh \
  websocket-entrypoint.sh

USER frappe

COPY --from=builder --chown=frappe:frappe /home/frappe/frappe-bench /home/frappe/frappe-bench

WORKDIR /home/frappe/frappe-bench

VOLUME [ \
  "/home/frappe/frappe-bench/sites", \
  "/home/frappe/frappe-bench/sites/assets", \
  "/home/frappe/frappe-bench/logs" \
]

CMD [ "backend-entrypoint.sh" ]