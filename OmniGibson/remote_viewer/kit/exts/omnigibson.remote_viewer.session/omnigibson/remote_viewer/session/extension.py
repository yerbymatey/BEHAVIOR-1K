from __future__ import annotations

import os
from typing import Any, Dict

import omni.ext
from omni.services.core import main, routers
from fastapi import Request

_SESSION_ENDPOINT = "/v1/streaming/session"
_router = routers.ServiceAPIRouter()


def _env_int(name: str, default: int) -> int:
    raw = os.getenv(name, "").strip()
    if not raw:
        return default
    try:
        return int(raw)
    except ValueError:  # pragma: no cover - defensive
        return default


def _split_host(value: str) -> str:
    if ":" in value and not value.startswith("["):
        return value.split(":", 1)[0]
    return value


@_router.post(_SESSION_ENDPOINT, summary="Create remote viewer session")
async def create_session_endpoint(request: Request) -> Dict[str, Any]:
    stream_host = os.getenv("PUBLIC_IP", "").strip()

    xf_host = request.headers.get("x-forwarded-host")
    if not stream_host and xf_host:
        stream_host = _split_host(xf_host)
    if not stream_host and request.client:
        stream_host = request.client.host or "127.0.0.1"
    stream_host = stream_host.strip()
    
    # Determine streaming mode (webrtc or websocket)
    streaming_mode = os.getenv("OMNIGIBSON_REMOTE_STREAMING", "webrtc").lower()
    if streaming_mode not in ["webrtc", "websocket"]:
        streaming_mode = "webrtc"

    # Determine signaling and media ports based on streaming mode
    if streaming_mode == "websocket":
        # WebSocket mode: use HTTP server port (same port for everything)
        # Try env var first, then fall back to request host header
        signaling_port = _env_int("EXTERNAL_HTTP_PORT", 0)
        if signaling_port == 0:
            # Extract port from request's host header
            host_header = request.headers.get("host", "")
            if ":" in host_header:
                signaling_port = int(host_header.split(":")[-1])
            else:
                # No port in host header, use standard HTTP port
                signaling_port = 80 if request.url.scheme == "http" else 443
        media_port = signaling_port  # Same port for websocket mode
    else:
        # WebRTC uses separate signaling and media ports
        signaling_port = _env_int("EXTERNAL_STREAM_SIGNALING_PORT", 49100)
        media_port = _env_int("EXTERNAL_STREAM_MEDIA_PORT", 47998)

    # Determine backend URL for client reference
    xf_proto = request.headers.get("x-forwarded-proto", request.url.scheme or "http")
    xf_host_full = request.headers.get("x-forwarded-host")
    if xf_proto and xf_host_full:
        backend_url = f"{xf_proto}://{xf_host_full}".rstrip("/")
    else:
        host = request.headers.get("host", "")
        backend_url = f"{request.url.scheme or 'http'}://{host}".rstrip("/")

    response: Dict[str, Any] = {
        "streamSignalingHost": stream_host,
        "signalingPort": int(signaling_port),
        "mediaPort": int(media_port),
        "backendUrl": backend_url,
        "streamingMode": streaming_mode,
    }

    return response


class SessionEndpointExtension(omni.ext.IExt):
    """Expose a simple `/v1/streaming/session` REST endpoint backed by Kit settings."""

    def on_startup(self, _ext_id: str) -> None:
        main.register_router(_router)

    def on_shutdown(self) -> None:
        main.deregister_router(_router)


