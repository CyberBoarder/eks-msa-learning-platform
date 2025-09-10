import React from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import { Layout } from './components/Layout';
import { ProductCatalog } from './pages/ProductCatalog';
import { OrderManagement } from './pages/OrderManagement';
import { FileUpload } from './pages/FileUpload';
import { Dashboard } from './pages/Dashboard';
import './App.css';

const App: React.FC = () => {
  return (
    <Router>
      <Layout>
        <Routes>
          <Route path="/" element={<Navigate to="/dashboard" replace />} />
          <Route path="/dashboard" element={<Dashboard />} />
          <Route path="/catalog" element={<ProductCatalog />} />
          <Route path="/orders" element={<OrderManagement />} />
          <Route path="/upload" element={<FileUpload />} />
        </Routes>
      </Layout>
    </Router>
  );
};

export default App;