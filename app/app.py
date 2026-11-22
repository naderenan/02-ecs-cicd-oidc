"""Tiny product-catalog microservice used to demo ECS Fargate + OIDC CI/CD."""
import os
import socket
import time

from flask import Flask, jsonify

app = Flask(__name__)
STARTED = time.time()
VERSION = os.getenv("APP_VERSION", "dev")

PRODUCTS = [
    {"id": 1, "name": "Canvas Tote", "price": 19.99},
    {"id": 2, "name": "Coffee Mug", "price": 12.50},
    {"id": 3, "name": "Desk Lamp", "price": 34.00},
]


@app.get("/")
def index():
    return jsonify(
        service="catalog",
        version=VERSION,
        host=socket.gethostname(),
        uptime_seconds=int(time.time() - STARTED),
    )


@app.get("/health")
def health():
    return jsonify(status="ok"), 200


@app.get("/products")
def products():
    return jsonify(PRODUCTS)


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.getenv("PORT", "8080")))
