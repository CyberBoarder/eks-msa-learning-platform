from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, or_, and_
from sqlalchemy.orm import selectinload
from typing import List, Optional
from decimal import Decimal
import logging

from ..database import get_db
from ..models import Product, Category
from ..schemas import (
    ProductResponse,
    ProductListResponse, 
    ProductCreate, 
    ProductUpdate,
    ProductSearchParams,
    PaginationParams,
    PaginatedResponse
)
from ..cache import (
    cache_manager, 
    get_product_cache_key, 
    get_products_list_cache_key
)
from ..config import settings

router = APIRouter()
logger = logging.getLogger(__name__)

@router.get("/", response_model=PaginatedResponse)
async def get_products(
    page: int = Query(1, ge=1, description="페이지 번호"),
    size: int = Query(20, ge=1, le=100, description="페이지 크기"),
    category_id: Optional[str] = Query(None, description="카테고리 ID"),
    search: Optional[str] = Query(None, description="검색어"),
    min_price: Optional[Decimal] = Query(None, ge=0, description="최소 가격"),
    max_price: Optional[Decimal] = Query(None, ge=0, description="최대 가격"),
    in_stock_only: bool = Query(False, description="재고 있는 상품만"),
    featured_only: bool = Query(False, description="추천 상품만"),
    active_only: bool = Query(True, description="활성 상품만"),
    sort_by: str = Query("created_at", regex="^(name|price|created_at|updated_at|stock_quantity)$"),
    sort_order: str = Query("desc", regex="^(asc|desc)$"),
    db: AsyncSession = Depends(get_db)
):
    """상품 목록 조회 (페이지네이션 포함)"""
    
    # 캐시 키 생성
    cache_key = get_products_list_cache_key(
        category_id=category_id,
        search=search,
        page=page,
        size=size,
        min_price=min_price,
        max_price=max_price,
        in_stock_only=in_stock_only,
        featured_only=featured_only,
        active_only=active_only,
        sort_by=sort_by,
        sort_order=sort_order
    )
    
    # 캐시에서 조회
    cached_result = await cache_manager.get(cache_key)
    if cached_result:
        logger.debug(f"Cache hit for products list")
        return cached_result
    
    try:
        # 기본 쿼리 구성
        query = select(Product)
        count_query = select(func.count(Product.id))
        
        # 필터 조건 적용
        conditions = []
        
        if active_only:
            conditions.append(Product.is_active == True)
        
        if category_id:
            conditions.append(Product.category_id == category_id)
        
        if search:
            search_condition = or_(
                Product.name.ilike(f"%{search}%"),
                Product.description.ilike(f"%{search}%"),
                Product.short_description.ilike(f"%{search}%"),
                Product.sku.ilike(f"%{search}%")
            )
            conditions.append(search_condition)
        
        if min_price is not None:
            conditions.append(Product.price >= min_price)
        
        if max_price is not None:
            conditions.append(Product.price <= max_price)
        
        if in_stock_only:
            conditions.append(Product.stock_quantity > 0)
        
        if featured_only:
            conditions.append(Product.is_featured == True)
        
        # 조건들을 쿼리에 적용
        if conditions:
            query = query.where(and_(*conditions))
            count_query = count_query.where(and_(*conditions))
        
        # 정렬 적용
        sort_column = getattr(Product, sort_by)
        if sort_order == "desc":
            query = query.order_by(sort_column.desc())
        else:
            query = query.order_by(sort_column.asc())
        
        # 페이지네이션 적용
        offset = (page - 1) * size
        query = query.offset(offset).limit(size)
        
        # 데이터 조회
        result = await db.execute(query)
        products = result.scalars().all()
        
        # 총 개수 조회
        count_result = await db.execute(count_query)
        total = count_result.scalar()
        
        # 응답 데이터 구성
        items = [ProductListResponse.from_orm(product) for product in products]
        
        pages = (total + size - 1) // size
        response_data = PaginatedResponse(
            items=items,
            total=total,
            page=page,
            size=size,
            pages=pages,
            has_next=page < pages,
            has_prev=page > 1
        )
        
        # 캐시에 저장
        await cache_manager.set(cache_key, response_data, settings.CACHE_TTL_PRODUCTS)
        
        return response_data
        
    except Exception as e:
        logger.error(f"Error fetching products: {e}")
        raise HTTPException(status_code=500, detail="Failed to fetch products")

