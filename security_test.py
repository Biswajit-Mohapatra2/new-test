import requests
import urllib.parse
import time

def test_basic_security():
    base_url = "http://localhost:8000"
    findings = []

    # Test for SQL Injection
    sql_payloads = [
        "1' OR '1'='1",
        "1 OR 1=1",
        "' UNION SELECT NULL--",
        "admin'--"
    ]
    
    for payload in sql_payloads:
        try:
            response = requests.get(f"{base_url}/search?q={urllib.parse.quote(payload)}")
            if response.status_code == 200 and "error" not in response.text.lower():
                findings.append(f"Potential SQL Injection vulnerability found with payload: {payload}")
        except Exception as e:
            print(f"Error testing SQL injection: {e}")

    # Test for XSS
    xss_payloads = [
        "<script>alert(1)</script>",
        "<img src=x onerror=alert(1)>",
        "javascript:alert(1)"
    ]
    
    for payload in xss_payloads:
        try:
            response = requests.get(f"{base_url}/search?q={urllib.parse.quote(payload)}")
            if payload in response.text:
                findings.append(f"Potential XSS vulnerability found with payload: {payload}")
        except Exception as e:
            print(f"Error testing XSS: {e}")

    # Test for Path Traversal
    traversal_payloads = [
        "../../../etc/passwd",
        "..\\..\\..\\windows\\win.ini",
        "%2e%2e%2f%2e%2e%2f"
    ]
    
    for payload in traversal_payloads:
        try:
            response = requests.get(f"{base_url}/static/{urllib.parse.quote(payload)}")
            if response.status_code == 200:
                findings.append(f"Potential Path Traversal vulnerability found with payload: {payload}")
        except Exception as e:
            print(f"Error testing path traversal: {e}")

    # Write findings to file
    with open('security-test-results.txt', 'w') as f:
        if findings:
            f.write("Security Issues Found:\n")
            for finding in findings:
                f.write(f"- {finding}\n")
        else:
            f.write("No security issues found in basic tests.\n")

if __name__ == "__main__":
    # Wait for application to be fully started
    time.sleep(5)
    test_basic_security()
