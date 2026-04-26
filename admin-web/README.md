# TradeX Admin Web

TradeX 的独立后台管理前端，复用后端 `/api` 接口。

## 功能

- 用户管理
- 商品审核
- 订单处理

## 本地开发

```bash
cd admin-web
npm install
npm run dev
```

开发环境默认通过 Vite 代理把 `/api` 转发到 `127.0.0.1:8000`。

## 生产构建

```bash
npm run build
```
