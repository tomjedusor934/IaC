# ==============================================================================
# FastAPI Task Manager - Task CRUD Tests
# ==============================================================================
import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_create_task(client: AsyncClient, auth_headers):
    """Test creating a task returns 201."""
    response = await client.post(
        "/tasks",
        json={
            "title": "Test Task",
            "content": "Test content",
            "due_date": "2025-12-31",
            "request_timestamp": "2025-09-25T20:00:00Z",
        },
        headers=auth_headers,
    )
    assert response.status_code == 201
    data = response.json()
    assert data["title"] == "Test Task"
    assert data["done"] is False


@pytest.mark.asyncio
async def test_list_tasks(client: AsyncClient, auth_headers):
    """Test listing tasks returns 200."""
    response = await client.get("/tasks", headers=auth_headers)
    assert response.status_code == 200
    data = response.json()
    assert "tasks" in data
    assert "count" in data


@pytest.mark.asyncio
async def test_get_task_not_found(client: AsyncClient, auth_headers):
    """Test getting a non-existent task returns 404."""
    response = await client.get(
        "/tasks/00000000-0000-0000-0000-000000000000",
        headers=auth_headers,
    )
    assert response.status_code == 404


@pytest.mark.asyncio
async def test_update_task(client: AsyncClient, auth_headers):
    """Test updating a task returns 200."""
    # Create first
    create_resp = await client.post(
        "/tasks",
        json={
            "title": "Original",
            "content": "Original content",
            "due_date": "2025-12-31",
            "request_timestamp": "2025-09-25T20:00:00Z",
        },
        headers=auth_headers,
    )
    task_id = create_resp.json()["id"]

    # Update
    response = await client.put(
        f"/tasks/{task_id}",
        json={
            "title": "Updated",
            "done": True,
            "request_timestamp": "2025-09-25T20:01:00Z",
        },
        headers=auth_headers,
    )
    assert response.status_code == 200
    assert response.json()["title"] == "Updated"
    assert response.json()["done"] is True


@pytest.mark.asyncio
async def test_update_task_conflict(client: AsyncClient, auth_headers):
    """Test updating with a stale timestamp returns 409."""
    create_resp = await client.post(
        "/tasks",
        json={
            "title": "Test",
            "content": "Content",
            "due_date": "2025-12-31",
            "request_timestamp": "2025-09-25T20:00:00Z",
        },
        headers=auth_headers,
    )
    task_id = create_resp.json()["id"]

    # Update with OLDER timestamp → conflict
    response = await client.put(
        f"/tasks/{task_id}",
        json={
            "title": "Stale update",
            "request_timestamp": "2025-09-25T19:00:00Z",
        },
        headers=auth_headers,
    )
    assert response.status_code == 409


@pytest.mark.asyncio
async def test_delete_task(client: AsyncClient, auth_headers):
    """Test deleting a task returns 200."""
    create_resp = await client.post(
        "/tasks",
        json={
            "title": "To Delete",
            "content": "Content",
            "due_date": "2025-12-31",
            "request_timestamp": "2025-09-25T20:00:00Z",
        },
        headers=auth_headers,
    )
    task_id = create_resp.json()["id"]

    response = await client.request(
        "DELETE",
        f"/tasks/{task_id}",
        json={"request_timestamp": "2025-09-25T20:01:00Z"},
        headers=auth_headers,
    )
    assert response.status_code == 200


@pytest.mark.asyncio
async def test_unauthorized_access(client: AsyncClient):
    """Test that missing auth returns 401 (or 403 previously)."""
    response = await client.get("/tasks")
    assert response.status_code in [401, 403]


@pytest.mark.asyncio
async def test_health_endpoint(client: AsyncClient):
    """Test liveness probe."""
    response = await client.get("/healthz")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"
