use axum::{
    extract::{State, Json},
    routing::{get, post},
    Router,
    response::IntoResponse,
    http::StatusCode,
};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use sqlx::{postgres::PgPoolOptions, Pool, Postgres};
use std::net::SocketAddr;
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};
use rust_decimal::Decimal;

#[derive(Debug, Deserialize, Serialize)]
struct SignalPayload {
    pair: String,
    action: String,     // "buy" or "sell"
    price: Decimal,
    source: String,     // "TradingView" or similar
}

#[tokio::main]
async fn main() {
    // Initialize tracing
    tracing_subscriber::registry()
        .with(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "cosmocore_ai=debug,tower_http=debug".into()),
        )
        .with(tracing_subscriber::fmt::layer())
        .init();

    // Load environment variables
    dotenvy::dotenv().ok();

    let database_url = std::env::var("DATABASE_URL")
        .expect("DATABASE_URL must be set");

    // Connect to database
    let pool = PgPoolOptions::new()
        .max_connections(5)
        .connect(&database_url)
        .await
        .expect("Failed to connect to Postgres");

    tracing::info!("Connected to Postgres!");

    // Build our application with routes
    let app = Router::new()
        .route("/health", get(health_check))
        .route("/webhook", post(handle_webhook))
        .with_state(pool);

    // Run it
    let addr = SocketAddr::from(([0, 0, 0, 0], 8000));
    tracing::info!("listening on {}", addr);
    let listener = tokio::net::TcpListener::bind(addr).await.unwrap();
    axum::serve(listener, app).await.unwrap();
}

async fn health_check(State(pool): State<Pool<Postgres>>) -> Json<Value> {
    // Basic check to see if we can query the DB
    match sqlx::query("SELECT 1").execute(&pool).await {
        Ok(_) => Json(json!({
            "status": "healthy",
            "database": "connected"
        })),
        Err(e) => {
            tracing::error!("Database health check failed: {}", e);
            Json(json!({
                "status": "unhealthy",
                "database": "disconnected"
            }))
        }
    }
}

async fn handle_webhook(
    State(pool): State<Pool<Postgres>>,
    Json(payload): Json<SignalPayload>,
) -> impl IntoResponse {
    tracing::info!("Received signal: {:?}", payload);

    // Serialize generic payload to JSONB
    let raw_payload = serde_json::to_value(&payload).unwrap_or(Value::Null);

    // Insert into signals table
    // Note: bot_id is nullable in schema, so we can insert without it for now.
    // If logic is needed to associate signal with a specific bot, it would be added here.
    let result = sqlx::query("INSERT INTO signals (pair, action, price, source, raw_payload) VALUES ($1, $2, $3, $4, $5)")
        .bind(payload.pair)
        .bind(payload.action)
        .bind(payload.price)
        .bind(payload.source)
        .bind(raw_payload)
        .execute(&pool)
        .await;

    match result {
        Ok(_) => {
            tracing::info!("Signal saved successfully");
            StatusCode::OK
        }
        Err(e) => {
            tracing::error!("Failed to save signal: {:?}", e);
            StatusCode::INTERNAL_SERVER_ERROR
        }
    }
}
