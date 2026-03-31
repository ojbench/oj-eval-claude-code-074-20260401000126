#!/usr/bin/env python3
"""
ACMOJ Client for submitting and querying submissions
"""

import os
import sys
import json
import requests
import time

# Try multiple possible base URLs
ACMOJ_API_BASES = [
    "https://acm.sjtu.edu.cn/OnlineJudge/api/v1",
    "https://acm.sjtu.edu.cn/api/v1",
    "http://acm.sjtu.edu.cn/OnlineJudge/api/v1",
    "http://acm.sjtu.edu.cn/api/v1",
]
ACMOJ_TOKEN = os.environ.get("ACMOJ_TOKEN")
ACMOJ_PROBLEM_ID = os.environ.get("ACMOJ_PROBLEM_ID", "2532")

def get_repo_url():
    """Get the current repository URL"""
    import subprocess
    result = subprocess.run(
        ["git", "config", "--get", "remote.origin.url"],
        capture_output=True,
        text=True
    )
    url = result.stdout.strip()
    # Remove credentials if present
    if "@" in url:
        parts = url.split("@")
        url = "https://" + parts[1]
    return url

def submit_solution():
    """Submit the current repository to ACMOJ"""
    if not ACMOJ_TOKEN:
        print("ERROR: ACMOJ_TOKEN not found in environment")
        return None

    repo_url = get_repo_url()
    if not repo_url:
        print("ERROR: Could not get repository URL")
        return None

    print(f"Submitting repository: {repo_url}")
    print(f"Problem ID: {ACMOJ_PROBLEM_ID}")

    headers = {
        "Authorization": f"Bearer {ACMOJ_TOKEN}",
        "Content-Type": "application/json"
    }

    data = {
        "problem_id": int(ACMOJ_PROBLEM_ID),
        "repository_url": repo_url,
        "repo_url": repo_url,
        "git_url": repo_url,
        "language": "verilog",
        "source_type": "git"
    }

    # Try all combinations
    for base_url in ACMOJ_API_BASES:
        endpoints = [
            f"{base_url}/submissions",
            f"{base_url}/submit",
            f"{base_url}/problems/{ACMOJ_PROBLEM_ID}/submissions",
            f"{base_url}/problems/{ACMOJ_PROBLEM_ID}/submit",
        ]

        for endpoint in endpoints:
            try:
                print(f"Trying: {endpoint}")
                response = requests.post(
                    endpoint,
                    headers=headers,
                    json=data,
                    timeout=30,
                    verify=True
                )

                print(f"Status: {response.status_code}")

                if response.status_code == 200 or response.status_code == 201:
                    result = response.json()
                    submission_id = result.get("submission_id") or result.get("id")
                    print(f"\n✓ Submission successful!")
                    print(f"Submission ID: {submission_id}")
                    print(f"\nUse 'python3 {sys.argv[0]} status {submission_id}' to check status")
                    return submission_id
                elif response.status_code != 404:
                    print(f"Response: {response.text[:200]}")

            except requests.exceptions.RequestException as e:
                print(f"Error: {e}")
                continue
            except Exception as e:
                print(f"Error: {e}")
                continue

    print("\nERROR: Could not find working API endpoint")
    print("The submission may need to be done through a web interface or different method")
    return None

def check_status(submission_id):
    """Check the status of a submission"""
    if not ACMOJ_TOKEN:
        print("ERROR: ACMOJ_TOKEN not found in environment")
        return

    headers = {
        "Authorization": f"Bearer {ACMOJ_TOKEN}"
    }

    for base_url in ACMOJ_API_BASES:
        endpoints = [
            f"{base_url}/submissions/{submission_id}",
            f"{base_url}/submission/{submission_id}",
        ]

        for endpoint in endpoints:
            try:
                response = requests.get(
                    endpoint,
                    headers=headers,
                    timeout=30
                )

                if response.status_code == 200:
                    result = response.json()
                    print(f"\nSubmission ID: {submission_id}")
                    print(f"Status: {result.get('status', 'Unknown')}")
                    print(f"Score: {result.get('score', 'N/A')}")

                    if result.get('details'):
                        print(f"\nDetails:")
                        print(json.dumps(result['details'], indent=2))

                    return result
            except:
                continue

    print(f"ERROR: Could not get status for submission {submission_id}")
    return None

def abort_submission(submission_id):
    """Abort a pending submission"""
    if not ACMOJ_TOKEN:
        print("ERROR: ACMOJ_TOKEN not found in environment")
        return

    headers = {
        "Authorization": f"Bearer {ACMOJ_TOKEN}"
    }

    for base_url in ACMOJ_API_BASES:
        endpoints = [
            f"{base_url}/submissions/{submission_id}/abort",
            f"{base_url}/submission/{submission_id}/abort",
        ]

        for endpoint in endpoints:
            try:
                response = requests.post(
                    endpoint,
                    headers=headers,
                    timeout=30
                )

                if response.status_code == 200:
                    print(f"✓ Submission {submission_id} aborted successfully")
                    print("Note: Aborted submissions do NOT count toward submission limit")
                    return True
            except:
                continue

    print(f"ERROR: Could not abort submission {submission_id}")
    return False

def main():
    if len(sys.argv) < 2:
        print("Usage:")
        print(f"  {sys.argv[0]} submit          - Submit current repository")
        print(f"  {sys.argv[0]} status <id>     - Check submission status")
        print(f"  {sys.argv[0]} abort <id>      - Abort a pending submission")
        sys.exit(1)

    command = sys.argv[1].lower()

    if command == "submit":
        submit_solution()
    elif command == "status":
        if len(sys.argv) < 3:
            print("ERROR: Please provide submission ID")
            sys.exit(1)
        check_status(sys.argv[2])
    elif command == "abort":
        if len(sys.argv) < 3:
            print("ERROR: Please provide submission ID")
            sys.exit(1)
        abort_submission(sys.argv[2])
    else:
        print(f"ERROR: Unknown command '{command}'")
        sys.exit(1)

if __name__ == "__main__":
    main()
