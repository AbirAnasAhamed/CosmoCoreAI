-- --------------------------------------------------------
-- PostgreSQL Database Schema for SaaS Crypto Trading Bot
-- Role: Senior Database Architect
-- Purpose: Support Signal-based and DCA trading strategies
-- --------------------------------------------------------

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Enums
CREATE TYPE subscription_tier_type AS ENUM ('FREE', 'PRO', 'ENTERPRISE');
CREATE TYPE account_status_type AS ENUM ('ACTIVE', 'SUSPENDED', 'PENDING');
CREATE TYPE strategy_type_enum AS ENUM ('SIGNAL', 'DCA', 'GRID');
CREATE TYPE bot_status_type AS ENUM ('ACTIVE', 'PAUSED', 'STOPPED');
CREATE TYPE order_side_type AS ENUM ('BUY', 'SELL');
CREATE TYPE order_status_type AS ENUM ('PENDING', 'FILLED', 'CANCELLED', 'FAILED');

-- Users Table
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    subscription_tier subscription_tier_type NOT NULL DEFAULT 'FREE',
    account_status account_status_type NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Exchange Keys Table
CREATE TABLE exchange_keys (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    exchange_name VARCHAR(50) NOT NULL,
    api_key VARCHAR(255) NOT NULL,
    api_secret_encrypted TEXT NOT NULL,
    label VARCHAR(100),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_user_exchange_api_key UNIQUE (user_id, api_key)
);

-- Bot Configuration Table
CREATE TABLE bots (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    exchange_key_id UUID NOT NULL REFERENCES exchange_keys(id),
    name VARCHAR(100) NOT NULL,
    strategy_type strategy_type_enum NOT NULL DEFAULT 'DCA',
    pair VARCHAR(20) NOT NULL,
    base_order_size NUMERIC(20, 8) NOT NULL,
    safety_order_size NUMERIC(20, 8) DEFAULT 0,
    max_safety_orders INTEGER DEFAULT 0,
    price_deviation_percent NUMERIC(5, 2) DEFAULT 1.0,
    take_profit_percent NUMERIC(5, 2) NOT NULL,
    stop_loss_percent NUMERIC(5, 2),
    status bot_status_type NOT NULL DEFAULT 'PAUSED',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Signals Table
CREATE TABLE signals (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    bot_id UUID REFERENCES bots(id) ON DELETE SET NULL,
    pair VARCHAR(20) NOT NULL,
    action VARCHAR(10) NOT NULL,
    price NUMERIC(20, 8),
    signal_timestamp TIMESTAMPTZ DEFAULT NOW(),
    source VARCHAR(50) NOT NULL,
    raw_payload JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Orders / Trades Table
CREATE TABLE orders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    bot_id UUID NOT NULL REFERENCES bots(id) ON DELETE CASCADE,
    exchange_order_id VARCHAR(100),
    pair VARCHAR(20) NOT NULL,
    side order_side_type NOT NULL,
    price NUMERIC(20, 8) NOT NULL,
    quantity NUMERIC(20, 8) NOT NULL,
    fee NUMERIC(20, 8) DEFAULT 0,
    status order_status_type NOT NULL DEFAULT 'PENDING',
    pnl NUMERIC(20, 8) DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_exchange_keys_user_id ON exchange_keys(user_id);
CREATE INDEX idx_bots_user_id ON bots(user_id);
CREATE INDEX idx_bots_status ON bots(status);
CREATE INDEX idx_signals_pair_created ON signals(pair, created_at DESC);
CREATE INDEX idx_orders_bot_id ON orders(bot_id);
CREATE INDEX idx_orders_status ON orders(status);