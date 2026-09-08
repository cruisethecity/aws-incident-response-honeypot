# AWS Incident Response Lab: Exposed Database to Remediation

A two-person exercise running one security incident end to end in AWS. I built the infrastructure, the attack simulation, and the remediation. [Kenny Barr](https://github.com/KennySBarr) ran detection and the Splunk dashboard.

## The business problem

A publicly reachable database is one of the most common ways companies actually get breached, and it usually happens the boring way: somebody flips a flag to make development easier and nobody flips it back. The useful question is not whether that is bad. It is how fast a team gets from "something is wrong" to "the exposure is closed," and whether that fix is repeatable or a console click somebody forgets.

This lab runs that loop once, in code, so both the timeline and the fix are auditable.

## What I built

**Network.** A VPC at `10.0.0.0/16` with two subnets, `10.0.1.0/24` and `10.0.2.0/24`, across two availability zones. Both public: auto-assign public IP on, routed through an internet gateway. There is no private subnet in this build, which matters later.

**The exposure.** An RDS PostgreSQL 15 instance (`db.t3.micro`, 20 GB, storage encrypted) with:

```hcl
publicly_accessible = true
```

and a security group allowing `0.0.0.0/0` inbound on 5432, 22, and 80.

**Telemetry.** VPC Flow Logs to S3, CloudTrail with log file validation, and a read-only IAM identity so the SOC side could pull from the bucket without touching infrastructure.

**Attack simulation** (`attack_sim.js`). Three concurrent behaviors, each with its own timing profile so none of it looks machine-regular:

| Behavior | Target | Jitter |
|---|---|---|
| Dictionary attack against `db_admin` | 5432 | 100 to 800 ms |
| Port knocking | 22, 80 | 200 to 1500 ms |
| Benign traffic with the real password | 5432 | 500 to 3000 ms |

That third one is the point. Mixing authorized logins into the attack stream meant the detection side had to distinguish real users from attackers rather than just alerting on volume.

**Alerting** (`slack_alert.js`). Pushed incident notifications into the team channel.

## What the telemetry showed

`sample_flow.log` in this repo is a 1,000-line capture from that window. Grouped by source:

| Source | Lines | What it was |
|---|---|---|
| `10.0.1.149` | 445 | My own traffic, inside the VPC |
| `194.87.190.127` | 245 | The simulated bot |
| `136.35.186.87` | 183 | A real internet actor, multi-port scan on 22, 80, 5432 |
| 25 other addresses | 1 to 3 each | Internet background scanning |

876 ACCEPT, 124 REJECT across 29 distinct destination ports.

**The long tail is the real finding.** Rejections landed on Redis (6379), VNC (5902 through 5959), Kubernetes kubelet (10250, 10255), NetBIOS (137), and a dozen alt-HTTP ports. Nothing in this lab ran any of those services. That is ambient internet scanning finding a fresh public IP within the capture window, which is the thing the lab set out to demonstrate.

## Two corrections to the original writeup

Leaving these documented rather than quietly editing them out.

**The escalated IP was internal.** `INCIDENT_REPORT.md` names `10.0.1.179` as an external threat actor. That address sits inside `10.0.1.0/24`, one of the subnets defined in `main.tf`. It was my own traffic. A genuine external actor, `136.35.186.87`, was in the same dataset and did not make the report.

**The remediation did not move subnets.** The report says the database was migrated into a private subnet. Setting `publicly_accessible = false` stops RDS assigning a publicly resolvable endpoint. It does not relocate the instance, and the DB subnet group still contained the same two public subnets. The accurate claim is that the database became unreachable from outside the VPC, which is narrower and still verifiable.

## Remediation

```hcl
publicly_accessible = false
```

`terraform apply`, then re-run the simulator:

```text
$ node attack_sim.js
[+] Initiating connection to database...
[-] Error: Connection Timeout. Network unreachable.
```

Version controlled, reproducible, and provable with a single command.

## What this lab does not do

- **No authentication telemetry.** Flow logs carry addresses, ports, protocol, counts, and ACCEPT or REJECT. No payload, no usernames, no auth results. Proving brute force requires the RDS PostgreSQL error log, a separate pipeline this build does not ship.
- **No network segmentation.** Two public subnets, no private subnet, no NAT gateway. Putting the database behind a private subnet is the actual production pattern and is the next thing to build here.
- **The security group stays permissive** after remediation. Only public accessibility changes.
- **The 15,025 event count in the incident report was never broken down** by port or source. Given what the sample shows, most of it was likely unrelated internet scanning rather than the simulation.

## Stack

Terraform, AWS (VPC, RDS PostgreSQL, S3, CloudTrail, IAM, Flow Logs), Node.js, Splunk Enterprise, Slack.

## Running it

```bash
cp terraform.tfvars.example terraform.tfvars   # set db_password
terraform init
terraform apply

node attack_sim.js        # generate traffic
# set publicly_accessible = false in main.tf
terraform apply
node attack_sim.js        # confirm timeout
```

Costs money while it runs. `terraform destroy` when you are finished.

## Files

```text
main.tf                     VPC, subnets, RDS, security group, flow logs, CloudTrail
attack_sim.js               brute force, port knocking, benign traffic
slack_alert.js              incident notifications
sample_flow.log             1,000-line flow log capture
INCIDENT_REPORT.md          the SOC escalation ticket, with corrections noted above
splunk dashboard.png        SOC dashboard
terraform.tfvars.example
```
