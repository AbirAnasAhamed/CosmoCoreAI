use axum::{
    extract::State,
    routing::get,
    Json, Router,
};
use serde_json::{json, Value};
use sqlx::{postgres::PgPoolOptions, Pool, Postgres};
use std::net::SocketAddr;
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

#[tokio::main]
async fn main() {
    // Initialize tracing
    tracing_subscriber::registry()
        .with(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "cosmocore_ai=debug".into()),
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

    // Build our application with a route
    let app = Router::new()
        .route("/health", get(health_check))
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
