from sqlalchemy import Column, Integer, String, Text, Numeric, DateTime, Boolean, ForeignKey, Index
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from datetime import datetime
from typing import Optional

from .database import Base

class Category(Base):
    """상품 카테고리 모델"""
    __tablename__ = "categories"
    
    id = Column(String(50), primary_key=True)
    name = Column(String(100), nullable=False, unique=True)
    description = Column(Text)
    parent_id = Column(String(50), ForeignKey("categories.id"), nullable=True)
    is_active = Column(Boolean, default=True, nullable=False)
    sort_order = Column(Integer, default=0)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
    
    # 관계 설정
    parent = relationship("Category", remote_side="Category.id", back_populates="children")
    children = relationship("Category", back_populates="parent")
    products = relationship("Product", back_populates="category")
    
    # 인덱스 설정
    __table_args__ = (
        Index("idx_category_name", "name"),
        Index("idx_category_parent", "parent_id"),
        Index("idx_category_active", "is_active"),
    )
    
    def __repr__(self):
        return f"<Category(id='{self.id}', name='{self.name}')>"

class Product(Base):
    """상품 모델"""
    __tablename__ = "products"
    
    id = Column(String(50), primary_key=True)
    name = Column(String(200), nullable=False)
    description = Column(Text)
    short_description = Column(String(500))
    sku = Column(String(100), unique=True, nullable=False)
    category_id = Column(String(50), ForeignKey("categories.id"), nullable=False)
    
    # 가격 정보
    price = Column(Numeric(10, 2), nullable=False)
    cost_price = Column(Numeric(10, 2))
    sale_price = Column(Numeric(10, 2))
    
    # 재고 정보
    stock_quantity = Column(Integer, default=0, nullable=False)
    min_stock_level = Column(Integer, default=0)
    max_stock_level = Column(Integer)
    
    # 상품 상태
    is_active = Column(Boolean, default=True, nullable=False)
    is_featured = Column(Boolean, default=False)
    is_digital = Column(Boolean, default=False)
    
    # 이미지 정보
    image_url = Column(String(500))
    thumbnail_url = Column(String(500))
    gallery_images = Column(Text)  # JSON 형태로 저장
    
    # 메타데이터
    weight = Column(Numeric(8, 3))  # kg 단위
    dimensions = Column(String(100))  # "길이x너비x높이" 형태
    tags = Column(Text)  # 쉼표로 구분된 태그들
    
    # SEO 정보
    meta_title = Column(String(200))
    meta_description = Column(String(500))
    slug = Column(String(200), unique=True)
    
    # 시간 정보
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
    
    # 관계 설정
    category = relationship("Category", back_populates="products")
    
    # 인덱스 설정
    __table_args__ = (
        Index("idx_product_name", "name"),
        Index("idx_product_sku", "sku"),
        Index("idx_product_category", "category_id"),
        Index("idx_product_active", "is_active"),
        Index("idx_product_featured", "is_featured"),
        Index("idx_product_price", "price"),
        Index("idx_product_stock", "stock_quantity"),
        Index("idx_product_created", "created_at"),
    )
    
    @property
    def is_in_stock(self) -> bool:
        """재고 여부 확인"""
        return self.stock_quantity > 0
    
    @property
    def is_low_stock(self) -> bool:
        """재고 부족 여부 확인"""
        return self.stock_quantity <= self.min_stock_level
    
    @property
    def effective_price(self) -> float:
        """실제 판매 가격 (세일 가격이 있으면 세일 가격, 없으면 정가)"""
        return float(self.sale_price) if self.sale_price else float(self.price)
    
    def __repr__(self):
        return f"<Product(id='{self.id}', name='{self.name}', sku='{self.sku}')>"