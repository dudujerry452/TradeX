from ninja import NinjaAPI

from core.api import router as core_router

api = NinjaAPI(
    title="TradeX API",
    version="0.1.0",
    description="商品网上交易系统 REST API",
    docs_url="/docs",
)

api.add_router("/", core_router)