@router.get("/{product_id}", response_model=ProductResponse)
async def get_product(
    product_id: str,
    db: AsyncSession = Depends(get_db)
):
    """특정 상품 상세 조회"""
    
    cache_key = get_product_cache_key(product_id)
    
    # 캐시에서 조회
    cached_result = await cache_manager.get(cache_key)
    if cached_result:
        logger.debug(f"Cache hit for product {product_id}")
        return cached_result
    
    try:
        # 카테고리 정보와 함께 조회
        query = select(Product).options(selectinload(Product.category)).where(Product.id == product_id)
        result = await db.execute(query)
        product = result.scalar_one_or_none()
        
        if not product:
            raise HTTPException(status_code=404, detail="Product not found")
        
        response_data = ProductResponse.from_orm(product)
        
        # 캐시에 저장
        await cache_manager.set(cache_key, response_data, settings.CACHE_TTL_PRODUCT_DETAIL)
        
        return response_data
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching product {product_id}: {e}")
        raise HTTPException(status_code=500, detail="Failed to fetch product")

@router.post("/", response_model=ProductResponse, status_code=201)
async def create_product(
    product_data: ProductCreate,
    db: AsyncSession = Depends(get_db)
):
    """새 상품 생성"""
    
    try:
        # 중복 ID 확인
        existing_query = select(Product).where(Product.id == product_data.id)
        existing_result = await db.execute(existing_query)
        if existing_result.scalar_one_or_none():
            raise HTTPException(status_code=409, detail="Product ID already exists")
        
        # 중복 SKU 확인
        sku_query = select(Product).where(Product.sku == product_data.sku)
        sku_result = await db.execute(sku_query)
        if sku_result.scalar_one_or_none():
            raise HTTPException(status_code=409, detail="Product SKU already exists")
        
        # 카테고리 존재 확인
        category_query = select(Category).where(Category.id == product_data.category_id)
        category_result = await db.execute(category_query)
        if not category_result.scalar_one_or_none():
            raise HTTPException(status_code=400, detail="Category not found")
        
        # slug 자동 생성 (제공되지 않은 경우)
        if not product_data.slug:
            product_data.slug = product_data.name.lower().replace(" ", "-").replace("_", "-")
        
        # 새 상품 생성
        new_product = Product(**product_data.dict())
        db.add(new_product)
        await db.commit()
        await db.refresh(new_product)
        
        # 관련 캐시 무효화
        await cache_manager.delete_pattern("products:*")
        
        # 카테고리 정보와 함께 응답
        query = select(Product).options(selectinload(Product.category)).where(Product.id == new_product.id)
        result = await db.execute(query)
        product_with_category = result.scalar_one()
        
        return ProductResponse.from_orm(product_with_category)
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error creating product: {e}")
        await db.rollback()
        raise HTTPException(status_code=500, detail="Failed to create product")

@router.put("/{product_id}", response_model=ProductResponse)
async def update_product(
    product_id: str,
    product_data: ProductUpdate,
    db: AsyncSession = Depends(get_db)
):
    """상품 정보 업데이트"""
    
    try:
        # 기존 상품 조회
        query = select(Product).where(Product.id == product_id)
        result = await db.execute(query)
        product = result.scalar_one_or_none()
        
        if not product:
            raise HTTPException(status_code=404, detail="Product not found")
        
        # SKU 중복 확인 (다른 상품과)
        if product_data.sku and product_data.sku != product.sku:
            sku_query = select(Product).where(
                Product.sku == product_data.sku,
                Product.id != product_id
            )
            sku_result = await db.execute(sku_query)
            if sku_result.scalar_one_or_none():
                raise HTTPException(status_code=409, detail="Product SKU already exists")
        
        # 카테고리 존재 확인
        if product_data.category_id:
            category_query = select(Category).where(Category.id == product_data.category_id)
            category_result = await db.execute(category_query)
            if not category_result.scalar_one_or_none():
                raise HTTPException(status_code=400, detail="Category not found")
        
        # 업데이트할 필드들 적용
        update_data = product_data.dict(exclude_unset=True)
        for field, value in update_data.items():
            setattr(product, field, value)
        
        await db.commit()
        await db.refresh(product)
        
        # 관련 캐시 무효화
        await cache_manager.delete(get_product_cache_key(product_id))
        await cache_manager.delete_pattern("products:*")
        
        # 카테고리 정보와 함께 응답
        query = select(Product).options(selectinload(Product.category)).where(Product.id == product_id)
        result = await db.execute(query)
        product_with_category = result.scalar_one()
        
        return ProductResponse.from_orm(product_with_category)
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error updating product {product_id}: {e}")
        await db.rollback()
        raise HTTPException(status_code=500, detail="Failed to update product")

