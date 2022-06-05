#!/usr/bin/env python3
"""
Axon IPC Bridge: Connects CLI commands and external HTTP clients
to the in-memory or native Axon engine.
"""

import json
import sys
from pathlib import Path


def execute_rebac_check(
    ns: str,
    obj_id: str,
    perm: str,
    subject_str: str,
    policy_path: Path,
) -> bool:
    from runner import (
        CheckEngine,
        MemoryTupleStore,
        RelationTuple,
        Subject,
    )

    with open(policy_path, "r", encoding="utf-8") as f:
        policy_data = json.load(f)

    # Convert policy data to runner format
    policies = {}
    for ns_def in policy_data.get("namespaces", []):
        name = ns_def["name"]
        policies[name] = {}
        for rel_name, rel_rule in ns_def.get("relations", {}).items():
            if "this" in rel_rule:
                policies[name][rel_name] = {"type": "this"}
            elif "union" in rel_rule:
                children = []
                for child in rel_rule["union"]:
                    if "this" in child:
                        children.append({"type": "this"})
                    elif "computed_userset" in child:
                        children.append({
                            "type": "computed_userset",
                            "relation": child["computed_userset"]["relation"],
                        })
                    elif "tuple_to_userset" in child:
                        children.append({
                            "type": "tuple_to_userset",
                            "tupleset": child["tuple_to_userset"]["tupleset"][
                                "relation"
                            ],
                            "computed": child["tuple_to_userset"][
                                "computed_userset"
                            ]["relation"],
                        })
                policies[name][rel_name] = {
                    "type": "union",
                    "children": children,
                }

    store = MemoryTupleStore()
    parts = subject_str.split(":")
    if len(parts) != 2:
        print(
            f"Invalid subject format: {subject_str}. Expected namespace:id",
            file=sys.stderr,
        )
        return False
    sub = Subject(parts[0], parts[1])

    checker = CheckEngine(policies, store)
    return checker.check(ns, obj_id, perm, sub)


if __name__ == "__main__":
    if len(sys.argv) < 5:
        print(
            "Usage: python3 bridge.py <namespace> <object_id> <permission>"
            " <subject>"
        )
        sys.exit(1)
    cfg = (
        Path(__file__).resolve().parent.parent / "config" / "rebac_policy.json"
    )
    res = execute_rebac_check(
        sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], cfg
    )
    print(f"DECISION: {'ALLOW' if res else 'DENY'}")
    sys.exit(0 if res else 2)
