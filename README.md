# 🚀 OpenResty API Gateway Pattern

This repository provides a complete, runnable Docker-based example of a high-performance, secure API gateway architecture using **OpenResty**, **Lua**, and **Redis**.

It demonstrates a modern approach where the gateway acts as an intelligent, central controller for authentication, caching, and security, simplifying backend microservices.

> *Note: A live, interactive version of this animation is available in `animation/index.html`.*

---

## ✨ Core Concepts Illustrated

This project is a practical demonstration of several powerful, modern architectural patterns:

* **🛡️ JWT Authentication at the Edge:** All JWT validation (`RS256`) happens within OpenResty. Backend services are completely decoupled from authentication logic and simply trust incoming requests from the gateway.

* **👮 Layered Security (WAF):** A conceptual Web Application Firewall (WAF) node is included in the flow to represent a layered security approach, inspecting all traffic before it reaches the core logic.

* **⚡ Intelligent Payload Caching:** To avoid expensive cryptographic operations on every request, the validated JWT payload is cached in Redis. Subsequent requests for the same token hit the cache and are processed almost instantly.

* **🛑 Secure Token Revocation:** On logout, the token's unique identifier (`jti`) is added to a Redis revocation list. The gateway checks this list on every request, ensuring that revoked tokens are immediately rejected.

* **💨 Gateway-Direct Responses:** For certain endpoints (like `/api/cart`), a Lua script in OpenResty fetches data *directly* from Redis and serves the response to the client. The request never hits a backend service, resulting in minimal latency.

---

## 💻 Technology Stack

* **API Gateway:** [OpenResty](https://openresty.org/) (NGINX + LuaJIT)
* **Caching & Revocation:** [Redis](https://redis.io/)
* **Services:** [HonoJS](https://hono.dev/) on Node.js
* **Containerization:** [Docker](https://www.docker.com/) & [Docker Compose](https://docs.docker.com/compose/)
* **Authentication:** JSON Web Tokens (JWT) with `RS256`

---

## 🚀 Getting Started

### Prerequisites

* [Docker](https://www.docker.com/products/docker-desktop)
* [Docker Compose](https://docs.docker.com/compose/install/)
* [OpenSSL](https://www.openssl.org/) (usually pre-installed on Linux/macOS)

### 1. Clone the Repository

```
git clone <your-repo-url>
cd openresty-jwt-gateway
```

### 2. Generate RSA Keys

The authentication service uses a private key to sign tokens, and OpenResty uses the corresponding public key to verify them.


# Generate the private key

```bash
openssl genpkey -algorithm RSA -out ./auth-service/private_key.pem -pkeyopt rsa_keygen_bits:2048
```

# Extract the public key

```bash
openssl rsa -pubout -in ./auth-service/private_key.pem -out ./openresty/public_key.pem
```

### 3. Build and Run Services

This single command will build all the service images and start the containers.

```bash
docker-compose up --build
```

The API gateway will be available at `http://localhost:8080`.

---

## 🧪 Usage & Testing the Flow

Follow these steps in a new terminal to interact with the system.

#### **A. Login & Get a Token**

```
TOKEN=$(curl -s -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username": "alice", "password": "password123"}' | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)

echo "TOKEN: $TOKEN"
```

#### **B. Access a Protected Endpoint (Cache Miss)**

```
curl -i -H "Authorization: Bearer $TOKEN" http://localhost:8080/api/protected/
```

#### **C. Access it Again (Cache Hit)**

```
curl -i -H "Authorization: Bearer $TOKEN" http://localhost:8080/api/protected/
```

#### **D. Access Data Directly from Redis**

```
curl -H "Authorization: Bearer $TOKEN" http://localhost:8080/api/cart/user-1
```

#### **E. Logout (Revoke the Token)**

```
curl -X POST -H "Authorization: Bearer $TOKEN" http://localhost:8080/api/auth/logout
```

#### **F. Attempt to Use the Revoked Token**

```
curl -i -H "Authorization: Bearer $TOKEN" http://localhost:8080/api/protected/
```

---

## 📂 Project Structure

```
.
├── auth-service/
│   ├── src/index.js
│   ├── Dockerfile
│   ├── package.json
│   └── private_key.pem
│
├── backend-protected/
│   ├── src/index.js
│   ├── Dockerfile
│   └── package.json
│
├── backend-public/
│   ├── src/index.js
│   ├── Dockerfile
│   └── package.json
│
├── openresty/
│   ├── Dockerfile
│   ├── cart_handler.lua
│   ├── jwt_validation.lua
│   ├── nginx.conf
│   └── public_key.pem
│
└── docker-compose.yml
```

---
