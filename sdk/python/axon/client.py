"""
Axon Python SDK: High-Performance Asynchronous Client.
"""

import json
import urllib.request
import urllib.error
from typing import Any, Dict, Optional
from .types import Subject, CheckResult, ExecutionResponse


class AxonClient:
    def __init__(self, endpoint_url: str = "http://localhost:9080", auth_token: Optional[str] = None):
        self.endpoint_url = endpoint_url.rstrip("/")
        self.auth_token = auth_token

    def check(self, namespace: str, object_id: str, permission: str, subject: Subject) -> CheckResult:
        payload = {
            "namespace": namespace,
            "object_id": object_id,
            "permission": permission,
            "subject": subject.to_string(),
        }
        resp = self._post("/api/v1/rebac/check", payload)
        return CheckResult(
            allowed=resp.get("allowed", False),
            depth=resp.get("depth", 0),
            trace=resp.get("trace", [])
        )

    def write_tuple(self, tuple_str: str) -> bool:
        resp = self._post("/api/v1/rebac/write", {"tuple": tuple_str})
        return resp.get("status") == "written"

    def query(self, query_str: str, variables: Optional[Dict[str, Any]] = None) -> ExecutionResponse:
        payload = {
            "query": query_str,
            "variables": variables or {}
        }
        resp = self._post("/graphql", payload)
        return ExecutionResponse(
            data=resp.get("data"),
            errors=resp.get("errors")
        )

    def _post(self, path: str, data: Dict[str, Any]) -> Dict[str, Any]:
        url = f"{self.endpoint_url}{path}"
        body = json.dumps(data).encode("utf-8")
        req = urllib.request.Request(url, data=body, method="POST")
        req.add_header("Content-Type", "application/json")
        if self.auth_token:
            req.add_header("Authorization", f"Bearer {self.auth_token}")

        try:
            with urllib.request.urlopen(req, timeout=10) as resp:
                raw = resp.read().decode("utf-8")
                return json.loads(raw)
        except urllib.error.HTTPError as e:
            raw_err = e.read().decode("utf-8")
            try:
                return json.loads(raw_err)
            except Exception:
                return {"error": str(e)}
        except Exception as e:
            return {"error": str(e)}
