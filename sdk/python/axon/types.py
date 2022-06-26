"""
Axon Python SDK: Core Type Definitions.
"""

from dataclasses import dataclass
from typing import Any, Dict, List, Optional


@dataclass
class Subject:
    namespace: str
    id: str
    relation: Optional[str] = None

    def to_string(self) -> str:
        if self.relation:
            return f"{self.namespace}:{self.id}#{self.relation}"
        return f"{self.namespace}:{self.id}"


@dataclass
class CheckResult:
    allowed: bool
    depth: int
    trace: List[str]


@dataclass
class ExecutionResponse:
    data: Optional[Dict[str, Any]]
    errors: Optional[List[str]] = None
