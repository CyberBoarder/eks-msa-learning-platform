from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from typing import List, Optional
import logging

from ..database import get_db
from ..models import Category
from ..schemas import (
    CategoryResponse, 
    CategoryCreate, 
    CategoryUpdate, 
    CategoryWithChildren,
    PaginationParams,
    PaginatedResponse
)
from ..cache import (
    cache_manager, 
    get_category_cache_key, 
    get_categories_list_cache_key
)
from ..config import settings

router = APIRouter()
logger = logging.getLogger(__name__)

@router.get("/", response_model=List[CategoryResponse])
async def get_categories(
    include_inactive: bool = Query(False, description="비활성 카테고리 포함 여부"),
    parent_id: Optional[str] = Query(None, description="부모 카테고리 ID"),
    db: AsyncSession = Depends(get_db)
):
    """카테고리 목록 조회"""
    
    # 캐시 키 생성
    cache_key = f"{get_categories_list_cache_key()}:inactive:{include_inactive}:parent:{parent_id or 'none'}"
    
    # 캐시에서 조회
    cached_result = await cache_manager.get(cache_key)
    if cached_result:
        logger.debug(f"Cache hit for categories list")
        return cached_result
    
    try:
        # 쿼리 구성
        query = select(Category).order_by(Category.sort_order, Category.name)
        
        if not include_inactive:
            query = query.where(Category.is_active == True)
        
        if parent_id is not None:
            query = query.where(Category.parent_id == parent_id)
        
        # 데이터베이스에서 조회
        result = await db.execute(query)
        categories = result.scalars().all()
        
        # 응답 데이터 구성
        response_data = [CategoryResponse.from_orm(category) for category in categories]
        
        # 캐시에 저장
        await cache_manager.set(cache_key, response_data, settings.CACHE_TTL_CATEGORIES)
        
        return response_data
        
    except Exception as e:
        logger.error(f"Error fetching categories: {e}")
        raise HTTPException(status_code=500, detail="Failed to fetch categories")

@router.get("/tree", response_model=List[CategoryWithChildren])
async def get_categories_tree(
    include_inactive: bool = Query(False, description="비활성 카테고리 포함 여부"),
    db: AsyncSession = Depends(get_db)
):
    """계층 구조 카테고리 트리 조회"""
    
    cache_key = f"categories:tree:inactive:{include_inactive}"
    
    # 캐시에서 조회
    cached_result = await cache_manager.get(cache_key)
    if cached_result:
        logger.debug(f"Cache hit for categories tree")
        return cached_result
    
    try:
        # 모든 카테고리 조회
        query = select(Category).order_by(Category.sort_order, Category.name)
        
        if not include_inactive:
            query = query.where(Category.is_active == True)
        
        result = await db.execute(query)
        all_categories = result.scalars().all()
        
        # 카테고리를 딕셔너리로 변환
        categories_dict = {cat.id: cat for cat in all_categories}
        
        # 루트 카테고리들 찾기
        root_categories = []
        
        for category in all_categories:
            if category.parent_id is None:
                # 루트 카테고리
                category_data = CategoryWithChildren.from_orm(category)
                category_data.children = []
                root_categories.append(category_data)
        
        # 하위 카테고리들 추가
        def add_children(parent_category, all_cats_dict):
            for cat_id, cat in all_cats_dict.items():
                if cat.parent_id == parent_category.id:
                    child_data = CategoryWithChildren.from_orm(cat)
                    child_data.children = []
                    add_children(child_data, all_cats_dict)
                    parent_category.children.append(child_data)
        
        for root_cat in root_categories:
            add_children(root_cat, categories_dict)
        
        # 캐시에 저장
        await cache_manager.set(cache_key, root_categories, settings.CACHE_TTL_CATEGORIES)
        
        return root_categories
        
    except Exception as e:
        logger.error(f"Error fetching categories tree: {e}")
        raise HTTPException(status_code=500, detail="Failed to fetch categories tree")

@router.get("/{category_id}", response_model=CategoryResponse)
async def get_category(
    category_id: str,
    db: AsyncSession = Depends(get_db)
):
    """특정 카테고리 조회"""
    
    cache_key = get_category_cache_key(category_id)
    
    # 캐시에서 조회
    cached_result = await cache_manager.get(cache_key)
    if cached_result:
        logger.debug(f"Cache hit for category {category_id}")
        return cached_result
    
    try:
        # 데이터베이스에서 조회
        query = select(Category).where(Category.id == category_id)
        result = await db.execute(query)
        category = result.scalar_one_or_none()
        
        if not category:
            raise HTTPException(status_code=404, detail="Category not found")
        
        response_data = CategoryResponse.from_orm(category)
        
        # 캐시에 저장
        await cache_manager.set(cache_key, response_data, settings.CACHE_TTL_CATEGORIES)
        
        return response_data
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching category {category_id}: {e}")
        raise HTTPException(status_code=500, detail="Failed to fetch category")

