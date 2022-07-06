# Axon Relationship-Based Access Control (ReBAC) Specification

This document provides the formal mathematical and algorithmic specification for Axon's Relationship-Based Access Control (ReBAC) engine, derived from the Google Zanzibar authorization architecture.

---

## 1. Formal Model

Let $\mathcal{N}$ be the set of namespaces (e.g. `document`, `workspace`, `organization`).
Let $\mathcal{O} = \mathcal{N} \times \Sigma^*$ be the set of objects, represented as `namespace:id`.
Let $\mathcal{R}$ be the set of relations and permissions (e.g. `owner`, `editor`, `viewer`, `member`).
Let $\mathcal{S}$ be the set of subjects:

$$\mathcal{S} = (\mathcal{N} \times \Sigma^*) \cup (\mathcal{N} \times \Sigma^* \times \mathcal{R})$$

A relation tuple $t \in \mathcal{T}$ is a 4-tuple:

$$t = (n, o, r, s) \quad \text{written as} \quad n:o\#r@s$$

Where:
- $n \in \mathcal{N}$ is the object namespace.
- $o \in \Sigma^*$ is the object identifier.
- $r \in \mathcal{R}$ is the relation name.
- $s \in \mathcal{S}$ is either a concrete subject (e.g. `user:alice`) or a userset indirection (e.g. `group:security#member`).

---

## 2. Userset Rewrite Grammar

Each namespace defines a set of relation rules mapping relation names to rewrite expressions:

$$\text{Rule} ::= \text{This} \mid \text{ComputedUserset}(r) \mid \text{TupleToUserset}(r_{\text{tupleset}}, r_{\text{computed}}) \mid \text{Union}(\text{Rule}^*) \mid \text{Intersection}(\text{Rule}^*) \mid \text{Exclusion}(\text{Rule}, \text{Rule})$$

### Semantics

Given an object $O = (n, o)$ and target subject $u$:

1. **This**:
   $$\text{Eval}(\text{This}, O, u) \iff \exists t \in \mathcal{T} \text{ such that } t = (n, o, r, u) \lor (t = (n, o, r, s') \land \text{Eval}(\text{Rule}(s'), s', u))$$

2. **ComputedUserset($r'$)**:
   $$\text{Eval}(\text{ComputedUserset}(r'), O, u) \iff \text{Eval}(\text{Rule}(n, r'), (n, o), u)$$

3. **TupleToUserset($r_{\text{tupleset}}, r_{\text{computed}}$)**:
   $$\text{Eval}(\text{TupleToUserset}(r_{\text{ts}}, r_{\text{comp}}), O, u) \iff \exists t \in \mathcal{T} \text{ with } t = (n, o, r_{\text{ts}}, (n', o')) \land \text{Eval}(\text{Rule}(n', r_{\text{comp}}), (n', o'), u)$$

4. **Union($R_1, \dots, R_k$)**:
   $$\text{Eval}(\text{Union}(R_1, \dots, R_k), O, u) \iff \bigvee_{i=1}^k \text{Eval}(R_i, O, u)$$

5. **Intersection($R_1, \dots, R_k$)**:
   $$\text{Eval}(\text{Intersection}(R_1, \dots, R_k), O, u) \iff \bigwedge_{i=1}^k \text{Eval}(R_i, O, u)$$

6. **Exclusion($R_{\text{base}}, R_{\text{subtract}}$)**:
   $$\text{Eval}(\text{Exclusion}(R_{\text{base}}, R_{\text{sub}}), O, u) \iff \text{Eval}(R_{\text{base}}, O, u) \land \neg \text{Eval}(R_{\text{sub}}, O, u)$$

---

## 3. Algorithm Complexity & Guarantees

- **Time Complexity**: For an acyclic relationship DAG with maximum fanout $B$ and maximum depth $D$, check evaluation terminates in $O(B^D)$ operations in the worst case, but achieves $O(1)$ amortized evaluation through multi-tier memoization.
- **Space Complexity**: The recursion call stack is strictly bounded by $O(D_{\text{max}})$ frames, where $D_{\text{max}} = 32$ by default.
- **Termination Guarantee**: Given that the visited state set $V$ grows monotonically with every call frame, and $|V| \le |\mathcal{O}| \times |\mathcal{R}| \times |\mathcal{S}| < \infty$, the check algorithm is guaranteed to terminate for all inputs, including cyclic graph topologies.
