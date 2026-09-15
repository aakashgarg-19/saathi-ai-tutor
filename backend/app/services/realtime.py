"""In-process pub/sub that pushes classroom events to connected teacher dashboards.

A single API instance is enough for this project; scaling out would swap this for Redis
pub/sub behind the same `publish` signature.
"""

import asyncio
import logging
from collections import defaultdict
from collections.abc import Iterable

from fastapi import WebSocket

log = logging.getLogger(__name__)


class ClassroomHub:
    def __init__(self) -> None:
        self._sockets: dict[int, set[WebSocket]] = defaultdict(set)

    def connect(self, classroom_id: int, ws: WebSocket) -> None:
        self._sockets[classroom_id].add(ws)

    def disconnect(self, classroom_id: int, ws: WebSocket) -> None:
        self._sockets[classroom_id].discard(ws)

    async def publish(self, classroom_ids: Iterable[int], event: dict) -> None:
        targets = [ws for cid in classroom_ids for ws in list(self._sockets.get(cid, ()))]
        results = await asyncio.gather(
            *(ws.send_json(event) for ws in targets), return_exceptions=True
        )
        for ws, result in zip(targets, results, strict=True):
            if isinstance(result, Exception):
                log.debug("Dropping dead socket: %s", result)
                for sockets in self._sockets.values():
                    sockets.discard(ws)


hub = ClassroomHub()
