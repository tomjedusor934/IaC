"""
Locust load testing for FastAPI Task Manager API.

Usage:
  locust -f locustfile.py --host=http://localhost:8000
  locust -f locustfile.py --host=https://dev.HERE_APP_DOMAIN

Web UI will be available at http://localhost:8089
"""

import json
import random
import string

from locust import HttpUser, between, task


def random_string(length: int = 10) -> str:
    return "".join(random.choices(string.ascii_lowercase, k=length))


class TaskManagerUser(HttpUser):
    """Simulates a user interacting with the Task Manager API."""

    wait_time = between(0.5, 2.0)
    token: str = ""
    task_ids: list = []

    def on_start(self):
        """Authenticate and obtain JWT token."""
        response = self.client.post(
            "/api/v1/auth/token",
            json={"username": "admin", "password": "admin"},
        )
        if response.status_code == 200:
            self.token = response.json().get("access_token", "")
        else:
            # Fallback: try without auth for health endpoints
            self.token = ""

    @property
    def auth_headers(self) -> dict:
        if self.token:
            return {"Authorization": f"Bearer {self.token}"}
        return {}

    # ------------------------------------------------------------------ #
    #  Health checks (high weight – lightweight)
    # ------------------------------------------------------------------ #

    @task(5)
    def health_check(self):
        self.client.get("/healthz", name="/healthz")

    @task(3)
    def readiness_check(self):
        self.client.get("/readyz", name="/readyz")

    # ------------------------------------------------------------------ #
    #  CRUD operations
    # ------------------------------------------------------------------ #

    @task(10)
    def create_task(self):
        payload = {
            "title": f"Load test task {random_string(8)}",
            "description": f"Created by Locust - {random_string(20)}",
        }
        with self.client.post(
            "/api/v1/tasks",
            json=payload,
            headers=self.auth_headers,
            catch_response=True,
            name="POST /api/v1/tasks",
        ) as response:
            if response.status_code == 201:
                task_id = response.json().get("id")
                if task_id:
                    self.task_ids.append(task_id)
                response.success()
            else:
                response.failure(f"Create failed: {response.status_code}")

    @task(15)
    def list_tasks(self):
        self.client.get(
            "/api/v1/tasks",
            headers=self.auth_headers,
            name="GET /api/v1/tasks",
        )

    @task(8)
    def get_single_task(self):
        if not self.task_ids:
            return
        task_id = random.choice(self.task_ids)
        self.client.get(
            f"/api/v1/tasks/{task_id}",
            headers=self.auth_headers,
            name="GET /api/v1/tasks/{id}",
        )

    @task(5)
    def update_task(self):
        if not self.task_ids:
            return
        task_id = random.choice(self.task_ids)
        payload = {
            "title": f"Updated task {random_string(6)}",
            "description": f"Updated by Locust - {random_string(15)}",
        }
        self.client.put(
            f"/api/v1/tasks/{task_id}",
            json=payload,
            headers=self.auth_headers,
            name="PUT /api/v1/tasks/{id}",
        )

    @task(2)
    def delete_task(self):
        if not self.task_ids:
            return
        task_id = self.task_ids.pop(random.randint(0, len(self.task_ids) - 1))
        self.client.delete(
            f"/api/v1/tasks/{task_id}",
            headers=self.auth_headers,
            name="DELETE /api/v1/tasks/{id}",
        )

    # ------------------------------------------------------------------ #
    #  Metrics endpoint (simulates Prometheus scraping)
    # ------------------------------------------------------------------ #

    @task(1)
    def metrics(self):
        self.client.get("/metrics", name="/metrics")
