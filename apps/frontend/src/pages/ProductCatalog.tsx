import React, { useState, useEffect } from 'react';
import { apiClient } from '../services/apiClient';

interface Product {
  id: string;
  name: string;
  description: string;
  price: number;
  category: string;
  stock: number;
  imageUrl?: string;
  createdAt: string;
  updatedAt: string;
}

interface Category {
  id: string;
  name: string;
  description: string;
}

export const ProductCatalog: React.FC = () => {
  const [products, setProducts] = useState<Product[]>([]);
  const [categories, setCategories] = useState<Category[]>([]);
  const [selectedCategory, setSelectedCategory] = useState<string>('all');
  const [searchTerm, setSearchTerm] = useState<string>('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fetchData = async () => {
      try {
        setLoading(true);
        const [productsData, categoriesData] = await Promise.all([
          apiClient.getProducts(),
          apiClient.getCategories()
        ]);
        setProducts(productsData);
        setCategories(categoriesData);
        setError(null);
      } catch (err) {
        setError('상품 데이터를 불러오는데 실패했습니다.');
        console.error('Failed to fetch products:', err);
      } finally {
        setLoading(false);
      }
    };

    fetchData();
  }, []);

  const filteredProducts = products.filter(product => {
    const matchesCategory = selectedCategory === 'all' || product.category === selectedCategory;
    const matchesSearch = product.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
                         product.description.toLowerCase().includes(searchTerm.toLowerCase());
    return matchesCategory && matchesSearch;
  });

  const formatPrice = (price: number) => {
    return new Intl.NumberFormat('ko-KR', {
      style: 'currency',
      currency: 'KRW'
    }).format(price);
  };

  const getStockStatus = (stock: number) => {
    if (stock === 0) return <span className="badge badge-danger">품절</span>;
    if (stock < 10) return <span className="badge badge-warning">재고 부족</span>;
    return <span className="badge badge-success">재고 충분</span>;
  };

  if (loading) {
    return (
      <div className="page-header">
        <h1 className="page-title">상품 카탈로그</h1>
        <div className="loading-spinner"></div>
      </div>
    );
  }

  if (error) {
    return (
      <div>
        <div className="page-header">
          <h1 className="page-title">상품 카탈로그</h1>
        </div>
        <div className="alert alert-danger">{error}</div>
      </div>
    );
  }

  return (
    <div>
      <div className="page-header">
        <h1 className="page-title">상품 카탈로그</h1>
        <p className="page-description">등록된 상품들을 조회하고 관리할 수 있습니다.</p>
      </div>

      <div className="card mb-20">
        <div className="card-body">
          <div className="row">
            <div className="col-6">
              <div className="form-group">
                <label className="form-label">카테고리 필터</label>
                <select 
                  className="form-control"
                  value={selectedCategory}
                  onChange={(e) => setSelectedCategory(e.target.value)}
                >
                  <option value="all">전체 카테고리</option>
                  {categories.map(category => (
                    <option key={category.id} value={category.id}>
                      {category.name}
                    </option>
                  ))}
                </select>
              </div>
            </div>
            <div className="col-6">
              <div className="form-group">
                <label className="form-label">상품 검색</label>
                <input
                  type="text"
                  className="form-control"
                  placeholder="상품명 또는 설명으로 검색..."
                  value={searchTerm}
                  onChange={(e) => setSearchTerm(e.target.value)}
                />
              </div>
            </div>
          </div>
        </div>
      </div>

      <div className="card">
        <div className="card-header">
          <h3 className="card-title">
            상품 목록 ({filteredProducts.length}개)
          </h3>
        </div>
        <div className="card-body">
          {filteredProducts.length === 0 ? (
            <div className="text-center p-20">
              <p>조건에 맞는 상품이 없습니다.</p>
            </div>
          ) : (
            <div className="products-grid">
              {filteredProducts.map(product => (
                <div key={product.id} className="product-card">
                  <div className="product-image">
                    {product.imageUrl ? (
                      <img src={product.imageUrl} alt={product.name} />
                    ) : (
                      <div className="product-placeholder">
                        📦
                      </div>
                    )}
                  </div>
                  <div className="product-info">
                    <h4 className="product-name">{product.name}</h4>
                    <p className="product-description">{product.description}</p>
                    <div className="product-details">
                      <div className="product-price">
                        {formatPrice(product.price)}
                      </div>
                      <div className="product-stock">
                        재고: {product.stock}개 {getStockStatus(product.stock)}
                      </div>
                      <div className="product-category">
                        카테고리: {categories.find(c => c.id === product.category)?.name || product.category}
                      </div>
                    </div>
                    <div className="product-actions">
                      <button className="btn btn-primary btn-sm">
                        상세보기
                      </button>
                      <button className="btn btn-success btn-sm">
                        주문하기
                      </button>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
};