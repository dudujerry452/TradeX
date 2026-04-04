"""
core/api/system.py — 系统相关接口
"""
from datetime import datetime
from ninja import Router

router = Router()


@router.get("/health", tags=["System"], auth=None)
def health_check(request):
    """健康检查接口"""
    return {"status": "ok", "timestamp": datetime.now().isoformat()}
