# AWS Cloud Security & Incident Response Simulation

## Executive Summary
This project demonstrates a complete cloud security incident response lifecycle. I provisioned an AWS infrastructure using Terraform, executed a simulated brute-force attack via Node.js, established SOC monitoring with Splunk, and applied infrastructure-as-code remediation to secure the compromised environment.

## Phase 1: Cloud Architecture Provisioning
Deployed a custom AWS Virtual Private Cloud configured to capture and log network telemetry.
* **Infrastructure:** Custom VPC, Public and Private Subnets, and an Internet Gateway.
* **Resource:** Amazon RDS PostgreSQL database temporarily configured with publicly_accessible = true to serve as the initial attack surface.
* **Logging:** AWS VPC Flow Logs configured for automated routing to an S3 bucket for SIEM ingestion.

## Phase 2: Attack Simulation
Engineered and deployed a Node.js script to simulate an external threat actor.
* Generated sustained authentication requests to test logging and monitoring thresholds.
* Targeted PostgreSQL Port 5432 and SSH Port 22.

## Phase 3: SOC Telemetry & Cross-Team Handoff
VPC Flow Logs were routed to an S3 bucket and ingested into Splunk Enterprise, enabling the Security Operations Center to establish a live monitoring dashboard. I also configured automated incident notifications utilizing slack_alert.js to push real-time threat data directly to the security team communication channels.

![Splunk SOC Dashboard](splunk%20dashboard.png)

**Threat Escalation:**
Upon detecting anomalous traffic, the SOC Analyst escalated a formal Incident Report containing the following Indicators of Compromise:
* **Event Volume:** 15,025 blocked network events.
* **Threat Origin:** External IP 10.0.1.179 identified conducting systematic port scanning.
* **Action Required:** Cloud Infrastructure team formally requested to execute immediate network isolation of the targeted database.

## Phase 4: Incident Remediation
Upon receiving the escalated ticket from the SOC team, I executed an infrastructure patch to mitigate the active threat and secure the environment.
1. Updated the Terraform main.tf configuration, altering the database parameter to publicly_accessible = false.
2. Applied the Terraform update to migrate the database instance into a private subnet.
3. Validated the patch by re-running the simulation, resulting in a network timeout and confirming the threat was neutralized.

```text
$ node attack_sim.js
[+] Initiating connection to database...
[-] Error: Connection Timeout. Network unreachable.
[+] Remediation verified: Database successfully isolated in private subnet.
