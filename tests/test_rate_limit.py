import unittest
import time
import asyncio
from unittest.mock import MagicMock, patch
from fastapi import Request, HTTPException
from server.auth.password import check_password, set_password, _rate_limiter, get_client_ip

class TestRateLimiter(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        # Set a password for testing
        set_password("correct-password")
        # Clear rate limiter state
        _rate_limiter.failed_attempts.clear()
        _rate_limiter.blocked_ips.clear()

    async def test_get_client_ip(self):
        # Case 1: No X-Forwarded-For
        req = MagicMock(spec=Request)
        req.headers = {}
        req.client.host = "1.2.3.4"
        self.assertEqual(get_client_ip(req), "1.2.3.4")

        # Case 2: X-Forwarded-For present
        req = MagicMock(spec=Request)
        req.headers = {"X-Forwarded-For": "10.0.0.1, 192.168.1.1"}
        req.client.host = "192.168.1.1"
        self.assertEqual(get_client_ip(req), "10.0.0.1")

    async def test_successful_login(self):
        req = MagicMock(spec=Request)
        req.headers = {}
        req.client.host = "1.2.3.4"

        # Should succeed
        result = await check_password(x_password="correct-password", request=req)
        self.assertTrue(result)

        # Should not have recorded any failure
        self.assertNotIn("1.2.3.4", _rate_limiter.failed_attempts)

    async def test_failed_login_rate_limit(self):
        req = MagicMock(spec=Request)
        req.headers = {}
        req.client.host = "5.6.7.8"

        # Fail 5 times (LIMIT)
        for _ in range(5):
            with self.assertRaises(HTTPException) as cm:
                await check_password(x_password="wrong", request=req)
            self.assertEqual(cm.exception.status_code, 401)

        # 6th time should be 429
        with self.assertRaises(HTTPException) as cm:
            await check_password(x_password="wrong", request=req)
        self.assertEqual(cm.exception.status_code, 429)
        self.assertIn("Too many failed attempts", cm.exception.detail)

        # Even correct password should be blocked now
        with self.assertRaises(HTTPException) as cm:
            await check_password(x_password="correct-password", request=req)
        self.assertEqual(cm.exception.status_code, 429)

    async def test_failed_login_rate_limit_with_proxy(self):
        req = MagicMock(spec=Request)
        req.headers = {"X-Forwarded-For": "203.0.113.1, 10.0.0.1"}
        req.client.host = "10.0.0.1"

        # Fail 5 times (LIMIT) for the real client IP (203.0.113.1)
        for _ in range(5):
            with self.assertRaises(HTTPException) as cm:
                await check_password(x_password="wrong", request=req)
            self.assertEqual(cm.exception.status_code, 401)

        # 6th time should be 429
        with self.assertRaises(HTTPException) as cm:
            await check_password(x_password="wrong", request=req)
        self.assertEqual(cm.exception.status_code, 429)

        # Verify blocking was done on the forwarded IP, not the proxy IP
        self.assertIn("203.0.113.1", _rate_limiter.blocked_ips)
        self.assertNotIn("10.0.0.1", _rate_limiter.blocked_ips)

    async def test_block_expiry(self):
        req = MagicMock(spec=Request)
        req.headers = {}
        req.client.host = "9.10.11.12"

        # Manually block with a future timestamp
        future_time = time.time() + 300
        _rate_limiter.blocked_ips["9.10.11.12"] = future_time

        # Verify blocked
        with self.assertRaises(HTTPException) as cm:
            await check_password(x_password="correct-password", request=req)
        self.assertEqual(cm.exception.status_code, 429)

        # Set block time to the past
        past_time = time.time() - 1
        _rate_limiter.blocked_ips["9.10.11.12"] = past_time

        # Should not be blocked anymore
        result = await check_password(x_password="correct-password", request=req)
        self.assertTrue(result)

        # Verify it was cleaned up
        self.assertNotIn("9.10.11.12", _rate_limiter.blocked_ips)

    async def test_rate_limiter_cleanup(self):
        # Setup old data
        old_ip = "100.1.1.1"
        recent_ip = "200.2.2.2"
        now = time.time()

        # Insert old failure (2 hours ago)
        _rate_limiter.failed_attempts[old_ip] = (1, now - 7200)
        # Insert recent failure
        _rate_limiter.failed_attempts[recent_ip] = (1, now)

        # Insert expired block
        _rate_limiter.blocked_ips[old_ip] = now - 100

        # Run cleanup
        _rate_limiter.cleanup()

        # Verify
        self.assertNotIn(old_ip, _rate_limiter.failed_attempts)
        self.assertIn(recent_ip, _rate_limiter.failed_attempts)
        self.assertNotIn(old_ip, _rate_limiter.blocked_ips)

if __name__ == "__main__":
    unittest.main()
