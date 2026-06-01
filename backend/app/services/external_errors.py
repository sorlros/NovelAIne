import asyncio
import logging
from dataclasses import dataclass
from typing import Awaitable, Callable, TypeVar

import httpx

logger = logging.getLogger(__name__)

T = TypeVar("T")

TIMEOUT_MESSAGE = "응답이 지연되고 있습니다. 다시 시도해주세요."
RATE_LIMIT_MESSAGE = "현재 요청이 많습니다. 잠시 후 다시 시도해주세요."
TEMPORARY_MESSAGE = "일시적인 서버 문제가 발생했습니다."
GENERIC_MESSAGE = "요청 처리 중 문제가 발생했습니다."


@dataclass
class ExternalServiceError(Exception):
    service: str
    user_message: str
    log_message: str
    retryable: bool = False

    def __str__(self) -> str:
        return self.user_message


def error_from_response(service: str, status_code: int, body: str = "") -> ExternalServiceError:
    body_preview = (body or "")[:500]
    if status_code == 429:
        return ExternalServiceError(service, RATE_LIMIT_MESSAGE, f"{service} rate limited: {body_preview}")
    if status_code in {401, 403}:
        return ExternalServiceError(service, TEMPORARY_MESSAGE, f"{service} auth/config failed: {status_code} {body_preview}")
    if status_code in {408, 500, 502, 503, 504}:
        return ExternalServiceError(service, TEMPORARY_MESSAGE, f"{service} temporary failure: {status_code} {body_preview}")
    return ExternalServiceError(service, GENERIC_MESSAGE, f"{service} failed: {status_code} {body_preview}")


def error_from_exception(service: str, error: Exception) -> ExternalServiceError:
    if isinstance(error, ExternalServiceError):
        return error
    if isinstance(error, (httpx.TimeoutException, TimeoutError, asyncio.TimeoutError)):
        return ExternalServiceError(service, TIMEOUT_MESSAGE, f"{service} timeout: {error}", retryable=True)
    return ExternalServiceError(service, GENERIC_MESSAGE, f"{service} exception: {error}")


async def with_timeout_retry(
    service: str,
    operation: Callable[[], Awaitable[T]],
    *,
    max_retries: int = 1,
) -> T:
    attempts = 0
    while True:
        try:
            return await operation()
        except Exception as error:
            classified = error_from_exception(service, error)
            if classified.retryable and attempts < max_retries:
                attempts += 1
                logger.warning("%s failed with retryable error. retry=%s", service, attempts)
                continue
            logger.error(classified.log_message)
            raise classified
