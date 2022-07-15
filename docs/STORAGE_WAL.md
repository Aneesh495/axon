# Axon Storage Engine and Write-Ahead Log (WAL) Specification

This document details the physical storage layout, append-only WAL binary format, and LSM tree durability mechanisms implemented in Axon.

---

## 1. Binary WAL Record Layout

Every state modification is durably recorded in an append-only binary log before being committed to the in-memory or on-disk storage engine.

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                      Log Sequence Number (LSN)                 |
|                              (64 bits)                        |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                          Timestamp Ms                         |
|                              (64 bits)                        |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|    OpCode     |           Table Name Length (uint32)          |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                   Table Name Bytes (Variable)                 |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                     Record ID Length (uint32)                 |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                    Record ID Bytes (Variable)                 |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                     Payload Length (uint32)                   |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                     Payload Bytes (Variable)                  |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                   CRC32 Checksum (uint32)                     |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

### Field Definitions

1. **LSN (uint64)**: Strictly monotonic sequence number assigned at write time.
2. **Timestamp Ms (uint64)**: Epoch millisecond timestamp of write generation.
3. **OpCode (uint8)**:
   - `0x01`: `PUT` (Insert or update record).
   - `0x02`: `DELETE` (Tombstone deletion).
   - `0x03`: `CHECKPOINT` (Compaction boundary).
4. **Table Name (uint32 length + bytes)**: Target entity table identifier.
5. **Record ID (uint32 length + bytes)**: Unique primary key of the record.
6. **Payload (uint32 length + bytes)**: Serialized entity attribute payload.
7. **CRC32 Checksum (uint32)**: IEEE 802.3 standard polynomial ($0xEDB88320$) calculated over all preceding bytes of the frame.

---

## 2. Crash Recovery Semantics

During restart:
1. The engine reads the latest checkpoint snapshot, restoring table states up to `snapshot_lsn`.
2. The recovery scanner begins parsing WAL frames strictly after `snapshot_lsn`.
3. For each frame, the expected CRC32 checksum is compared against the computed checksum.
4. If a checksum matches, the operation is applied to the in-memory state.
5. If a CRC mismatch or EOF underflow occurs (indicating a power failure torn write), scanning halts cleanly and all previously verified records are retained.

---

## 3. Log-Structured Merge (LSM) Tree and SSTables

Axon includes an LSM Tree storage option for write-heavy workloads:
- **MemTable**: In-memory red-black or skip-list table buffering live writes.
- **Flushing**: When MemTable entries exceed `memtableThreshold` (e.g. 1,000 entries), it is converted into an immutable sorted string table (`SSTable`).
- **Bloom Filters**: Each SSTable constructs an in-memory Bloom filter with optimal $k$-hash functions ($k = \frac{m}{n} \ln 2$), rejecting lookups for non-existent keys in $O(1)$ time without reading the table index.
- **Compaction**: Background compaction merges overlapping SSTables, eliminating superseded versions and discarding dead tombstones.