@router.post("/", response_model=CategoryResponse, status_code=201)
async def create_category(
    category_data: CategoryCreate,
    db: AsyncSession = Depends(get_db)
):
    """새 카테고리 생성"""
    
    try:
        # 중복 ID 확인
        existing_query = select(Category).where(Category.id == category_data.id)
        existing_result = await db.execute(existing_query)
        if existing_result.scalar_one_or_none():
            raise HTTPException(status_code=409, detail="Category ID already exists")
        
        # 중복 이름 확인
        name_query = select(Category).where(Category.name == category_data.name)
        name_result = await db.execute(name_query)
        if name_result.scalar_one_or_none():
            raise HTTPException(status_code=409, detail="Category name already exists")
        
        # 부모 카테고리 존재 확인
        if category_data.parent_id:
            parent_query = select(Category).where(Category.id == category_data.parent_id)
            parent_result = await db.execute(parent_query)
            if not parent_result.scalar_one_or_none():
                raise HTTPException(status_code=400, detail="Parent category not found")
        
        # 새 카테고리 생성
        new_category = Category(**category_data.dict())
        db.add(new_category)
        await db.commit()
        await db.refresh(new_category)
        
        # 관련 캐시 무효화
        await cache_manager.delete_pattern("categories:*")
        
        return CategoryResponse.from_orm(new_category)
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error creating category: {e}")
        await db.rollback()
        raise HTTPException(status_code=500, detail="Failed to create category")

@router.put("/{category_id}", response_model=CategoryResponse)
async def update_category(
    category_id: str,
    category_data: CategoryUpdate,
    db: AsyncSession = Depends(get_db)
):
    """카테고리 정보 업데이트"""
    
    try:
        # 기존 카테고리 조회
        query = select(Category).where(Category.id == category_id)
        result = await db.execute(query)
        category = result.scalar_one_or_none()
        
        if not category:
            raise HTTPException(status_code=404, detail="Category not found")
        
        # 이름 중복 확인 (다른 카테고리와)
        if category_data.name and category_data.name != category.name:
            name_query = select(Category).where(
                Category.name == category_data.name,
                Category.id != category_id
            )
            name_result = await db.execute(name_query)
            if name_result.scalar_one_or_none():
                raise HTTPException(status_code=409, detail="Category name already exists")
        
        # 부모 카테고리 존재 확인
        if category_data.parent_id:
            if category_data.parent_id == category_id:
                raise HTTPException(status_code=400, detail="Category cannot be its own parent")
            
            parent_query = select(Category).where(Category.id == category_data.parent_id)
            parent_result = await db.execute(parent_query)
            if not parent_result.scalar_one_or_none():
                raise HTTPException(status_code=400, detail="Parent category not found")
        
        # 업데이트할 필드들 적용
        update_data = category_data.dict(exclude_unset=True)
        for field, value in update_data.items():
            setattr(category, field, value)
        
        await db.commit()
        await db.refresh(category)
        
        # 관련 캐시 무효화
        await cache_manager.delete(get_category_cache_key(category_id))
        await cache_manager.delete_pattern("categories:*")
        
        return CategoryResponse.from_orm(category)
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error updating category {category_id}: {e}")
        await db.rollback()
        raise HTTPException(status_code=500, detail="Failed to update category")

@router.delete("/{category_id}")
async def delete_category(
    category_id: str,
    force: bool = Query(False, description="하위 카테고리가 있어도 강제 삭제"),
    db: AsyncSession = Depends(get_db)
):
    """카테고리 삭제"""
    
    try:
        # 기존 카테고리 조회
        query = select(Category).where(Category.id == category_id)
        result = await db.execute(query)
        category = result.scalar_one_or_none()
        
        if not category:
            raise HTTPException(status_code=404, detail="Category not found")
        
        # 하위 카테고리 확인
        children_query = select(func.count(Category.id)).where(Category.parent_id == category_id)
        children_result = await db.execute(children_query)
        children_count = children_result.scalar()
        
        if children_count > 0 and not force:
            raise HTTPException(
                status_code=400, 
                detail="Cannot delete category with subcategories. Use force=true to delete anyway."
            )
        
        # 상품이 있는지 확인 (실제로는 Product 모델과 관계 확인 필요)
        # 여기서는 간단히 처리
        
        if force and children_count > 0:
            # 하위 카테고리들의 parent_id를 null로 설정하거나 삭제
            children_update_query = select(Category).where(Category.parent_id == category_id)
            children_result = await db.execute(children_update_query)
            children = children_result.scalars().all()
            
            for child in children:
                child.parent_id = None
        
        # 카테고리 삭제
        await db.delete(category)
        await db.commit()
        
        # 관련 캐시 무효화
        await cache_manager.delete(get_category_cache_key(category_id))
        await cache_manager.delete_pattern("categories:*")
        
        return {"message": "Category deleted successfully"}
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error deleting category {category_id}: {e}")
        await db.rollback()
        raise HTTPException(status_code=500, detail="Failed to delete category")