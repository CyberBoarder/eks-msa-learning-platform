import axios, { AxiosInstance, AxiosProgressEvent } from 'axios';

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

interface UploadedFile {
  id: string;
  filename: string;
  originalName: string;
  size: number;
  mimeType: string;
  uploadedAt: string;
  url: string;
}

class ApiClient {
  private client: AxiosInstance;

  constructor() {
    this.client = axios.create({
      baseURL: process.env.REACT_APP_API_BASE_URL || '/api',
      timeout: 30000,
      headers: {
        'Content-Type': 'application/json',
      },
    });

    // 요청 인터셉터
    this.client.interceptors.request.use(
      (config) => {
        console.log(`API Request: ${config.method?.toUpperCase()} ${config.url}`);
        return config;
      },
      (error) => {
        console.error('API Request Error:', error);
        return Promise.reject(error);
      }
    );

    // 응답 인터셉터
    this.client.interceptors.response.use(
      (response) => {
        console.log(`API Response: ${response.status} ${response.config.url}`);
        return response;
      },
      (error) => {
        console.error('API Response Error:', error.response?.status, error.response?.data);
        
        // 개발 환경에서 목업 데이터 반환
        if (process.env.NODE_ENV === 'development') {
          return this.handleMockResponse(error);
        }
        
        return Promise.reject(error);
      }
    );
  }

  private handleMockResponse(error: any) {
    const url = error.config?.url;
    const method = error.config?.method?.toUpperCase();

    console.log(`Returning mock data for: ${method} ${url}`);

    // 시스템 메트릭 목업
    if (url?.includes('/health') || url?.includes('/metrics')) {
      return {
        data: {
          services: [
            { name: 'Frontend', status: 'healthy', responseTime: 45 },
            { name: 'Main Service', status: 'healthy', responseTime: 120 },
            { name: 'Catalog Service', status: 'healthy', responseTime: 89 },
            { name: 'Order Service', status: 'healthy', responseTime: 156 }
          ],
          database: { status: 'connected', connections: 12 },
          cache: { status: 'connected', hitRate: 87 },
          storage: { status: 'available', usage: 34 }
        }
      };
    }

    // 상품 목록 목업
    if (url?.includes('/products') && method === 'GET') {
      return {
        data: [
          {
            id: '1',
            name: '노트북',
            description: '고성능 개발용 노트북',
            price: 1500000,
            category: 'electronics',
            stock: 15,
            createdAt: '2024-01-01T00:00:00Z',
            updatedAt: '2024-01-01T00:00:00Z'
          },
          {
            id: '2',
            name: '무선 마우스',
            description: '인체공학적 무선 마우스',
            price: 50000,
            category: 'electronics',
            stock: 25,
            createdAt: '2024-01-01T00:00:00Z',
            updatedAt: '2024-01-01T00:00:00Z'
          }
        ]
      };
    }

    // 카테고리 목록 목업
    if (url?.includes('/categories') && method === 'GET') {
      return {
        data: [
          { id: 'electronics', name: '전자제품', description: '컴퓨터 및 전자기기' },
          { id: 'books', name: '도서', description: '기술서적 및 일반도서' }
        ]
      };
    }

    // 주문 목록 목업
    if (url?.includes('/orders') && method === 'GET') {
      return {
        data: [
          {
            id: 'order-1',
            customerId: 'customer-1',
            customerName: '김개발',
            items: [
              { productId: '1', productName: '노트북', quantity: 1, price: 1500000 }
            ],
            totalAmount: 1500000,
            status: 'confirmed',
            createdAt: '2024-01-01T10:00:00Z',
            updatedAt: '2024-01-01T10:30:00Z'
          }
        ]
      };
    }

    // 기본 에러 반환
    return Promise.reject(error);
  }

  // 시스템 메트릭 조회
  async getSystemMetrics(): Promise<SystemMetrics> {
    const response = await this.client.get('/health');
    return response.data;
  }

  // 상품 관련 API
  async getProducts(): Promise<Product[]> {
    const response = await this.client.get('/products');
    return response.data;
  }

  async getProduct(id: string): Promise<Product> {
    const response = await this.client.get(`/products/${id}`);
    return response.data;
  }

  async getCategories(): Promise<Category[]> {
    const response = await this.client.get('/categories');
    return response.data;
  }

  // 주문 관련 API
  async getOrders(): Promise<Order[]> {
    const response = await this.client.get('/orders');
    return response.data;
  }

  async getOrder(id: string): Promise<Order> {
    const response = await this.client.get(`/orders/${id}`);
    return response.data;
  }

  async createOrder(orderData: CreateOrderRequest): Promise<Order> {
    const response = await this.client.post('/orders', orderData);
    return response.data;
  }

  async updateOrderStatus(orderId: string, status: Order['status']): Promise<Order> {
    const response = await this.client.patch(`/orders/${orderId}/status`, { status });
    return response.data;
  }

  // 파일 업로드 관련 API
  async uploadFile(
    formData: FormData, 
    onProgress?: (progress: number) => void
  ): Promise<UploadedFile> {
    const response = await this.client.post('/files/upload', formData, {
      headers: {
        'Content-Type': 'multipart/form-data',
      },
      onUploadProgress: (progressEvent: AxiosProgressEvent) => {
        if (progressEvent.total && onProgress) {
          const progress = Math.round((progressEvent.loaded * 100) / progressEvent.total);
          onProgress(progress);
        }
      },
    });
    return response.data;
  }

  async deleteFile(fileId: string): Promise<void> {
    await this.client.delete(`/files/${fileId}`);
  }

  async getFiles(): Promise<UploadedFile[]> {
    const response = await this.client.get('/files');
    return response.data;
  }
}

export const apiClient = new ApiClient();