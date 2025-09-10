import React, { useState, useEffect } from 'react';
import { apiClient } from '../services/apiClient';

interface Order {
  id: string;
  customerId: string;
  customerName: string;
  items: OrderItem[];
  totalAmount: number;
  status: 'pending' | 'confirmed' | 'processing' | 'shipped' | 'delivered' | 'cancelled';
  createdAt: string;
  updatedAt: string;
}

interface OrderItem {
  productId: string;
  productName: string;
  quantity: number;
  price: number;
}

interface CreateOrderRequest {
  customerId: string;
  customerName: string;
  items: {
    productId: string;
    quantity: number;
  }[];
}

export const OrderManagement: React.FC = () => {
  const [orders, setOrders] = useState<Order[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [showCreateForm, setShowCreateForm] = useState(false);
  const [createOrderData, setCreateOrderData] = useState<CreateOrderRequest>({
    customerId: '',
    customerName: '',
    items: []
  });

  useEffect(() => {
    fetchOrders();
  }, []);

  const fetchOrders = async () => {
    try {
      setLoading(true);
      const data = await apiClient.getOrders();
      setOrders(data);
      setError(null);
    } catch (err) {
      setError('주문 데이터를 불러오는데 실패했습니다.');
      console.error('Failed to fetch orders:', err);
    } finally {
      setLoading(false);
    }
  };

  const handleCreateOrder = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      await apiClient.createOrder(createOrderData);
      setShowCreateForm(false);
      setCreateOrderData({
        customerId: '',
        customerName: '',
        items: []
      });
      await fetchOrders();
    } catch (err) {
      setError('주문 생성에 실패했습니다.');
      console.error('Failed to create order:', err);
    }
  };

  const handleStatusChange = async (orderId: string, newStatus: Order['status']) => {
    try {
      await apiClient.updateOrderStatus(orderId, newStatus);
      await fetchOrders();
    } catch (err) {
      setError('주문 상태 변경에 실패했습니다.');
      console.error('Failed to update order status:', err);
    }
  };

  const getStatusBadge = (status: Order['status']) => {
    const statusMap = {
      pending: { class: 'badge-warning', text: '대기중' },
      confirmed: { class: 'badge-info', text: '확인됨' },
      processing: { class: 'badge-info', text: '처리중' },
      shipped: { class: 'badge-success', text: '배송중' },
      delivered: { class: 'badge-success', text: '배송완료' },
      cancelled: { class: 'badge-danger', text: '취소됨' }
    };
    
    const statusInfo = statusMap[status];
    return <span className={`badge ${statusInfo.class}`}>{statusInfo.text}</span>;
  };

  const formatPrice = (price: number) => {
    return new Intl.NumberFormat('ko-KR', {
      style: 'currency',
      currency: 'KRW'
    }).format(price);
  };

  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleString('ko-KR');
  };

  if (loading) {
    return (
      <div className="page-header">
        <h1 className="page-title">주문 관리</h1>
        <div className="loading-spinner"></div>
      </div>
    );
  }

  return (
    <div>
      <div className="page-header">
        <h1 className="page-title">주문 관리</h1>
        <p className="page-description">고객 주문을 조회하고 상태를 관리할 수 있습니다.</p>
        <button 
          className="btn btn-primary"
          onClick={() => setShowCreateForm(true)}
        >
          새 주문 생성
        </button>
      </div>

      {error && (
        <div className="alert alert-danger mb-20">{error}</div>
      )}

      {showCreateForm && (
        <div className="card mb-20">
          <div className="card-header">
            <h3 className="card-title">새 주문 생성</h3>
          </div>
          <div className="card-body">
            <form onSubmit={handleCreateOrder}>
              <div className="row">
                <div className="col-6">
                  <div className="form-group">
                    <label className="form-label">고객 ID</label>
                    <input
                      type="text"
                      className="form-control"
                      value={createOrderData.customerId}
                      onChange={(e) => setCreateOrderData({
                        ...createOrderData,
                        customerId: e.target.value
                      })}
                      required
                    />
                  </div>
                </div>
                <div className="col-6">
                  <div className="form-group">
                    <label className="form-label">고객명</label>
                    <input
                      type="text"
                      className="form-control"
                      value={createOrderData.customerName}
                      onChange={(e) => setCreateOrderData({
                        ...createOrderData,
                        customerName: e.target.value
                      })}
                      required
                    />
                  </div>
                </div>
              </div>
              <div className="form-actions">
                <button type="submit" className="btn btn-success">
                  주문 생성
                </button>
                <button 
                  type="button" 
                  className="btn btn-secondary"
                  onClick={() => setShowCreateForm(false)}
                >
                  취소
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      <div className="card">
        <div className="card-header">
          <h3 className="card-title">주문 목록 ({orders.length}개)</h3>
        </div>
        <div className="card-body">
          {orders.length === 0 ? (
            <div className="text-center p-20">
              <p>등록된 주문이 없습니다.</p>
            </div>
          ) : (
            <div className="table-responsive">
              <table className="table">
                <thead>
                  <tr>
                    <th>주문 ID</th>
                    <th>고객명</th>
                    <th>상품 수</th>
                    <th>총 금액</th>
                    <th>상태</th>
                    <th>주문일시</th>
                    <th>액션</th>
                  </tr>
                </thead>
                <tbody>
                  {orders.map(order => (
                    <tr key={order.id}>
                      <td>
                        <code>{order.id.substring(0, 8)}...</code>
                      </td>
                      <td>{order.customerName}</td>
                      <td>{order.items.length}개</td>
                      <td>{formatPrice(order.totalAmount)}</td>
                      <td>{getStatusBadge(order.status)}</td>
                      <td>{formatDate(order.createdAt)}</td>
                      <td>
                        <select
                          className="form-control form-control-sm"
                          value={order.status}
                          onChange={(e) => handleStatusChange(order.id, e.target.value as Order['status'])}
                        >
                          <option value="pending">대기중</option>
                          <option value="confirmed">확인됨</option>
                          <option value="processing">처리중</option>
                          <option value="shipped">배송중</option>
                          <option value="delivered">배송완료</option>
                          <option value="cancelled">취소됨</option>
                        </select>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};