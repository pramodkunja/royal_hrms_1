from __future__ import annotations

from rest_framework import status
from rest_framework.response import Response


def success(
    message: str,
    data: dict | list | None = None,
    http_status: int = status.HTTP_200_OK,
) -> Response:
    return Response(
        {'status': 'success', 'message': message, 'data': data if data is not None else {}},
        status=http_status,
    )


def error(
    message: str,
    data: dict | None = None,
    http_status: int = status.HTTP_400_BAD_REQUEST,
) -> Response:
    return Response(
        {'status': 'error', 'message': message, 'data': data if data is not None else {}},
        status=http_status,
    )


def first_error(serializer_errors: dict) -> str:
    """Return the first human-readable message from a DRF serializer errors dict."""
    for field_errors in serializer_errors.values():
        if isinstance(field_errors, list) and field_errors:
            return str(field_errors[0])
        if isinstance(field_errors, str):
            return field_errors
    return 'Validation error.'


def get_client_ip(request) -> str:
    x_forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR', '')
    if x_forwarded_for:
        return x_forwarded_for.split(',')[0].strip()
    return request.META.get('REMOTE_ADDR') or '0.0.0.0'
