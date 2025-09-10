"""Initial migration - Create categories and products tables

Revision ID: 001
Revises: 
Create Date: 2024-01-01 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision = '001'
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Create categories table
    op.create_table('categories',
        sa.Column('id', sa.String(length=50), nullable=False),
        sa.Column('name', sa.String(length=100), nullable=False),
        sa.Column('description', sa.Text(), nullable=True),
        sa.Column('parent_id', sa.String(length=50), nullable=True),
        sa.Column('is_active', sa.Boolean(), nullable=False, default=True),
        sa.Column('sort_order', sa.Integer(), nullable=True, default=0),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=True),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=True),
        sa.ForeignKeyConstraint(['parent_id'], ['categories.id'], ),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('name')
    )
    
    # Create indexes for categories
    op.create_index('idx_category_name', 'categories', ['name'], unique=False)
    op.create_index('idx_category_parent', 'categories', ['parent_id'], unique=False)
    op.create_index('idx_category_active', 'categories', ['is_active'], unique=False)

    # Create products table
    op.create_table('products',
        sa.Column('id', sa.String(length=50), nullable=False),
        sa.Column('name', sa.String(length=200), nullable=False),
        sa.Column('description', sa.Text(), nullable=True),
        sa.Column('short_description', sa.String(length=500), nullable=True),
        sa.Column('sku', sa.String(length=100), nullable=False),
        sa.Column('category_id', sa.String(length=50), nullable=False),
        sa.Column('price', sa.Numeric(precision=10, scale=2), nullable=False),
        sa.Column('cost_price', sa.Numeric(precision=10, scale=2), nullable=True),
        sa.Column('sale_price', sa.Numeric(precision=10, scale=2), nullable=True),
        sa.Column('stock_quantity', sa.Integer(), nullable=False, default=0),
        sa.Column('min_stock_level', sa.Integer(), nullable=True, default=0),
        sa.Column('max_stock_level', sa.Integer(), nullable=True),
        sa.Column('is_active', sa.Boolean(), nullable=False, default=True),
        sa.Column('is_featured', sa.Boolean(), nullable=True, default=False),
        sa.Column('is_digital', sa.Boolean(), nullable=True, default=False),
        sa.Column('image_url', sa.String(length=500), nullable=True),
        sa.Column('thumbnail_url', sa.String(length=500), nullable=True),
        sa.Column('gallery_images', sa.Text(), nullable=True),
        sa.Column('weight', sa.Numeric(precision=8, scale=3), nullable=True),
        sa.Column('dimensions', sa.String(length=100), nullable=True),
        sa.Column('tags', sa.Text(), nullable=True),
        sa.Column('meta_title', sa.String(length=200), nullable=True),
        sa.Column('meta_description', sa.String(length=500), nullable=True),
        sa.Column('slug', sa.String(length=200), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=True),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=True),
        sa.ForeignKeyConstraint(['category_id'], ['categories.id'], ),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('sku'),
        sa.UniqueConstraint('slug')
    )
    
    # Create indexes for products
    op.create_index('idx_product_name', 'products', ['name'], unique=False)
    op.create_index('idx_product_sku', 'products', ['sku'], unique=False)
    op.create_index('idx_product_category', 'products', ['category_id'], unique=False)
    op.create_index('idx_product_active', 'products', ['is_active'], unique=False)
    op.create_index('idx_product_featured', 'products', ['is_featured'], unique=False)
    op.create_index('idx_product_price', 'products', ['price'], unique=False)
    op.create_index('idx_product_stock', 'products', ['stock_quantity'], unique=False)
    op.create_index('idx_product_created', 'products', ['created_at'], unique=False)


def downgrade() -> None:
    # Drop products table and its indexes
    op.drop_index('idx_product_created', table_name='products')
    op.drop_index('idx_product_stock', table_name='products')
    op.drop_index('idx_product_price', table_name='products')
    op.drop_index('idx_product_featured', table_name='products')
    op.drop_index('idx_product_active', table_name='products')
    op.drop_index('idx_product_category', table_name='products')
    op.drop_index('idx_product_sku', table_name='products')
    op.drop_index('idx_product_name', table_name='products')
    op.drop_table('products')
    
    # Drop categories table and its indexes
    op.drop_index('idx_category_active', table_name='categories')
    op.drop_index('idx_category_parent', table_name='categories')
    op.drop_index('idx_category_name', table_name='categories')
    op.drop_table('categories')