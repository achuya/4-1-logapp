from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from app.routers import items
import logging
import json
import time
from pythonjsonlogger import jsonlogger

# ====================================
# ログ設定（JSON形式）
# ====================================
def setup_logging():
    logger = logging.getLogger()
    logger.setLevel(logging.INFO)

    handler = logging.StreamHandler()
    formatter = jsonlogger.JsonFormatter(
        fmt="%(asctime)s %(name)s %(levelname)s %(message)s",
        datefmt="%Y-%m-%dT%H:%M:%S"
    )
    handler.setFormatter(formatter)
    logger.addHandler(handler)

setup_logging()

logger = logging.getLogger(__name__)

# ====================================
# FastAPIアプリ
# ====================================
app = FastAPI(
    title="Log App API",
    description="CloudWatchログ・アラートのデモAPI",
    version="1.0.1"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ====================================
# リクエストログミドルウェア
# ====================================
@app.middleware("http")
async def log_requests(request: Request, call_next):
    start_time = time.time()
    logger.info(
        f"リクエスト開始",
        extra={
            "method": request.method,
            "path": request.url.path,
            "client": request.client.host if request.client else "unknown"
        }
    )

    response = await call_next(request)

    duration = time.time() - start_time
    logger.info(
        f"リクエスト完了",
        extra={
            "method": request.method,
            "path": request.url.path,
            "status_code": response.status_code,
            "duration_ms": round(duration * 1000, 2)
        }
    )
    return response

# ====================================
# グローバルエラーハンドラー
# ====================================
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    logger.error(
        f"予期しないエラーが発生しました",
        extra={
            "path": request.url.path,
            "error": str(exc)
        }
    )
    return JSONResponse(
        status_code=500,
        content={"detail": "Internal Server Error"}
    )

app.include_router(items.router, prefix="/api")

@app.get("/health")
def health_check():
    logger.info("ヘルスチェック")
    return {"status": "ok"}