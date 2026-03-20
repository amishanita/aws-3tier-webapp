# Load Test (k6)

This directory contains a k6 script to drive traffic against the API endpoint:

- `tests/load/k6.js` calls `GET /api/data?key=...`

## Run locally after deployment

1. Get your ALB DNS name from Terraform outputs (for the environment you tested).
2. Export:
   - `BASE_URL=https://<alb-dns-name>` (or `http://` if you temporarily bypass HTTPS)
3. Run:
   - `k6 run tests/load/k6.js`

## Prove auto scaling triggered

During the test, watch:

- EC2 / ASG CPU metric: `AWS/EC2 CPUUtilization` with dimension `AutoScalingGroupName`
- Custom metric (emitted by the Flask API): `TierHaWeb ApiResponseTimeMsAvg`

If scaling doesn’t trigger:

- Increase the k6 target VUs
- Lower the ASG target tracking thresholds in Terraform (`asg.tf`)

## Export CloudWatch evidence

After the run:

1. Open the CloudWatch dashboard created by Terraform: `(${tier-ha-web-<env>}-dashboard)`
2. Use the dashboard widget menu to export as PNG (or use CloudWatch “Share” -> “Export image”).
3. Capture the graph showing scale-out latency behavior (requests vs response time).

