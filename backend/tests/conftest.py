import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker
from testcontainers.postgres import PostgresContainer

from app.db.base import Base, get_db
from app.main import create_app


@pytest.fixture(scope="session")
def pg_container():
    with PostgresContainer("postgres:16-alpine") as pg:
        yield pg


@pytest.fixture(scope="session")
def db_engine(pg_container):
    url = pg_container.get_connection_url().replace("psycopg2", "psycopg")
    engine = create_engine(url, pool_pre_ping=True)
    Base.metadata.create_all(engine)
    yield engine
    engine.dispose()


@pytest.fixture
def db_session(db_engine):
    SessionLocal = sessionmaker(bind=db_engine, autocommit=False, autoflush=False)
    session = SessionLocal()
    try:
        yield session
    finally:
        session.rollback()
        # Clean tables between tests
        session.execute(text("TRUNCATE order_combined, order_detail, order_date CASCADE"))
        session.commit()
        session.close()


@pytest.fixture
def client(db_engine):
    app = create_app()
    SessionLocal = sessionmaker(bind=db_engine, autocommit=False, autoflush=False)

    def override_db():
        session = SessionLocal()
        try:
            yield session
        except Exception:
            session.rollback()
            raise
        finally:
            session.close()

    app.dependency_overrides[get_db] = override_db
    with TestClient(app) as c:
        yield c
