#!/usr/bin/env python3
"""
ACMOJ Client for submitting and querying submissions
"""

import os
import sys
import json
import requests
import time

ACMOJ_API_BASE = "https://acm.sjtu.edu.cn/OnlineJudge"
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
    return result.stdout.strip()

def submit_solution():
    """Submit the current repository to ACMOJ"""
    if not ACMOJ_TOKEN:
        print("ERROR: ACMOJ_TOKEN not found in environment")
        return None

    repo_url = get_repo_url()
    if not repo_url:
        print("ERROR: Could not get repository URL")
        return None

    # Make repo_url public-accessible (remove credentials)
    if "@" in repo_url:
        repo_url = repo_url.split("@")[1]
        repo_url = "https://" + repo_url

    print(f"Submitting repository: {repo_url}")
    print(f"Problem ID: {ACMOJ_PROBLEM_ID}")

    headers = {
        "Authorization": f"Bearer {ACMOJ_TOKEN}",
        "Content-Type": "application/json"
    }

    data = {
        "problem_id": ACMOJ_PROBLEM_ID,
        "repository_url": repo_url,
        "language": "verilog"
    }

    try:
        response = requests.post(
            f"{ACMOJ_API_BASE}/api/submit",
            headers=headers,
            json=data,
            timeout=30
        )

        if response.status_code == 200:
            result = response.json()
            submission_id = result.get("submission_id")
            print(f"\n✓ Submission successful!")
            print(f"Submission ID: {submission_id}")
            print(f"\nUse 'python3 {sys.argv[0]} status {submission_id}' to check status")
            return submission_id
        else:
            print(f"ERROR: Submission failed with status {response.status_code}")
            print(f"Response: {response.text}")
            return None
    except Exception as e:
        print(f"ERROR: {e}")
        return None

def check_status(submission_id):
    """Check the status of a submission"""
    if not ACMOJ_TOKEN:
        print("ERROR: ACMOJ_TOKEN not found in environment")
        return

    headers = {
        "Authorization": f"Bearer {ACMOJ_TOKEN}"
    }

    try:
        response = requests.get(
            f"{ACMOJ_API_BASE}/api/submission/{submission_id}",
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
        else:
            print(f"ERROR: Could not get status (HTTP {response.status_code})")
            print(f"Response: {response.text}")
            return None
    except Exception as e:
        print(f"ERROR: {e}")
        return None

def abort_submission(submission_id):
    """Abort a pending submission"""
    if not ACMOJ_TOKEN:
        print("ERROR: ACMOJ_TOKEN not found in environment")
        return

    headers = {
        "Authorization": f"Bearer {ACMOJ_TOKEN}"
    }

    try:
        response = requests.post(
            f"{ACMOJ_API_BASE}/api/submission/{submission_id}/abort",
            headers=headers,
            timeout=30
        )

        if response.status_code == 200:
            print(f"✓ Submission {submission_id} aborted successfully")
            print("Note: Aborted submissions do NOT count toward submission limit")
            return True
        else:
            print(f"ERROR: Could not abort submission (HTTP {response.status_code})")
            print(f"Response: {response.text}")
            return False
    except Exception as e:
        print(f"ERROR: {e}")
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
