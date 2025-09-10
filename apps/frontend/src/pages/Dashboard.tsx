import React, { useState, useEffect } from 'react';
import { apiClient } from '../services/apiClient';

interface SystemMetrics {
  services: {
    name: string;
    status: 'healthy' | 'unhealthy' | 'unknown';
    responseTime: number;
  }[];
  database: {
    status: 'connected' | 'disconnected';
    connections: number;
  };
  cache: {
    status: 'connected' | 'disconnected';
    hitRate: number;
  };
  storage: {
    status: 'available' | 'unavailable';
    usage: number;
  };
}

export const Dashboard: React.FC = () => {
  const [metrics, setMetrics] = useState<SystemMetrics | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fetchMetrics = async () => {
      try {
        setLoading(true);
        const data = await apiClient.getSystemMetrics();
        setMetrics(data);
        setError(null);
      } catch (err) {
        setError('시스템 메트릭을 불러오는데 실패했습니다.');
        console.error('Failed to fetch metrics:', err);
      } finally {
        setLoading(false);
      }
    };

    fetchMetrics();
    const interval = setInterval(fetchMetrics, 30000); // 30초마다 업데이트

    return () => clearInterval(interval);
  }, []);

  const getStatusBadge = (status: string) => {
    switch (status) {
      case 'healthy':
      case 'connected':
      case 'available':
        return <span className="badge badge-success">{status}</span>;
      case 'unhealthy':
      case 'disconnected':
      case 'unavailable':
        return <span className="badge badge-danger">{status}</span>;
      default:
        return <span className="badge badge-warning">{status}</span>;
    }
  };

  if (loading) {
    return (
      <div className="page-header">
        <h1 className="page-title">시스템 대시보드</h1>
        <div className="loading-spinner"></div>
      </div>
    );
  }

  if (error) {
    return (
      <div>
        <div className="page-header">
          <h1 className="page-title">시스템 대시보드</h1>
        </div>
        <div className="alert alert-danger">{error}</div>
      </div>
    );
  }

  return (
    <div>
      <div className="page-header">
        <h1 className="page-title">시스템 대시보드</h1>
        <p className="page-description">EKS MSA 학습 플랫폼의 실시간 상태를 모니터링합니다.</p>
      </div>

      <div className="row">
        <div className="col-6">
          <div className="card">
            <div className="card-header">
              <h3 className="card-title">마이크로서비스 상태</h3>
            </div>
            <div className="card-body">
              {metrics?.services.map((service) => (
                <div key={service.name} className="service-status">
                  <div className="service-info">
                    <strong>{service.name}</strong>
                    {getStatusBadge(service.status)}
                  </div>
                  <div className="service-metrics">
                    응답시간: {service.responseTime}ms
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>

        <div className="col-6">
          <div className="card">
            <div className="card-header">
              <h3 className="card-title">인프라 상태</h3>
            </div>
            <div className="card-body">
              <div className="infra-metric">
                <div className="metric-label">데이터베이스</div>
                <div className="metric-value">
                  {getStatusBadge(metrics?.database.status || 'unknown')}
                  <span className="metric-detail">
                    연결 수: {metrics?.database.connections || 0}
                  </span>
                </div>
              </div>

              <div className="infra-metric">
                <div className="metric-label">캐시 (Redis)</div>
                <div className="metric-value">
                  {getStatusBadge(metrics?.cache.status || 'unknown')}
                  <span className="metric-detail">
                    히트율: {metrics?.cache.hitRate || 0}%
                  </span>
                </div>
              </div>

              <div className="infra-metric">
                <div className="metric-label">스토리지 (S3)</div>
                <div className="metric-value">
                  {getStatusBadge(metrics?.storage.status || 'unknown')}
                  <span className="metric-detail">
                    사용량: {metrics?.storage.usage || 0}%
                  </span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div className="row mt-20">
        <div className="col-12">
          <div className="card">
            <div className="card-header">
              <h3 className="card-title">시스템 개요</h3>
            </div>
            <div className="card-body">
              <p>
                이 대시보드는 EKS 기반 마이크로서비스 아키텍처의 실시간 상태를 보여줍니다.
                각 서비스의 헬스체크, 데이터베이스 연결 상태, 캐시 성능, 스토리지 사용량을 
                모니터링할 수 있습니다.
              </p>
              <div className="system-info">
                <div className="info-item">
                  <strong>플랫폼:</strong> Amazon EKS
                </div>
                <div className="info-item">
                  <strong>서비스 수:</strong> {metrics?.services.length || 0}개
                </div>
                <div className="info-item">
                  <strong>마지막 업데이트:</strong> {new Date().toLocaleString('ko-KR')}
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};