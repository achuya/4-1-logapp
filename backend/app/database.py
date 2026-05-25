from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base
import os
import json

database_url = os.getenv("DATABASE_URL", "sqlite:///./test.db")

# Secrets ManagerのJSON形式に対応
try:
    parsed = json.loads(database_url)
    if isinstance(parsed, dict) and "DATABASE_URL" in parsed:
        database_url = parsed["DATABASE_URL"]
except (json.JSONDecodeError, TypeError):
    pass

DATABASE_URL = database_url

engine = create_engine(
    DATABASE_URL,
    connect_args={"check_same_thread": False} if "sqlite" in DATABASE_URL else {}
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()