import React from 'react';
import { Link, useLocation } from 'react-router-dom';

interface LayoutProps {
  children: React.ReactNode;
}

export const Layout: React.FC<LayoutProps> = ({ children }) => {
  const location = useLocation();

  const isActive = (path: string) => {
    return location.pathname === path ? 'nav-link active' : 'nav-link';
  };

  return (
    <div className="layout">
      <nav className="sidebar">
        <div className="sidebar-header">
          <h1 className="sidebar-title">EKS MSA Platform</h1>
          <p className="sidebar-subtitle">학습 플랫폼</p>
        </div>
        <ul className="nav-menu">
          <li className="nav-item">
            <Link to="/dashboard" className={isActive('/dashboard')}>
              📊 대시보드
            </Link>
          </li>
          <li className="nav-item">
            <Link to="/catalog" className={isActive('/catalog')}>
              📦 상품 카탈로그
            </Link>
          </li>
          <li className="nav-item">
            <Link to="/orders" className={isActive('/orders')}>
              🛒 주문 관리
            </Link>
          </li>
          <li className="nav-item">
            <Link to="/upload" className={isActive('/upload')}>
              📁 파일 업로드
            </Link>
          </li>
        </ul>
      </nav>
      <main className="main-content">
        {children}
      </main>
    </div>
  );
};