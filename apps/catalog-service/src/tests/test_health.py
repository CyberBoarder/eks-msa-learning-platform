import pytest
from fastapi.testclient import TestClient
from unittest.mock import AsyncMock, patch

from ..main import app

client = TestClient(app)

def test_health_check():
    """기본 헬스체크 테스트"""
    response = client.get("/health/")
    assert response.status_code == 200
    
    data = response.json()
    assert data["service"] == "Catalog Service"
    assert data["status"] == "healthy"
    assert "timestamp" in data
    assert "version" in data
    assert "environment" in data

def test_liveness_probe():
    """Liveness probe 테스트"""
    response = client.get("/health/live")
    assert response.status_code == 200
    assert response.json() == {"status": "alive"}

@patch('src.routers.health.test_database_connection')
@patch('src.routers.health.cache_manager.ping')
def test_readiness_probe_healthy(mock_cache_ping, mock_db_test):
    """Readiness probe 테스트 - 정상 상태"""
    mock_db_test.return_value = True
    mock_cache_ping.return_value = True
    
    response = client.get("/health/ready")
    assert response.status_code == 200
    assert response.json() == {"status": "ready"}

@patch('src.routers.health.test_database_connection')
@patch('src.routers.health.cache_manager.ping')
def test_readiness_probe_unhealthy(mock_cache_ping, mock_db_test):
    """Readiness probe 테스트 - 비정상 상태"""
    mock_db_test.return_value = False
    mock_cache_ping.return_value = True
    
    response = client.get("/health/ready")
    assert response.status_code == 503

@patch('src.routers.health.cache_manager.get_stats')
def test_metrics_endpoint(mock_get_stats):
    """메트릭 엔드포인트 테스트"""
    mock_get_stats.return_value = {
        'uptime_in_seconds': 3600,
        'keyspace_hits': 100,
        'keyspace_misses': 20,
        'used_memory': 1024000,
        'connected_clients': 5,
        'total_commands_processed': 1000
    }
    
    response = client.get("/health/metrics")
    assert response.status_code == 200
    assert response.headers["content-type"] == "text/plain; charset=utf-8"
    
    content = response.text
    assert "catalog_service_uptime_seconds 3600" in content
    assert "catalog_service_cache_hits_total 100" in content
    assert "catalog_service_cache_misses_total 20" in content

@patch('src.routers.health.test_database_connection')
@patch('src.routers.health.cache_manager.ping')
@patch('src.routers.health.cache_manager.get_stats')
def test_detailed_health_check(mock_get_stats, mock_cache_ping, mock_db_test):
    """상세 헬스체크 테스트"""
    mock_db_test.return_value = True
    mock_cache_ping.return_value = True
    mock_get_stats.return_value = {
        'connected_clients': 5,
        'used_memory': 1024000,
        'keyspace_hits': 100,
        'keyspace_misses': 20
    }
    
    response = client.get("/health/detailed")
    assert response.status_code == 200
    
    data = response.json()
    assert data["service"] == "Catalog Service"
    assert data["status"] == "healthy"
    assert "database" in data
    assert "cache" in data
    assert "dependencies" in data
    
    assert data["database"]["status"] == "connected"
    assert data["cache"]["status"] == "connected"