@router.delete("/{product_id}")
async def delete_product(
    product_id: str,
    db: AsyncSession = Depends(get_db)
):
    """상품 삭제"""
    
    try:
        # 기존 상품 조회
        query = select(Product).where(Product.id == product_id)
        result = await db.execute(query)
        product = result.scalar_one_or_none()
        
        if not product:
            raise HTTPException(status_code=404, detail="Product not found")
        
        # 상품 삭제
        await db.delete(product)
        await db.commit()
        
        # 관련 캐시 무효화
        await cache_manager.delete(get_product_cache_key(product_id))
        await cache_manager.delete_pattern("products:*")
        
        return {"message": "Product deleted successfully"}
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error deleting product {product_id}: {e}")
        await db.rollback()
        raise HTTPException(status_code=500, detail="Failed to delete product")

@router.patch("/{product_id}/stock")
async def update_product_stock(
    product_id: str,
    quantity: int = Query(..., description="재고 수량"),
    operation: str = Query("set", regex="^(set|add|subtract)$", description="재고 조작 방식"),
    db: AsyncSession = Depends(get_db)
):
    """상품 재고 업데이트"""
    
    try:
        # 기존 상품 조회
        query = select(Product).where(Product.id == product_id)
        result = await db.execute(query)
        product = result.scalar_one_or_none()
        
        if not product:
            raise HTTPException(status_code=404, detail="Product not found")
        
        # 재고 업데이트
        if operation == "set":
            product.stock_quantity = quantity
        elif operation == "add":
            product.stock_quantity += quantity
        elif operation == "subtract":
            new_quantity = product.stock_quantity - quantity
            if new_quantity < 0:
                raise HTTPException(status_code=400, detail="Insufficient stock")
            product.stock_quantity = new_quantity
        
        await db.commit()
        await db.refresh(product)
        
        # 관련 캐시 무효화
        await cache_manager.delete(get_product_cache_key(product_id))
        await cache_manager.delete_pattern("products:*")
        
        return {
            "message": "Stock updated successfully",
            "product_id": product_id,
            "new_stock_quantity": product.stock_quantity,
            "is_in_stock": product.is_in_stock,
            "is_low_stock": product.is_low_stock
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error updating stock for product {product_id}: {e}")
        await db.rollback()
        raise HTTPException(status_code=500, detail="Failed to update stock")

@router.get("/category/{category_id}", response_model=PaginatedResponse)
async def get_products_by_category(
    category_id: str,
    page: int = Query(1, ge=1),
    size: int = Query(20, ge=1, le=100),
    active_only: bool = Query(True),
    in_stock_only: bool = Query(False),
    sort_by: str = Query("created_at", regex="^(name|price|created_at|updated_at|stock_quantity)$"),
    sort_order: str = Query("desc", regex="^(asc|desc)$"),
    db: AsyncSession = Depends(get_db)
):
    """특정 카테고리의 상품 목록 조회"""
    
    # 카테고리 존재 확인
    category_query = select(Category).where(Category.id == category_id)
    category_result = await db.execute(category_query)
    if not category_result.scalar_one_or_none():
        raise HTTPException(status_code=404, detail="Category not found")
    
    # 상품 목록 조회 (기존 get_products 로직 재사용)
    return await get_products(
        page=page,
        size=size,
        category_id=category_id,
        active_only=active_only,
        in_stock_only=in_stock_only,
        sort_by=sort_by,
        sort_order=sort_order,
        db=db
    )