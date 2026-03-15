软件工程作业

# 选题

4、商品网上交易系统要求

（1）用户管理：主要包括注册、登录、留言等功能模块。

（2）商品管理：主要包括发布在线产品展示功能（必须有图片的形式）以及对商品信息的管理。

（3）审查管理：主要包括管理员对注册的审查以及商品的审查。

（4）用户购物：主要包括用户能对已经审核通过的商品进行在线产品查找功能，并且进行在线下订单购物功能。

（5）配送：主要包括买家和卖家对订单的一系列操作：用户下订单后。卖家在发现后修改订单状态为出货，买家收到物品后能将订单状态修改为已收货，交易成功结束。


# 成员

Contributors: dudujerry452(周致远) Junhan327(刘俊含) morose098(李子豪) HKJay(黄坤) 


# 环境

## Nix 开发环境 for dudujerry452

见 `flake.nix`和`.envrc`.

## Vue 前端环境

前端项目已创建在 `frontend/`，技术栈是 Vue 3 + Vite。

1. 启动前端开发服务器：`cd frontend && npm run dev`
2. 构建前端：`cd frontend && npm run build`

注: `frontend/vite.config.js` 已配置开发代理：访问 `/api` 时会转发到 `http://127.0.0.1:8000`. 


## 开发流程

### 1. 启动后端

`python djangotradeX/manage.py runserver 127.0.0.1:8000`

1. 数据库迁移：`python djangotradeX/manage.py migrate`
2. 创建管理员：`python djangotradeX/manage.py createsuperuser`

### 2. 启动前端

1. `cd /home/dudujerry/TradeX`
2. `nix develop`
3. `cd frontend && npm run dev`

前端默认地址：`http://127.0.0.1:5173`

- 前端请求以 `/api/...` 开头时，会由 Vite 代理到 Django 的 `127.0.0.1:8000`
- 建议 Django API 路由统一挂在 `/api/` 前缀下

### 5. 建议

1. 前端构建检查：`cd frontend && npm run build`
2. 后端配置检查：`python djangotradeX/manage.py check`

