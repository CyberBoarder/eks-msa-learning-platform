from pydantic import BaseModel, Field, validator
from typing import Optional, List
from datetime import datetime
from decimal import Decimal

# 기본 스키마들
class CategoryBase(BaseModel):
    """카테고리 기본 스키마"""
    name: str = Field(..., min_length=1, max_length=100)
    description: Optional[str] = None
    parent_id: Optional[str] = None
    is_active: bool = True
    sort_order: int = 0

class CategoryCreate(CategoryBase):
    """카테고리 생성 스키마"""
    id: str = Field(..., min_length=1, max_length=50)

class CategoryUpdate(BaseModel):
    """카테고리 업데이트 스키마"""
    name: Optional[str] = Field(None, min_length=1, max_length=100)
    description: Optional[str] = None
    parent_id: Optional[str] = None
    is_active: Optional[bool] = None
    sort_order: Optional[int] = None

class CategoryResponse(CategoryBase):
    """카테고리 응답 스키마"""
    id: str
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True

class CategoryWithChildren(CategoryResponse):
    """하위 카테고리를 포함한 카테고리 응답 스키마"""
    children: List[CategoryResponse] = []

# 상품 스키마들
class ProductBase(BaseModel):
    """상품 기본 스키마"""
    name: str = Field(..., min_length=1, max_length=200)
    description: Optional[str] = None
    short_description: Optional[str] = Field(None, max_length=500)
    sku: str = Field(..., min_length=1, max_length=100)
    category_id: str = Field(..., min_length=1, max_length=50)
    price: Decimal = Field(..., gt=0, decimal_places=2)
    cost_price: Optional[Decimal] = Field(None, ge=0, decimal_places=2)
    sale_price: Optional[Decimal] = Field(None, ge=0, decimal_places=2)
    stock_quantity: int = Field(default=0, ge=0)
    min_stock_level: int = Field(default=0, ge=0)
    max_stock_level: Optional[int] = Field(None, ge=0)
    is_active: bool = True
    is_featured: bool = False
    is_digital: bool = False
    image_url: Optional[str] = Field(None, max_length=500)
    thumbnail_url: Optional[str] = Field(None, max_length=500)
    gallery_images: Optional[str] = None
    weight: Optional[Decimal] = Field(None, ge=0, decimal_places=3)
    dimensions: Optional[str] = Field(None, max_length=100)
    tags: Optional[str] = None
    meta_title: Optional[str] = Field(None, max_length=200)
    meta_description: Optional[str] = Field(None, max_length=500)
    slug: Optional[str] = Field(None, max_length=200)
    
    @validator('sale_price')
    def validate_sale_price(cls, v, values):
        if v is not None and 'price' in values and v >= values['price']:
            raise ValueError('Sale price must be less than regular price')
        return v
    
    @validator('max_stock_level')
    def validate_max_stock_level(cls, v, values):
        if v is not None and 'min_stock_level' in values and v <= values['min_stock_level']:
            raise ValueError('Max stock level must be greater than min stock level')
        return v

class ProductCreate(ProductBase):
    """상품 생성 스키마"""
    id: str = Field(..., min_length=1, max_length=50)

class ProductUpdate(BaseModel):
    """상품 업데이트 스키마"""
    name: Optional[str] = Field(None, min_length=1, max_length=200)
    description: Optional[str] = None
    short_description: Optional[str] = Field(None, max_length=500)
    category_id: Optional[str] = Field(None, min_length=1, max_length=50)
    price: Optional[Decimal] = Field(None, gt=0, decimal_places=2)
    cost_price: Optional[Decimal] = Field(None, ge=0, decimal_places=2)
    sale_price: Optional[Decimal] = Field(None, ge=0, decimal_places=2)
    stock_quantity: Optional[int] = Field(None, ge=0)
    min_stock_level: Optional[int] = Field(None, ge=0)
    max_stock_level: Optional[int] = Field(None, ge=0)
    is_active: Optional[bool] = None
    is_featured: Optional[bool] = None
    is_digital: Optional[bool] = None
    image_url: Optional[str] = Field(None, max_length=500)
    thumbnail_url: Optional[str] = Field(None, max_length=500)
    gallery_images: Optional[str] = None
    weight: Optional[Decimal] = Field(None, ge=0, decimal_places=3)
    dimensions: Optional[str] = Field(None, max_length=100)
    tags: Optional[str] = None
    meta_title: Optional[str] = Field(None, max_length=200)
    meta_description: Optional[str] = Field(None, max_length=500)
    slug: Optional[str] = Field(None, max_length=200)

class ProductResponse(ProductBase):
    """상품 응답 스키마"""
    id: str
    is_in_stock: bool
    is_low_stock: bool
    effective_price: Decimal
    created_at: datetime
    updated_at: datetime
    category: Optional[CategoryResponse] = None
    
    class Config:
        from_attributes = True

class ProductListResponse(BaseModel):
    """상품 목록 응답 스키마"""
    id: str
    name: str
    short_description: Optional[str]
    sku: str
    price: Decimal
    sale_price: Optional[Decimal]
    effective_price: Decimal
    stock_quantity: int
    is_in_stock: bool
    is_low_stock: bool
    is_featured: bool
    image_url: Optional[str]
    thumbnail_url: Optional[str]
    category_id: str
    created_at: datetime
    
    class Config:
        from_attributes = True

# 페이지네이션 스키마들
class PaginationParams(BaseModel):
    """페이지네이션 파라미터"""
    page: int = Field(default=1, ge=1)
    size: int = Field(default=20, ge=1, le=100)

class PaginatedResponse(BaseModel):
    """페이지네이션 응답 스키마"""
    items: List[dict]
    total: int
    page: int
    size: int
    pages: int
    has_next: bool
    has_prev: bool

# 검색 및 필터 스키마들
class ProductSearchParams(BaseModel):
    """상품 검색 파라미터"""
    q: Optional[str] = None  # 검색어
    category_id: Optional[str] = None
    min_price: Optional[Decimal] = Field(None, ge=0)
    max_price: Optional[Decimal] = Field(None, ge=0)
    in_stock_only: bool = False
    featured_only: bool = False
    sort_by: str = Field(default="created_at", regex="^(name|price|created_at|updated_at|stock_quantity)$")
    sort_order: str = Field(default="desc", regex="^(asc|desc)$")

# 헬스체크 스키마들
class HealthResponse(BaseModel):
    """헬스체크 응답 스키마"""
    service: str
    status: str
    timestamp: datetime
    version: str
    environment: str

class DetailedHealthResponse(HealthResponse):
    """상세 헬스체크 응답 스키마"""
    database: dict
    cache: dict
    dependencies: dict