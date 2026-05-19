# AWS Cloud Security & Incident Response Simulation

## Executive Summary
This project demonstrates a complete cloud security incident response lifecycle. I provisioned an AWS infrastructure using Terraform, executed a simulated brute-force attack via Node.js, established SOC monitoring with Splunk, and applied infrastructure-as-code remediation to secure the compromised environment.

## Phase 1: Cloud Architecture Provisioning
Deployed a custom AWS Virtual Private Cloud configured to capture and log network telemetry.
* **Infrastructure:** Custom VPC, Public/Private Subnets, and an Internet Gateway.
* **Resource:** Amazon RDS PostgreSQL database temporarily configured with `publicly_accessible = true` to serve as the initial attack surface.
* **Logging:** AWS VPC Flow Logs configured for automated routing to an S3 bucket for SIEM ingestion.

## Phase 2: Attack Simulation
Engineered and deployed a Node.js script to simulate an external threat actor.
* Generated sustained authentication requests to test logging and monitoring thresholds.
* Targeted Port 5432 and Port 22.

## Phase 3: SOC Telemetry & Threat Detection
Ingested VPC Flow Logs into Splunk Enterprise to establish a Security Operations Center dashboard and identify Indicators of Compromise.

![Splunk SOC Dashboard](splunk%20dashboard.png)

**Incident Report Findings:**
* **Event Volume:** 15,025 blocked network events.
* **Threat Origin:** Identified external IP `10.0.1.179` conducting systematic port scanning.
* **Action Required:** Immediate network isolation of the targeted database.

## Phase 4: Incident Remediation
Executed an infrastructure patch to mitigate the active threat and secure the environment.
1. Updated the Terraform `main.tf` configuration, altering the database parameter to `publicly_accessible = false`.
2. Applied the Terraform update to migrate the database instance into a private subnet.
3. Validated the patch by re-running the simulation, resulting in a network timeout and confirming the threat was neutralized.

```text
$ node attack_sim.js
[+] Initiating connection to database...
[-] Error: Connection Timeout. Network unreachable.
[+] Remediation verified: Database successfully isolated in private subnet.
