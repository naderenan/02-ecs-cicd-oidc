from app import app


def test_index_reports_version():
    res = app.test_client().get("/")
    assert res.status_code == 200
    assert res.get_json()["service"] == "catalog"


def test_health():
    assert app.test_client().get("/health").get_json() == {"status": "ok"}


def test_products():
    data = app.test_client().get("/products").get_json()
    assert len(data) == 3 and data[0]["name"] == "Canvas Tote"
