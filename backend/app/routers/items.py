from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app import models, schemas
from app.database import get_db
import logging

logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/items",
    tags=["items"]
)


@router.get("/", response_model=list[schemas.ItemResponse])
def get_items(db: Session = Depends(get_db)):
    logger.info("商品一覧を取得します")
    try:
        items = db.query(models.Item).all()
        logger.info(f"商品一覧を取得しました件数={len(items)}")
        return items
    except Exception as e:
        logger.error(f"商品一覧の取得に失敗しました error={str(e)}")
        raise HTTPException(status_code=500, detail="Internal Server Error")


@router.get("/{item_id}", response_model=schemas.ItemResponse)
def get_item(item_id: int, db: Session = Depends(get_db)):
    logger.info(f"商品を取得します item_id={item_id}")
    try:
        item = db.query(models.Item).filter(models.Item.id == item_id).first()
        if not item:
            logger.warning(f"商品が見つかりません item_id={item_id}")
            raise HTTPException(status_code=404, detail="Item not found")
        logger.info(f"商品を取得しました item_id={item_id}")
        return item
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"商品の取得に失敗しました item_id={item_id} error={str(e)}")
        raise HTTPException(status_code=500, detail="Internal Server Error")


@router.post("/", response_model=schemas.ItemResponse, status_code=201)
def create_item(item: schemas.ItemCreate, db: Session = Depends(get_db)):
    logger.info(f"商品を作成します name={item.name} price={item.price}")
    try:
        db_item = models.Item(**item.model_dump())
        db.add(db_item)
        db.commit()
        db.refresh(db_item)
        logger.info(f"商品を作成しました item_id={db_item.id}")
        return db_item
    except Exception as e:
        logger.error(f"商品の作成に失敗しました error={str(e)}")
        db.rollback()
        raise HTTPException(status_code=500, detail="Internal Server Error")


@router.put("/{item_id}", response_model=schemas.ItemResponse)
def update_item(
    item_id: int,
    item: schemas.ItemUpdate,
    db: Session = Depends(get_db)
):
    logger.info(f"商品を更新します item_id={item_id}")
    try:
        db_item = db.query(models.Item).filter(models.Item.id == item_id).first()
        if not db_item:
            logger.warning(f"更新対象の商品が見つかりません item_id={item_id}")
            raise HTTPException(status_code=404, detail="Item not found")
        for key, value in item.model_dump(exclude_none=True).items():
            setattr(db_item, key, value)
        db.commit()
        db.refresh(db_item)
        logger.info(f"商品を更新しました item_id={item_id}")
        return db_item
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"商品の更新に失敗しました item_id={item_id} error={str(e)}")
        db.rollback()
        raise HTTPException(status_code=500, detail="Internal Server Error")


@router.delete("/{item_id}", status_code=204)
def delete_item(item_id: int, db: Session = Depends(get_db)):
    logger.info(f"商品を削除します item_id={item_id}")
    try:
        db_item = db.query(models.Item).filter(models.Item.id == item_id).first()
        if not db_item:
            logger.warning(f"削除対象の商品が見つかりません item_id={item_id}")
            raise HTTPException(status_code=404, detail="Item not found")
        db.delete(db_item)
        db.commit()
        logger.info(f"商品を削除しました item_id={item_id}")
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"商品の削除に失敗しました item_id={item_id} error={str(e)}")
        db.rollback()
        raise HTTPException(status_code=500, detail="Internal Server Error")