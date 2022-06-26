"""
Tests for Axon Python SDK client interfaces.
"""

from axon import AxonClient, Subject


def test_subject_formatting():
    s1 = Subject("user", "alice")
    assert s1.to_string() == "user:alice"

    s2 = Subject("group", "engineering", "member")
    assert s2.to_string() == "group:engineering#member"


def test_client_initialization():
    client = AxonClient("http://127.0.0.1:9080", auth_token="secret_token")
    assert client.endpoint_url == "http://127.0.0.1:9080"
    assert client.auth_token == "secret_token"


if __name__ == "__main__":
    test_subject_formatting()
    test_client_initialization()
    print("Python SDK tests passed.")
