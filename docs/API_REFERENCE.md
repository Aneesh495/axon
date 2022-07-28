# Axon API Reference

This document provides complete documentation for Axon's HTTP REST endpoints, GraphQL gateway, and administrative CLI tools.

---

## 1. HTTP REST Endpoints

### 1.1 Check Permission
Evaluate whether a subject possesses a specific permission on an object.

- **Method**: `POST`
- **Path**: `/api/v1/rebac/check`
- **Headers**: `Content-Type: application/json`
- **Request Body**:
```json
{
  "namespace": "document",
  "object_id": "doc-runbook",
  "permission": "viewer",
  "subject": "user:usr-alice"
}
```
- **Response** (`200 OK`):
```json
{
  "allowed": true,
  "depth": 3,
  "trace": [
    "Evaluated document:doc-runbook#viewer via parent_workspace",
    "Matched workspace:ws-infra#viewer via organization:org-alpha#member"
  ]
}
```

---

### 1.2 Expand Userset Tree
Inspect the complete resolution tree for an object's relation.

- **Method**: `POST`
- **Path**: `/api/v1/rebac/expand`
- **Request Body**:
```json
{
  "namespace": "workspace",
  "object_id": "ws-infra",
  "relation": "member"
}
```
- **Response** (`200 OK`):
```json
{
  "type": "UNION",
  "children_count": 2
}
```

---

### 1.3 Write Relation Tuple
Durably insert a new relationship assertion.

- **Method**: `POST`
- **Path**: `/api/v1/rebac/write`
- **Request Body**:
```json
{
  "tuple": "document:doc-101#viewer@user:usr-bob"
}
```
- **Response** (`201 Created`):
```json
{
  "status": "written",
  "tuple": "document:doc-101#viewer@user:usr-bob"
}
```

---

## 2. GraphQL Gateway

- **Method**: `POST`
- **Path**: `/graphql`
- **Request Body**:
```json
{
  "query": "query GetDocument($id: ID!) { Document(id: $id) { title owner { username } } }",
  "variables": { "id": "doc-101" }
}
```
- **Response** (`200 OK`):
```json
{
  "data": {
    "Document": {
      "title": "Production Runbook",
      "owner": {
        "username": "alice"
      }
    }
  }
}
```

---

## 3. Observability Endpoints

- `GET /healthz`: Returns JSON service health status (`{"status":"healthy"}`).
- `GET /metrics`: Returns OpenMetrics / Prometheus scrape format metrics.

---

## 4. Unified CLI Commands

```bash
# Evaluate access permission
axon check document doc-101 viewer user:alice

# Execute a GraphQL query
axon query '{ Document(id: "doc-1") { title } }'

# Run micro-benchmarks
axon bench 50000

# Export schema as Mermaid class diagram
axon graphviz mermaid

# Start HTTP service daemon
axon server 9080
```
